import 'package:storage_cleaner/core/constants/app_optimizer_policy.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_container.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_kind.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_probe.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimization_plan.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_quality.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_verdict.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/video_codec.dart';

/// Decides whether re-encoding a file would free enough to be worth doing, and
/// what to turn it into.
///
/// This is the file the feature is actually about. Everything around it walks
/// directories and moves bytes; the question of *which* files are worth
/// touching is answered here, in one pure function, with no file system and no
/// platform anywhere near it.
///
/// The method is the same for both kinds and it has one idea in it: compare how
/// many bytes a file spends per unit of picture against how many that format
/// needs. Raw size says nothing — a 4 GB film is efficient and a 40 MB
/// ten-second clip is not — and neither does bitrate on its own, because a 4K
/// clip legitimately needs four times what a 1080p one does. Dividing by the
/// pixel count, and for video by the frame rate as well, is what removes
/// resolution from the question and leaves the part that is a judgement.
///
/// ## What is deliberately not offered
///
/// **Changing the container alone.** An MKV rewrapped as an MP4 copies the
/// video stream byte for byte into a different box and frees well under one per
/// cent. It looks like it should help and it does not. MKV and AVI files here
/// are converted because they are being re-encoded anyway, never for the box.
///
/// **Anything already in HEVC or AV1 at a sensible bitrate.** This is the
/// branch that matters most for a phone: it is what stops the app spending
/// twenty minutes of battery and a hot device to free three per cent of one
/// video.
///
/// **HEIF, WebP and AVIF.** Already the efficient answer for a photograph. Not
/// a gap in the encoders — re-encoding one would spend quality to arrive at a
/// size it is already at.
///
/// **Screenshots.** A PNG of flat interface colour is the one case where PNG
/// beats JPEG outright, and converting it puts ringing around every letter of
/// text while saving very little. Told apart from a photograph by bytes per
/// pixel alone — see `AppOptimizerPolicy.pngPhotographicBytesPerPixel`.
///
/// ## On the estimates
///
/// They are estimates and are labelled as such everywhere they are shown. There
/// is no formula turning a quality setting into a file size, because the answer
/// depends on how much detail the picture holds; the figures in
/// `AppOptimizerPolicy` are what typical camera output actually lands at, and
/// they lean pessimistic on purpose. An estimate that is too generous makes the
/// app promise savings it will not deliver, and the number on the screen before
/// the run is the one the user decides on. `OptimizeReport.freedBytes` is the
/// other number, measured from the disk afterwards, and the result card shows
/// both.
class SavingsEstimator {
  const SavingsEstimator._();

  /// What to do about one file.
  ///
  /// [sizeInBytes] is the file on disk; [probe] is what its header said. A
  /// probe that did not come back complete is refused here rather than guessed
  /// at — see `MediaProbe.isComplete`.
  ///
  /// [quality] defaults to the shipped one. The default is here so that the
  /// twenty-odd tests about the *rule* — is a screenshot left alone, is an
  /// unknown codec refused — can be read without a preset in every line; the
  /// one production caller passes it, and a test asserts that it does.
  static OptimizationPlan plan({
    required MediaProbe probe,
    required int sizeInBytes,
    OptimizeQuality quality = OptimizeQuality.fallback,
  }) {
    if (!probe.isComplete || sizeInBytes <= 0) {
      return const OptimizationPlan.skip(OptimizeVerdict.unreadable);
    }

    return switch (probe.kind) {
      MediaKind.photo => _photo(probe, sizeInBytes, quality),
      MediaKind.video => _video(probe, sizeInBytes, quality),
    };
  }

  // ---------------------------------------------------------------- photos --

  static OptimizationPlan _photo(
    MediaProbe probe,
    int sizeInBytes,
    OptimizeQuality quality,
  ) {
    final double bytesPerPixel = sizeInBytes / probe.pixelCount;

    return switch (probe.container) {
      // Lossy already. Worth re-encoding only where the first encode was
      // generous — a camera at "high quality" or an editor exporting at
      // maximum.
      MediaContainer.jpeg =>
        bytesPerPixel > AppOptimizerPolicy.photoWorthwhileBytesPerPixel
            ? _asJpeg(probe, sizeInBytes, quality)
            : const OptimizationPlan.skip(OptimizeVerdict.alreadyEfficient),

      // Lossless, so the size follows the detail, and the detail is what says
      // whether this is a photograph or a screenshot.
      MediaContainer.png =>
        bytesPerPixel > AppOptimizerPolicy.pngPhotographicBytesPerPixel
            ? _asJpeg(probe, sizeInBytes, quality)
            : const OptimizationPlan.skip(OptimizeVerdict.alreadyEfficient),

      // Barely compressed at all: three or four bytes per pixel, straight out
      // of a scanner or an old editor. Always a large win.
      MediaContainer.bmp ||
      MediaContainer.tiff =>
        _asJpeg(probe, sizeInBytes, quality),

      // Already the efficient answer, or animation this tool has no business
      // flattening.
      //
      // HEIF stays on this list at every preset, and that is not a gap waiting
      // to be filled. Turning a HEIC into a JPEG usually produces a *larger*
      // file at worse quality: the format is a decade newer and roughly twice
      // as efficient, so the honest answer is that the phone already did this.
      MediaContainer.heif ||
      MediaContainer.webp ||
      MediaContainer.gif =>
        const OptimizationPlan.skip(OptimizeVerdict.unsupportedFormat),

      // A video container reached the photo branch, which means the probe and
      // the enum disagree. Refuse rather than encode something as a JPEG.
      _ => const OptimizationPlan.skip(OptimizeVerdict.unreadable),
    };
  }

