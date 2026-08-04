import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:storage_cleaner/core/constants/app_byte_units.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/encoders/media_encoder.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/encoder_supply_repo.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/media_optimize_repo.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/media_scan_repo.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/encoder_supply_job.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/encoder_support.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_candidate.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_container.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_kind.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_probe.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_scan_job.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_scan_update.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimization_plan.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_job.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_quality.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_report.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_update.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_verdict.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/video_codec.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/optimize_quality_repo.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/run_notice.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';

import 'fixtures.dart';

/// Hand-written fakes for the optimiser. There is no mocking package in this
/// project and none is to be added — see `CLAUDE.md`.
///
/// Two of these fake a `domain/` contract, as the rule requires. The third,
/// [FakeMediaEncoder], fakes `MediaEncoder`, which is a `data/` interface — and
/// that is the exception the rule allows for: it is the seam that exists
/// precisely so the replace ladder can be driven without a codec, and none of
/// the four real encoders can run under `flutter test`.

/// A candidate, with everything but the interesting field defaulted.
MediaCandidate fakeCandidate({
  String path = '/pictures/holiday.jpg',
  String? name,
  int sizeInBytes = 9000000,
  int estimatedBytes = 3000000,
  MediaKind kind = MediaKind.photo,
  MediaContainer? container,
  MediaContainer? target,
  OptimizeVerdict verdict = OptimizeVerdict.worthIt,
  OptimizeQuality preset = OptimizeQuality.fallback,
  int width = 4000,
  int height = 3000,
  DateTime? modifiedAt,
}) {
  final MediaContainer source = container ??
      (kind == MediaKind.photo ? MediaContainer.jpeg : MediaContainer.mp4);

  return MediaCandidate(
    path: path,
    name: name ?? path.split('/').last,
    sizeInBytes: sizeInBytes,
    modifiedAt: modifiedAt ?? DateTime.utc(2026, 1, 1),
    probe: MediaProbe(
      container: source,
      width: width,
      height: height,
      codec: kind == MediaKind.video ? VideoCodec.h264 : null,
      durationMs: kind == MediaKind.video ? 60000 : null,
      frameRate: kind == MediaKind.video ? 30 : null,
    ),
    plan: verdict == OptimizeVerdict.worthIt
        ? OptimizationPlan.reencode(
            targetContainer: target ??
                (kind == MediaKind.photo
                    ? MediaContainer.jpeg
                    : MediaContainer.mp4),
            estimatedBytes: estimatedBytes,
            targetCodec: kind == MediaKind.video ? VideoCodec.hevc : null,
            preset: preset,
          )
        : OptimizationPlan.skip(verdict),
  );
}

class FakeMediaScanRepo implements MediaScanRepo {
  FakeMediaScanRepo({
    this.isSupported = true,
    this.kinds = const <MediaKind>{MediaKind.video, MediaKind.photo},
    this.updates = const <MediaScanUpdate>[],
    this.failure,
    this.holdOpen = false,
  });

  @override
  bool isSupported;

  Set<MediaKind> kinds;

  /// Emitted in order, then the stream closes.
  List<MediaScanUpdate> updates;

  /// Ends the stream with this instead of closing it.
  Object? failure;

  /// Leaves the stream open after the updates, so a test can observe a walk
  /// that is still running — the only way to check that closing the bloc stops
  /// one without the job finishing first and passing for the wrong reason.
  bool holdOpen;

  int scanCount = 0;
  Set<MediaKind>? lastRequestedKinds;

  /// Which preset the walk was started under. The estimates depend on it, so a
  /// bloc that forgot to pass the user's choice would produce a plausible list
  /// measured against the wrong one.
  OptimizeQuality? lastRequestedQuality;
  bool wasCancelled = false;

  /// Empty where the access reaches no folder the user filled, which is the
  /// rule `MediaRuleset` really applies: an app-only Android answers
  /// `StorageAccess.canScan` true and still has nothing here to look at.
  @override
  Future<Set<MediaKind>> kindsFor(StorageAccess access) async {
    return switch (access.level) {
      StorageAccessLevel.full || StorageAccessLevel.scopedFolders => kinds,
      StorageAccessLevel.appOnly || StorageAccessLevel.none => const <MediaKind>{},
    };
  }

