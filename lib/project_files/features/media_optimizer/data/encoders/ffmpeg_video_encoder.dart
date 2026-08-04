import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:storage_cleaner/project_files/features/media_optimizer/data/encoders/ffmpeg_location.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/encoders/media_encoder.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_candidate.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_quality.dart';

/// Re-encodes a video by running an `ffmpeg` — the user's, or the one this app
/// fetched for them.
///
/// Windows, Linux and macOS. Bundling the binary is still the wrong answer for
/// the reasons it always was: a hundred megabytes of encoder inside an
/// application whose purpose is freeing disk space, paid for by every copy
/// including the ones that never open a video, and a GPL encoder *distributed*
/// rather than downloaded. What changed is the other half of it. "There is
/// nothing there, and the screen says so" left the user reading an instruction
/// to install FFmpeg and put it on their path, which is the application asking
/// somebody else to do its job — so `FfmpegSupplyRepo` fetches one on request and
/// puts it in `FfmpegLocation`, and this looks in both places.
///
/// The path is searched first and the app's own copy second. A machine with
/// `ffmpeg` already installed is a machine that downloads nothing, and a user who
/// upgrades theirs gets the upgrade.
///
/// The process is the isolation. An encoder is the one part of this app most
/// likely to crash on a malformed file, and a crash in another process is an
/// exit code rather than a dead app.
class FfmpegVideoEncoder implements MediaEncoder {
  FfmpegVideoEncoder({String pathExecutable = 'ffmpeg'})
      : _pathExecutable = pathExecutable;

  final String _pathExecutable;

  Process? _process;
  bool _isCancelling = false;

  /// Cached, and only when the answer was yes.
  ///
  /// An encoder that is there stays there, and the question costs a process
  /// launch — asked once when the screen opens rather than per file, which on a
  /// folder of two hundred videos would be two hundred launches. A *no* is not
  /// cached, and that asymmetry is the whole mechanism behind the download
  /// button: the screen re-asks after a fetch and gets the new answer, without
  /// this object knowing that a fetch is a thing that exists.
  String? _resolved;

  @override
  Future<bool> get isAvailable async => await _resolve() != null;

  /// The first of the two candidates that runs, or `null`.
  Future<String?> _resolve() async {
    final String? cached = _resolved;

    if (cached != null) {
      return cached;
    }

    final String? installed = await FfmpegLocation.installed();

    for (final String candidate in <String>[_pathExecutable, ?installed]) {
      if (await _runs(candidate)) {
        return _resolved = candidate;
      }
    }

    return null;
  }

  static Future<bool> _runs(String executable) async {
    try {
      final ProcessResult result =
          await Process.run(executable, <String>['-version']);

      return result.exitCode == 0;
    } on ProcessException {
      // Not on the path. The ordinary case, not an error.
      return false;
    }
  }

  @override
  Future<void> cancel() async {
    _isCancelling = true;
    _process?.kill();
  }

  @override
  Stream<double> encode({
    required MediaCandidate candidate,
    required String outputPath,
  }) async* {
    _isCancelling = false;

    final String? executable = await _resolve();

    if (executable == null) {
      // Reachable only if the encoder went away between the screen asking and
      // the run starting — an uninstall mid-session. Said the same way an
      // unavailable encoder says it, so the ladder above deletes its working
      // file and leaves the original alone.
      throw ProcessException(
        _pathExecutable,
        const <String>[],
        'no ffmpeg to run',
      );
    }

    final int? durationMs = candidate.probe.durationMs;

    final Process process = await Process.start(
      executable,
      _argumentsFor(candidate: candidate, outputPath: outputPath),
    );

    _process = process;

    // Drained and dropped. `ffmpeg` writes its banner and its warnings to
    // stderr and will block on a full pipe if nobody reads it, which on a long
    // encode is a hang rather than an error.
    unawaited(process.stderr.drain<void>());

    final StreamController<double> progress = StreamController<double>();

    final StreamSubscription<String> lines = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      final double? fraction = _progressFrom(line, durationMs);

      if (fraction != null && !progress.isClosed) {
        progress.add(fraction);
      }
    });

    final Future<int> exitCode = process.exitCode.whenComplete(() async {
      await lines.cancel();
      await progress.close();
    });

    yield* progress.stream;

    final int code = await exitCode;
    _process = null;

    // A killed process is a cancellation and not a failure. The caller is
    // already stopping and will delete the partial file.
    if (code != 0 && !_isCancelling) {
      throw ProcessException(
        executable,
        const <String>[],
        'ffmpeg exited with $code',
        code,
      );
    }
  }

  /// `-progress pipe:1` makes ffmpeg write `key=value` lines to stdout, one
  /// block per update, and `out_time_ms` is how far into the source it has got.
  ///
  /// Parsed rather than taken from the frame counter, because the frame count
  /// of the *output* is not known in advance on a file with a variable rate.
  /// `null` where the duration is unknown, and the bar is then indeterminate
  /// rather than invented.
  static double? _progressFrom(String line, int? durationMs) {
    if (durationMs == null || durationMs <= 0) {
      return null;
    }

    if (!line.startsWith('out_time_ms=')) {
      return null;
    }

    final int? micros = int.tryParse(line.substring('out_time_ms='.length));

    if (micros == null) {
      return null;
    }

    // Despite the name, the field is microseconds. It has been for years and
    // the name is kept for compatibility.
    return (micros / 1000 / durationMs).clamp(0.0, 1.0);
  }

  /// The command line, with the reason for each flag.
  static List<String> _argumentsFor({
    required MediaCandidate candidate,
    required String outputPath,
  }) {
    return <String>[
      // Never prompt. There is no terminal attached and a prompt is a hang.
      '-y',
      '-nostdin',
      '-i', candidate.path,
      // Every stream, not just the first of each kind. A file with two audio
      // tracks or a subtitle track must not come back with one of them missing.
      '-map', '0',
      '-c:v', 'libx265',
      '-crf', '${_presetFor(candidate).videoCrf}',
      '-preset', 'medium',
      // The tag Apple's players insist on before they will open HEVC. Without
      // it the file is valid and QuickTime refuses it.
      '-tag:v', 'hvc1',
      // Audio and subtitles carried across untouched. Re-encoding audio saves
      // single-digit megabytes on a file whose video is hundreds, and it is the
      // one part of a recording where a loss is heard rather than seen.
      '-c:a', 'copy',
      '-c:s', 'copy',
      // Metadata and chapters likewise: the date a clip was recorded is worth
      // more than the bytes it occupies.
      '-map_metadata', '0',
      // The index at the front, so the file starts playing before it has
      // finished downloading anywhere it is later shared.
      '-movflags', '+faststart',
      '-progress', 'pipe:1',
      '-loglevel', 'error',
      outputPath,
    ];
  }

  /// The preset the plan was made at, falling back to the shipped one for the
  /// reason the image encoders give.
  static OptimizeQuality _presetFor(MediaCandidate candidate) =>
      candidate.plan.preset ?? OptimizeQuality.fallback;

}
