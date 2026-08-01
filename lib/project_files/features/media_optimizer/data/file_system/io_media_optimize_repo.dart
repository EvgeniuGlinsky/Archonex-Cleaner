import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:storage_cleaner/core/constants/app_optimizer_policy.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/encoders/media_encoder.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/file_system/file_byte_source.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/probes/media_probe_reader.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/media_optimize_repo.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/encoder_support.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_candidate.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_kind.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_probe.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_job.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_report.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_update.dart';

/// The real runner, on `dart:io`.
///
/// It does not encode anything. `MediaEncoder` does that, and which one is
/// decided on the platform boundary; what lives here is the part that must not
/// lose a file, in one place, so there is exactly one implementation of it to
/// get right.
class IoMediaOptimizeRepo implements MediaOptimizeRepo {
  IoMediaOptimizeRepo({
    required MediaEncoder photoEncoder,
    required MediaEncoder videoEncoder,
    MediaProbeReader? probeReader,
  })  : _photoEncoder = photoEncoder,
        _videoEncoder = videoEncoder,
        _probeReader = probeReader ?? const MediaProbeReader();

  final MediaEncoder _photoEncoder;
  final MediaEncoder _videoEncoder;
  final MediaProbeReader _probeReader;

  @override
  bool get isSupported => true;

  @override
  Future<EncoderSupport> support() async {
    return EncoderSupport(
      photos: await _photoEncoder.isAvailable,
      videos: await _videoEncoder.isAvailable,
    );
  }

  @override
  OptimizeJob optimize({required List<MediaCandidate> candidates}) {
    return _IoOptimizeJob(
      candidates: candidates,
      encoderFor: (kind) =>
          kind == MediaKind.photo ? _photoEncoder : _videoEncoder,
      probeReader: _probeReader,
    );
  }
}

/// One run, exposed as a stream that can be stopped.
///
/// It ends the opposite way to the scan job, and the asymmetry is deliberate:
/// this one emits `OptimizeFinished` and closes normally even when cancelled,
/// because by then files have been rewritten and the count is owed to the user.
/// `_IoCleanJob` makes the same distinction for the same reason.
///
/// ## The replace ladder
///
/// This is the whole reason the class exists, and the part to be paranoid in.
/// There is no quarantine here — keeping the original for seven days would mean
/// the disk holding both, which frees nothing, and freeing space is what the
/// button was pressed for. So the original is deleted, and the only thing
/// standing between the user and a lost photograph is the order these steps
/// happen in.
///
/// Per file:
///
/// 1. Encode to a working file **beside the original**, on the same volume, so
///    that step 4 is a rename rather than a copy. A rename is atomic and a copy
///    of a four-gigabyte video is four gigabytes of the space this run is
///    trying to free.
/// 2. Verify the result: it exists, it is meaningfully smaller, and its header
///    re-reads with the same dimensions and, for a video, the same length. An
///    encoder that stopped early leaves a valid file that is simply shorter,
///    and file size alone cannot tell that from a good encode.
/// 3. Carry the modification time across, so a gallery does not reorder itself
///    and put every optimised photograph at the top as if taken today.
/// 4. Swap. Rename the original aside, rename the working file into place,
///    then delete the original — never a rename *over* a live file, which
///    throws on Windows, and never a delete-then-rename, which has a window
///    where neither file exists.
/// 5. Anything that fails at any step: delete the working file, leave the
///    original exactly where it is, count it and carry on. One file refusing
///    does not end a run of two hundred.
///
/// A run sweeps the leavings of a crashed one before it starts, because step 4
/// is the only place two names for the same content exist and a process killed
/// in the middle of it is the one case the ladder cannot clean up after itself.
class _IoOptimizeJob implements OptimizeJob {
  _IoOptimizeJob({
    required List<MediaCandidate> candidates,
    required MediaEncoder Function(MediaKind) encoderFor,
    required MediaProbeReader probeReader,
  })  : _candidates = candidates,
        _encoderFor = encoderFor,
        _probeReader = probeReader {
    _controller = StreamController<OptimizeUpdate>(onListen: _start);
  }

  final List<MediaCandidate> _candidates;
  final MediaEncoder Function(MediaKind) _encoderFor;
  final MediaProbeReader _probeReader;

  late final StreamController<OptimizeUpdate> _controller;

  int _freedBytes = 0;
  int _optimizedCount = 0;
  int _skippedCount = 0;
  int _failedCount = 0;
  int _renamedCount = 0;
  bool _isCancelling = false;

  @override
  Stream<OptimizeUpdate> get updates => _controller.stream;

  @override
  Future<void> cancel() async {
    _isCancelling = true;
    // The encoder is told as well as the loop, because the loop is inside an
    // await that can last an hour and would otherwise not notice until it ends.
    await _encoderFor(MediaKind.photo).cancel();
    await _encoderFor(MediaKind.video).cancel();
  }