  @override
  Future<MediaScanJob> scan({
    required Set<MediaKind> kinds,
    required StorageAccess access,
    required OptimizeQuality quality,
  }) async {
    scanCount++;
    lastRequestedQuality = quality;
    lastRequestedKinds = kinds;

    return FakeMediaScanJob(
      updates: updates,
      failure: failure,
      holdOpen: holdOpen,
      onCancel: () => wasCancelled = true,
    );
  }
}

class FakeMediaScanJob implements MediaScanJob {
  FakeMediaScanJob({
    required List<MediaScanUpdate> updates,
    Object? failure,
    bool holdOpen = false,
    void Function()? onCancel,
  })  : _updates = updates,
        _failure = failure,
        _holdOpen = holdOpen,
        _onCancel = onCancel {
    _controller = StreamController<MediaScanUpdate>(onListen: _start);
  }

  final List<MediaScanUpdate> _updates;
  final Object? _failure;
  final bool _holdOpen;
  final void Function()? _onCancel;

  late final StreamController<MediaScanUpdate> _controller;

  @override
  Stream<MediaScanUpdate> get updates => _controller.stream;

  @override
  Future<void> cancel() async {
    _onCancel?.call();

    if (!_controller.isClosed) {
      _controller.addError(const _Cancelled());
      await _controller.close();
    }
  }

  /// Nothing is emitted until something listens, exactly as the real job does.
  Future<void> _start() async {
    for (final MediaScanUpdate update in _updates) {
      if (_controller.isClosed) {
        return;
      }

      _controller.add(update);
    }

    if (_controller.isClosed) {
      return;
    }

    if (_failure != null) {
      _controller.addError(_failure);
    }

    if (_holdOpen) {
      return;
    }

    await _controller.close();
  }
}

/// Stands in for `MediaScanCancelledFailure` without the fake importing it —
/// the bloc maps anything that is not an `OptimizeFailure` to a scan failure,
/// and the tests that care set `failure` explicitly.
class _Cancelled implements Exception {
  const _Cancelled();
}

class FakeMediaOptimizeRepo implements MediaOptimizeRepo {
  FakeMediaOptimizeRepo({
    this.isSupported = true,
    this.encoderSupport = const EncoderSupport(photos: true, videos: true),
    this.report = const OptimizeReport(freedBytes: 6000000, optimizedCount: 2),
    this.failure,
    this.holdOpen = false,
  });

  @override
  bool isSupported;

  EncoderSupport encoderSupport;

  /// Reported by the `OptimizeFinished` the job ends with.
  OptimizeReport report;

  /// Ends the stream with this instead of finishing.
  Object? failure;

  bool holdOpen;

  List<MediaCandidate>? lastCandidates;
  bool wasCancelled = false;

  @override
  Future<EncoderSupport> support() async => encoderSupport;

  @override
  OptimizeJob optimize({required List<MediaCandidate> candidates}) {
    lastCandidates = candidates;

    return FakeOptimizeJob(
      candidates: candidates,
      report: report,
      failure: failure,
      holdOpen: holdOpen,
      onCancel: () => wasCancelled = true,
    );
  }
}

class FakeOptimizeJob implements OptimizeJob {
  FakeOptimizeJob({
    required List<MediaCandidate> candidates,
    required OptimizeReport report,
    Object? failure,
    bool holdOpen = false,
    void Function()? onCancel,
  })  : _candidates = candidates,
        _report = report,
        _failure = failure,
        _holdOpen = holdOpen,
        _onCancel = onCancel {
    _controller = StreamController<OptimizeUpdate>(onListen: _start);
  }

  final List<MediaCandidate> _candidates;
  final OptimizeReport _report;
  final Object? _failure;
  final bool _holdOpen;
  final void Function()? _onCancel;

  late final StreamController<OptimizeUpdate> _controller;

  @override
  Stream<OptimizeUpdate> get updates => _controller.stream;

  @override
  Future<void> cancel() async {
    _onCancel?.call();
  }

