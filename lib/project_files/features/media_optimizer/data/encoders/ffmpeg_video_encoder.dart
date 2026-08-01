import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:storage_cleaner/core/constants/app_optimizer_policy.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/encoders/media_encoder.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_candidate.dart';

/// Re-encodes a video by running whatever `ffmpeg` is on the path.
///
/// Windows, Linux and macOS. A bundled binary was the obvious alternative and
/// is the wrong one twice over: it would put a hundred megabytes of encoder
/// into an application whose entire purpose is freeing disk space, and it would
/// mean shipping H.264 and HEVC encoders, which is a licensing question this
/// project has no answer to. Asking the machine what it already has costs
/// nothing and is honest — [isAvailable] is false when there is nothing there,
/// and the screen says so instead of offering a button that fails.
///
/// The process is the isolation. An encoder is the one part of this app most
/// likely to crash on a malformed file, and a crash in another process is an
/// exit code rather than a dead app.
class FfmpegVideoEncoder implements MediaEncoder {
  FfmpegVideoEncoder({String executable = 'ffmpeg'}) : _executable = executable;

  final String _executable;

  Process? _process;
  bool _isCancelling = false;

  /// Cached after the first ask.
  ///
  /// The answer does not change while the app is open, and the question costs a
  /// process launch. Asked once when the screen opens rather than per file,
  /// which on a folder of two hundred videos would be two hundred launches.
  Future<bool>? _availability;

  @override
  Future<bool> get isAvailable => _availability ??= _probeAvailability();

  Future<bool> _probeAvailability() async {
    try {
      final ProcessResult result =
          await Process.run(_executable, <String>['-version']);

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

    final int? durationMs = candidate.probe.durationMs;

    final Process process = await Process.start(
      _executable,
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
        _executable,
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
      '-crf', '${AppOptimizerPolicy.videoCrf}',
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
}
