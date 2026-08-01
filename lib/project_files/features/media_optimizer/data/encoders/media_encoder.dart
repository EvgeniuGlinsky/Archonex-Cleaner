import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_candidate.dart';

/// One way of turning a file into a smaller file, whatever is behind it.
///
/// The seam the whole feature is tested through. Behind it sit four completely
/// different things — a pure-Dart codec, a platform plugin, a Kotlin
/// `MediaCodec` pipeline and an `ffmpeg` process — and none of them can run
/// under `flutter test`. In front of it, `IoMediaOptimizeRepo` contains the
/// part that must not lose a file, and a fake here is what lets that part be
/// driven through every branch it has.
///
/// It lives in `data/` rather than `domain/` on purpose. It is not a
/// repository and nothing above the data layer knows it exists: the bloc asks
/// for a run, and which encoder serves it is settled on the platform boundary.
abstract interface class MediaEncoder {
  /// Whether this machine can do it *right now*.
  ///
  /// A real question, not a property of the platform. The desktop encoder is
  /// whatever `ffmpeg` is on the path and there may not be one, and an Android
  /// device may have no HEVC encoder in its media stack. Asked once when the
  /// screen opens, so it can say "these four videos would save 6 GB, and this
  /// machine cannot re-encode them" instead of offering a button that fails.
  Future<bool> get isAvailable;

  /// Writes a smaller version of [candidate] to [outputPath].
  ///
  /// Emits progress from 0 to 1 where the encoder reports it, and nothing at
  /// all where it does not — the bar is then indeterminate rather than
  /// invented. Completing normally means the file was written; it does *not*
  /// mean the result is any good, and the caller checks that. Throwing means
  /// nothing usable is at [outputPath], and the caller deletes whatever is.
  ///
  /// The encoder never touches the original and never touches the destination
  /// the original will end up at. Everything about replacing a file is the
  /// caller's, in one place, for the reason that ladder documents.
  Stream<double> encode({
    required MediaCandidate candidate,
    required String outputPath,
  });

  /// Stops a run in flight. The partial output is the caller's to delete.
  Future<void> cancel();
}

/// The sibling for a platform, or a machine, that cannot do this kind at all.
///
/// Named for what it does rather than `unsupported_`, following
/// `EmptyQuarantineRepo`: it is not broken, there is simply no encoder here.
/// `isAvailable` is false, which is what the screen reads, and `encode` errors
/// rather than returning silently — a stream that closes with no output would
/// look to the ladder above exactly like a successful encode that produced
/// nothing.
class UnavailableEncoder implements MediaEncoder {
  const UnavailableEncoder();

  @override
  Future<bool> get isAvailable async => false;

  @override
  Stream<double> encode({
    required MediaCandidate candidate,
    required String outputPath,
  }) {
    return Stream<double>.error(
      StateError('No encoder on this platform for ${candidate.kind.name}.'),
    );
  }

  @override
  Future<void> cancel() async {}
}