  Future<void> _start() async {
    if (_failure != null) {
      _controller.addError(_failure);
      await _controller.close();

      return;
    }

    for (int index = 0; index < _candidates.length; index++) {
      _controller.add(
        OptimizeProgress(
          doneCount: index,
          totalCount: _candidates.length,
          freedBytes: 0,
          currentName: _candidates[index].name,
        ),
      );
    }

    if (_holdOpen) {
      return;
    }

    _controller.add(OptimizeFinished(_report));
    await _controller.close();
  }
}

/// An encoder that writes a real, structurally valid JPEG of a chosen size.
///
/// Real rather than random bytes, because the replace ladder re-reads the
/// header of what it produced and a blob would be rejected for the wrong
/// reason. Everything a test wants to go wrong is a flag here: too large, wrong
/// dimensions, unparseable, thrown, nothing written at all.
class FakeMediaEncoder implements MediaEncoder {
  FakeMediaEncoder({
    this.outputBytes,
    this.shrinkTo,
    this.outputWidth,
    this.outputHeight,
    this.available = true,
    this.writeGarbage = false,
    this.writeNothing = false,
    this.throwsAfter,
    this.failPaths = const <String>{},
  });

  /// Exact size of the file to write.
  final int? outputBytes;

  /// Or a fraction of the input's size, where the test cares about the ratio
  /// rather than the number.
  final double? shrinkTo;

  /// Dimensions to put in the header, for the check that catches an encoder
  /// quietly downscaling.
  final int? outputWidth;
  final int? outputHeight;

  final bool available;
  final bool writeGarbage;
  final bool writeNothing;

  /// Throws once this many progress events have been emitted.
  final int? throwsAfter;

  /// Inputs to fail on, so a run of several can have one bad file in it.
  final Set<String> failPaths;

  String? lastOutputPath;
  int encodeCount = 0;
  bool wasCancelled = false;

  @override
  Future<bool> get isAvailable async => available;

  @override
  Future<void> cancel() async {
    wasCancelled = true;
  }

  @override
  Stream<double> encode({
    required MediaCandidate candidate,
    required String outputPath,
  }) async* {
    encodeCount++;
    lastOutputPath = outputPath;

    if (failPaths.contains(candidate.path) || throwsAfter == 0) {
      throw const FileSystemException('The encoder gave up.');
    }

    if (writeNothing) {
      yield 1;

      return;
    }

    final int size = outputBytes ??
        (candidate.sizeInBytes * (shrinkTo ?? 0.33)).round();

    final Uint8List bytes = Uint8List(size);

    if (!writeGarbage) {
      final Uint8List header = jpegBytes(
        width: outputWidth ?? candidate.probe.width,
        height: outputHeight ?? candidate.probe.height,
      );

      bytes.setRange(0, header.length, header);
    }

    await File(outputPath).writeAsBytes(bytes, flush: true);

    yield 1;
  }
}

/// Records what the shade was told, and can press its Stop button.
///
/// Faked rather than driven through the real channel, for the reason
/// `MediaEncoder` is: the thing on the other side is a foreground service, and
/// nothing under `flutter test` can start one.
class FakeRunNotice implements RunNotice {
  final StreamController<void> _stopRequests = StreamController<void>.broadcast();

  final List<String> shown = <String>[];
  final List<double?> progresses = <double?>[];

  int hideCount = 0;
  int disposeCount = 0;

  bool get isShowing => shown.isNotEmpty && hideCount == 0;

  /// The user pressed Stop on the notification.
  void pressStop() => _stopRequests.add(null);

  @override
  Stream<void> get stopRequests => _stopRequests.stream;

  @override
  Future<void> show({
    required String channelName,
    required String title,
    required String text,
    required String stopLabel,
    double? progress,
  }) async {
    shown.add(text);
    progresses.add(progress);
  }

  @override
  Future<void> hide() async {
    hideCount++;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    await _stopRequests.close();
  }
}