  static OptimizationPlan _asJpeg(
    MediaProbe probe,
    int sizeInBytes,
    OptimizeQuality quality,
  ) {
    final int estimated =
        (probe.pixelCount * quality.photoTargetBytesPerPixel).round();

    if (!_isWorthIt(
      sizeInBytes: sizeInBytes,
      estimatedBytes: estimated,
      quality: quality,
    )) {
      return const OptimizationPlan.skip(OptimizeVerdict.alreadyEfficient);
    }

    return OptimizationPlan.reencode(
      targetContainer: MediaContainer.jpeg,
      estimatedBytes: estimated,
      preset: quality,
    );
  }

  // ---------------------------------------------------------------- videos --

  static OptimizationPlan _video(
    MediaProbe probe,
    int sizeInBytes,
    OptimizeQuality quality,
  ) {
    final VideoCodec codec = probe.codec ?? VideoCodec.unknown;
    final double? efficient = codec.efficientBitsPerPixelPerFrame;

    // An unknown codec could be anything from a lossless intermediate to
    // something already better than HEVC. "Probably H.264" is how a tool ends
    // up re-encoding an archive master.
    if (efficient == null) {
      return const OptimizationPlan.skip(OptimizeVerdict.unreadable);
    }

    final double seconds = probe.durationMs! / 1000;
    final double pixelRate = probe.pixelCount * probe.frameRate!;
    final double bitsPerPixelPerFrame = (sizeInBytes * 8 / seconds) / pixelRate;

    // Already at least as good as what this app would produce, and not spending
    // wildly more than it needs to. Left alone whatever its size.
    if (codec.isAtLeastAsGoodAsTarget &&
        bitsPerPixelPerFrame <= efficient * AppOptimizerPolicy.efficientTolerance) {
      return const OptimizationPlan.skip(OptimizeVerdict.alreadyEfficient);
    }

    final int estimated = _estimatedVideoBytes(
      pixelRate: pixelRate,
      seconds: seconds,
      quality: quality,
    );

    if (!_isWorthIt(
      sizeInBytes: sizeInBytes,
      estimatedBytes: estimated,
      quality: quality,
    )) {
      return const OptimizationPlan.skip(OptimizeVerdict.alreadyEfficient);
    }

    return OptimizationPlan.reencode(
      // MP4 whatever went in. It is the container every player and every
      // gallery on every platform opens, and the stream is being rebuilt
      // anyway, so there is nothing to be gained by keeping a Matroska box that
      // half the devices in the house cannot read.
      targetContainer: MediaContainer.mp4,
      targetCodec: VideoCodec.hevc,
      estimatedBytes: estimated,
      preset: quality,
    );
  }

  /// The video stream at the target density, plus the audio track carried
  /// across untouched.
  ///
  /// Audio is copied rather than re-encoded — it is single-digit megabytes on a
  /// file whose video is measured in hundreds, and it is the one part of a
  /// recording where a loss is heard rather than seen — so its bytes survive
  /// the run and have to be in the estimate. Assumed at
  /// `AppOptimizerPolicy.audioBitsPerSecond` rather than measured, because a
  /// track that is not there costs the estimate a per cent and a track that is
  /// costs nothing to allow for.
  static int _estimatedVideoBytes({
    required double pixelRate,
    required double seconds,
    required OptimizeQuality quality,
  }) {
    final double videoBits =
        quality.targetBitsPerPixelPerFrame * pixelRate * seconds;
    final double audioBits = AppOptimizerPolicy.audioBitsPerSecond * seconds;

    return ((videoBits + audioBits) / 8).round();
  }

  // ----------------------------------------------------------------- both ---

  /// Both thresholds, and both have to hold.
  ///
  /// The fraction alone would offer a two-megabyte photo for four hundred
  /// kilobytes; the absolute figure alone would offer a four-gigabyte film for
  /// the two per cent that is its container overhead.
  static bool _isWorthIt({
    required int sizeInBytes,
    required int estimatedBytes,
    required OptimizeQuality quality,
  }) {
    if (estimatedBytes >= sizeInBytes) {
      return false;
    }

    final int saving = sizeInBytes - estimatedBytes;

    return saving >= quality.minimumGainBytes &&
        saving / sizeInBytes >= quality.minimumGainFraction;
  }
}