  /// Sequential, one file at a time, on purpose.
  ///
  /// The cleaner's deleter is sequential because deleting is bound by the file
  /// system and parallel workers buy nothing. Here the reason inverts and lands
  /// in the same place: encoding is bound by the CPU, and two at once on a
  /// phone is thermal throttling and a device too hot to hold. It also keeps
  /// cancellation meaning "stop after this one" rather than "stop after however
  /// many are in flight".
  Future<void> _start() async {
    await _sweepLeavings();

    for (int index = 0; index < _candidates.length; index++) {
      if (_isCancelling) {
        break;
      }

      final MediaCandidate candidate = _candidates[index];

      _emit(
        OptimizeProgress(
          doneCount: index,
          totalCount: _candidates.length,
          freedBytes: _freedBytes,
          currentName: candidate.name,
        ),
      );

      await _process(candidate, index);
    }

    _emit(
      OptimizeFinished(
        OptimizeReport(
          freedBytes: _freedBytes,
          optimizedCount: _optimizedCount,
          skippedCount: _skippedCount,
          failedCount: _failedCount,
          renamedCount: _renamedCount,
          wasCancelled: _isCancelling,
        ),
      ),
    );

    await _close();
  }

  Future<void> _process(MediaCandidate candidate, int index) async {
    final String workingPath = _workingPathFor(candidate.path);
    final String destination = _destinationFor(candidate);

    // A different extension means a different name, and a name already taken
    // is refused outright rather than resolved by inventing one. A user who
    // finds `holiday (2).jpg` beside a missing `holiday.png` has been given a
    // puzzle instead of a result.
    if (destination != candidate.path && await _exists(destination)) {
      _skippedCount++;

      return;
    }

    try {
      await _encode(candidate, workingPath, index);
    } on Object {
      await _deleteQuietly(workingPath);

      // A cancelled encode is not a failure. The user stopped it, the original
      // is untouched, and the file simply was not done.
      if (!_isCancelling) {
        _failedCount++;
      }

      return;
    }

    if (_isCancelling) {
      await _deleteQuietly(workingPath);

      return;
    }

    final int? producedBytes = await _verify(candidate, workingPath);

    if (producedBytes == null) {
      await _deleteQuietly(workingPath);
      _skippedCount++;

      return;
    }

    final bool swapped = await _swap(
      candidate: candidate,
      workingPath: workingPath,
      destination: destination,
    );

    if (!swapped) {
      await _deleteQuietly(workingPath);
      _failedCount++;

      return;
    }

    _freedBytes += candidate.sizeInBytes - producedBytes;
    _optimizedCount++;

    if (destination != candidate.path) {
      _renamedCount++;
    }
  }

  Future<void> _encode(
    MediaCandidate candidate,
    String workingPath,
    int index,
  ) async {
    final Stream<double> progress = _encoderFor(candidate.kind).encode(
      candidate: candidate,
      outputPath: workingPath,
    );

    await for (final double fraction in progress) {
      if (_isCancelling) {
        return;
      }

      _emit(
        OptimizeProgress(
          doneCount: index,
          totalCount: _candidates.length,
          freedBytes: _freedBytes,
          currentName: candidate.name,
          fileProgress: fraction,
        ),
      );
    }
  }

  /// The size of the replacement, or `null` if it is not one.
  ///
  /// Three questions, and the third is the one that earns its keep. Size alone
  /// cannot tell a good encode from an encoder that stopped a third of the way
  /// through: both produce a valid, smaller file. Re-reading the header and
  /// comparing the dimensions and the duration is what catches it, and it costs
  /// one open per file at the end of an encode that took minutes.
  Future<int?> _verify(MediaCandidate candidate, String workingPath) async {
    final File produced = File(workingPath);
    final int producedBytes;

    try {
      if (!await produced.exists()) {
        return null;
      }

      producedBytes = await produced.length();
    } on FileSystemException {
      return null;
    }

    if (producedBytes <= 0) {
      return null;
    }

    // An encoder that produced something the same size or larger has done
    // nothing useful, whatever the estimate promised.
    final double shrink =
        (candidate.sizeInBytes - producedBytes) / candidate.sizeInBytes;

    if (shrink < AppOptimizerPolicy.verifyMinShrinkFraction) {
      return null;
    }

    final FileByteSource? source = await FileByteSource.open(workingPath);

    if (source == null) {
      return null;
    }

    try {
      final MediaProbe? probe = await _probeReader.read(source);

      if (probe == null || !probe.isComplete) {
        return null;
      }

      if (probe.width != candidate.probe.width ||
          probe.height != candidate.probe.height) {
        return null;
      }

      return _durationMatches(candidate.probe, probe) ? producedBytes : null;
    } finally {
      await source.close();
    }
  }

  /// Whether a re-encoded video is still as long as it was.
  ///
  /// The single most useful check here: a transcode that hit a corrupt frame
  /// and stopped writes a file that plays perfectly and ends early. A tolerance
  /// because an honest encoder rounds to a frame boundary.
  static bool _durationMatches(MediaProbe original, MediaProbe produced) {
    final int? before = original.durationMs;
    final int? after = produced.durationMs;

    if (before == null) {
      return true;
    }

    if (after == null || before <= 0) {
      return false;
    }

    return ((before - after).abs() / before) <= AppOptimizerPolicy.durationTolerance;
  }