/// Where the video encoder comes from, without a network.
///
/// The `domain/` contract, faked, which is the rule — the real
/// `FfmpegSupplyRepo` downloads a hundred megabytes from a publisher and is the
/// one thing in this feature no test may touch.
///
/// [installsEncoder] is what makes the interesting assertion possible: the bloc
/// re-asks `MediaOptimizeRepo.support()` after a fetch and must react to the new
/// answer, so a successful fetch here flips the *other* fake's support. That
/// wiring is exactly what the screen depends on and nothing else states.
class FakeEncoderSupplyRepo implements EncoderSupplyRepo {
  FakeEncoderSupplyRepo({
    this.isSupported = true,
    this.isInstalledNow = false,
    this.downloadBytes = 45 * AppByteUnits.megabyte,
    this.failure,
    this.holdOpen = false,
    this.installsEncoder,
  });

  @override
  bool isSupported;

  bool isInstalledNow;

  @override
  int downloadBytes;

  /// Ends the stream with this instead of closing it.
  Object? failure;

  /// Leaves the download running, so a test can see the panel mid-fetch and
  /// cancel it.
  bool holdOpen;

  /// Run just before the stream closes, for a fake that has to make the encoder
  /// actually appear.
  void Function()? installsEncoder;

  int fetchCount = 0;
  bool wasCancelled = false;

  @override
  Future<bool> get isInstalled async => isInstalledNow;

  @override
  EncoderSupplyJob fetch() {
    fetchCount++;

    return FakeEncoderSupplyJob(
      failure: failure,
      holdOpen: holdOpen,
      onInstalled: () {
        isInstalledNow = true;
        installsEncoder?.call();
      },
      onCancel: () => wasCancelled = true,
    );
  }
}

class FakeEncoderSupplyJob implements EncoderSupplyJob {
  FakeEncoderSupplyJob({
    Object? failure,
    bool holdOpen = false,
    void Function()? onInstalled,
    void Function()? onCancel,
  })  : _failure = failure,
        _holdOpen = holdOpen,
        _onInstalled = onInstalled,
        _onCancel = onCancel {
    _controller = StreamController<double>(onListen: _start);
  }

  final Object? _failure;
  final bool _holdOpen;
  final void Function()? _onInstalled;
  final void Function()? _onCancel;

  late final StreamController<double> _controller;

  @override
  Stream<double> get progress => _controller.stream;

  @override
  Future<void> cancel() async {
    _onCancel?.call();

    if (_controller.isClosed) {
      return;
    }

    _controller.addError(const _FetchCancelled());
    await _controller.close();
  }

  Future<void> _start() async {
    for (final double fraction in <double>[0.25, 0.75]) {
      await Future<void>.delayed(Duration.zero);

      if (_controller.isClosed) {
        return;
      }

      _controller.add(fraction);
    }

    await Future<void>.delayed(Duration.zero);

    if (_controller.isClosed) {
      return;
    }

    if (_failure != null) {
      _controller.addError(_failure);
      await _controller.close();

      return;
    }

    if (_holdOpen) {
      return;
    }

    _onInstalled?.call();
    _controller.add(1);
    await _controller.close();
  }
}

/// Stands in for `EncoderFetchCancelledFailure` without the fake importing it,
/// the way `_Cancelled` does for the scan.
class _FetchCancelled implements Exception {
  const _FetchCancelled();
}

/// The quality preference, in memory.
///
/// Hand-written like everything else here. It exists so a bloc test can assert
/// that a preset the user chose last week is in force before the first walk,
/// which is otherwise only observable through a platform channel.
class FakeOptimizeQualityRepo implements OptimizeQualityRepo {
  FakeOptimizeQualityRepo({this.stored});

  /// What an earlier run left behind. `null` is a first run.
  OptimizeQuality? stored;

  OptimizeQuality _selected = OptimizeQuality.fallback;

  int restoreCount = 0;

  @override
  OptimizeQuality get selected => _selected;

  @override
  void select(OptimizeQuality quality) {
    _selected = quality;
    stored = quality;
  }

  @override
  Future<void> restore() async {
    restoreCount++;

    final OptimizeQuality? stored = this.stored;

    if (stored != null) {
      _selected = stored;
    }
  }
}