  /// Puts the replacement where the original was, and removes the original.
  ///
  /// Three renames rather than one, because the obvious version does not work.
  /// Renaming the working file over the original throws on Windows, where a
  /// destination that exists is an error rather than something to overwrite;
  /// deleting the original first and then renaming leaves a window, however
  /// short, in which the only copy of the picture is gone and the replacement
  /// is not yet in place. Moving the original aside first means every failure
  /// has something to fall back to.
  Future<bool> _swap({
    required MediaCandidate candidate,
    required String workingPath,
    required String destination,
  }) async {
    final String supersededPath =
        '${candidate.path}${AppOptimizerPolicy.supersededSuffix}';

    try {
      await File(candidate.path).rename(supersededPath);
    } on FileSystemException {
      return false;
    }

    try {
      await File(workingPath).rename(destination);
    } on FileSystemException {
      // Put it back. The user's file is exactly where it was and nothing has
      // been lost — which is the entire point of doing it in this order.
      await _restoreQuietly(supersededPath, candidate.path);

      return false;
    }

    // Only now, with a verified replacement in place, does the original go.
    await _deleteQuietly(supersededPath);

    // Last, and not worth failing the file over: a gallery whose ordering moved
    // is an annoyance, and undoing a completed swap to fix it would be worse.
    await _carryTimestamp(destination, candidate.modifiedAt);

    return true;
  }

  /// The working name for a file, beside it and hidden.
  ///
  /// Beside it because a rename across volumes is a copy, and the system
  /// temporary directory is routinely on a different one — which would mean
  /// writing four gigabytes twice to free two.
  static String _workingPathFor(String originalPath) {
    final String directory = p.dirname(originalPath);
    final String name = p.basename(originalPath);

    return p.join(directory, '${AppOptimizerPolicy.workingPrefix}$name');
  }

  /// Where the result ends up: the original path, unless the container changed.
  static String _destinationFor(MediaCandidate candidate) {
    if (!candidate.changesExtension) {
      return candidate.path;
    }

    final String directory = p.dirname(candidate.path);
    final String stem = p.basenameWithoutExtension(candidate.path);
    final String extension = candidate.plan.targetContainer!.canonicalExtension;

    return p.join(directory, '$stem$extension');
  }

  /// Removes the working files and moved-aside originals of a run that was
  /// killed part way.
  ///
  /// Step 4 is the only place two names for the same content exist, and a
  /// process that dies inside it is the one case the ladder cannot clean up
  /// after itself. A `.archonex-old` left behind is the user's file, so it is
  /// restored rather than deleted; a working file is half an encode and goes.
  ///
  /// Only the directories this run will touch, not the whole disk: a sweep
  /// wider than the work is a second walk nobody asked for.
  Future<void> _sweepLeavings() async {
    final Set<String> directories = _candidates
        .map((candidate) => p.dirname(candidate.path))
        .toSet();

    for (final String directory in directories) {
      try {
        await for (final FileSystemEntity entity
            in Directory(directory).list(followLinks: false)) {
          if (entity is! File) {
            continue;
          }

          final String name = p.basename(entity.path);

          if (name.startsWith(AppOptimizerPolicy.workingPrefix)) {
            await _deleteQuietly(entity.path);
          } else if (name.endsWith(AppOptimizerPolicy.supersededSuffix)) {
            final String original = entity.path.substring(
              0,
              entity.path.length - AppOptimizerPolicy.supersededSuffix.length,
            );

            await _restoreQuietly(entity.path, original);
          }
        }
      } on FileSystemException {
        // A folder that has gone or will not open. The run carries on; the
        // sweep is housekeeping, not a precondition.
        continue;
      }
    }
  }

  /// So a gallery does not put every optimised photograph at the top as though
  /// it were taken today.
  Future<void> _carryTimestamp(String path, DateTime modifiedAt) async {
    try {
      await File(path).setLastModified(modifiedAt);
    } on FileSystemException {
      // Not supported on every file system, and not worth a failure.
    }
  }

  Future<bool> _exists(String path) async {
    try {
      return await File(path).exists();
    } on FileSystemException {
      return true;
    }
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final File file = File(path);

      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // Nothing depends on it going.
    }
  }

  Future<void> _restoreQuietly(String from, String to) async {
    try {
      if (await File(to).exists()) {
        // Something is already at the destination, which means the swap got
        // further than it looked. Leaving both is the safe answer: the user has
        // their file either way, and this one is the one to look at.
        return;
      }

      await File(from).rename(to);
    } on FileSystemException {
      // The moved-aside original stays on disk under its suffixed name, which
      // is recoverable by hand and is the safe direction to fail in.
    }
  }

  void _emit(OptimizeUpdate update) {
    if (!_controller.isClosed) {
      _controller.add(update);
    }
  }

  Future<void> _close() async {
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}
