import 'package:flutter_test/flutter_test.dart';

import 'package:storage_cleaner/core/constants/app_byte_units.dart';
import 'package:storage_cleaner/core/constants/app_optimizer_policy.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/rules/savings_estimator.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_container.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_probe.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimization_plan.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_quality.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_verdict.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/video_codec.dart';

/// The methodology, pinned down.
///
/// Every branch of the estimator is a product claim — "a phone video shot in
/// H.264 is worth re-encoding", "one already in HEVC is not" — and this is the
/// file where those claims are written as arithmetic anybody can check. It is
/// deliberately built from realistic figures rather than round ones: the whole
/// question is whether the thresholds sit in the right place for files people
/// actually have, and a test using a 1000-byte photo would pass whatever the
/// numbers were.
void main() {
  MediaProbe photo({
    required MediaContainer container,
    int width = 4032,
    int height = 3024,
  }) {
    return MediaProbe(container: container, width: width, height: height);
  }

  MediaProbe video({
    VideoCodec codec = VideoCodec.h264,
    int width = 1920,
    int height = 1080,
    int seconds = 60,
    double frameRate = 30,
    MediaContainer container = MediaContainer.mp4,
  }) {
    return MediaProbe(
      container: container,
      width: width,
      height: height,
      codec: codec,
      durationMs: seconds * 1000,
      frameRate: frameRate,
    );
  }

  /// The file size a video of this shape would be at [bitsPerPixelPerFrame].
  int videoBytesAt(MediaProbe probe, double bitsPerPixelPerFrame) {
    final double seconds = probe.durationMs! / 1000;
    final double bits =
        bitsPerPixelPerFrame * probe.pixelCount * probe.frameRate! * seconds;

    return (bits / 8).round();
  }

  group('photos', () {
    test('a camera JPEG saved generously is worth re-encoding', () {
      // 12 MP at 0.5 bytes per pixel — a phone on its "high quality" setting.
      final MediaProbe probe = photo(container: MediaContainer.jpeg);
      final int size = (probe.pixelCount * 0.5).round();

      final OptimizationPlan plan =
          SavingsEstimator.plan(probe: probe, sizeInBytes: size);

      expect(plan.verdict, OptimizeVerdict.worthIt);
      expect(plan.targetContainer, MediaContainer.jpeg);
      expect(plan.preset, OptimizeQuality.fallback);
      // Roughly a third of the original, which is the claim the feature makes
      // about camera JPEGs.
      expect(plan.estimatedBytes, lessThan(size ~/ 2));
    });

    test('a JPEG that was already saved tightly is left alone', () {
      // 0.2 bytes per pixel. Re-encoding this spends quality for nothing.
      final MediaProbe probe = photo(container: MediaContainer.jpeg);
      final int size = (probe.pixelCount * 0.2).round();

      expect(
        SavingsEstimator.plan(probe: probe, sizeInBytes: size).verdict,
        OptimizeVerdict.alreadyEfficient,
      );
    });

    test('a photograph stored as PNG becomes a JPEG', () {
      // 2 bytes per pixel: lossless, and far above anything a screenshot
      // reaches.
      final MediaProbe probe = photo(container: MediaContainer.png);
      final int size = (probe.pixelCount * 2.0).round();

      final OptimizationPlan plan =
          SavingsEstimator.plan(probe: probe, sizeInBytes: size);

      expect(plan.verdict, OptimizeVerdict.worthIt);
      expect(plan.targetContainer, MediaContainer.jpeg);
    });

    test('a screenshot stays a PNG', () {
      // 0.3 bytes per pixel — flat interface colour, which PNG is better at
      // than JPEG will ever be, and where converting puts ringing round text.
      final MediaProbe probe =
          photo(container: MediaContainer.png, width: 1170, height: 2532);
      final int size = (probe.pixelCount * 0.3).round();

      expect(
        SavingsEstimator.plan(probe: probe, sizeInBytes: size).verdict,
        OptimizeVerdict.alreadyEfficient,
      );
    });

    test('a bitmap is always worth it', () {
      final MediaProbe probe = photo(container: MediaContainer.bmp);
      final int size = probe.pixelCount * 3;

      final OptimizationPlan plan =
          SavingsEstimator.plan(probe: probe, sizeInBytes: size);

      expect(plan.verdict, OptimizeVerdict.worthIt);
      expect(plan.targetContainer, MediaContainer.jpeg);
    });

    test('HEIF and WebP are refused as formats rather than judged', () {
      for (final MediaContainer container in <MediaContainer>[
        MediaContainer.heif,
        MediaContainer.webp,
        MediaContainer.gif,
      ]) {
        final MediaProbe probe = photo(container: container);

        expect(
          SavingsEstimator.plan(
            probe: probe,
            sizeInBytes: probe.pixelCount * 3,
          ).verdict,
          OptimizeVerdict.unsupportedFormat,
          reason: container.name,
        );
      }
    });

    test('a small photograph is refused on the absolute floor', () {
      // Over the bytes-per-pixel threshold, so the fraction alone would offer
      // it — but a 640×480 JPEG saves a few hundred kilobytes at best.
      final MediaProbe probe =
          photo(container: MediaContainer.jpeg, width: 640, height: 480);
      final int size = (probe.pixelCount * 0.9).round();

      expect(size, lessThan(OptimizeQuality.fallback.minimumGainBytes * 2));
      expect(
        SavingsEstimator.plan(probe: probe, sizeInBytes: size).verdict,
        OptimizeVerdict.alreadyEfficient,
      );
    });
  });

  group('videos', () {
    test('a phone clip in H.264 is worth re-encoding', () {
      // 0.15 bits per pixel per frame: what a phone writes at 1080p30, half
      // again what H.264 needs.
      final MediaProbe probe = video(seconds: 300);
      final int size = videoBytesAt(probe, 0.15);

      final OptimizationPlan plan =
          SavingsEstimator.plan(probe: probe, sizeInBytes: size);

      expect(plan.verdict, OptimizeVerdict.worthIt);
      expect(plan.targetCodec, VideoCodec.hevc);
      expect(plan.targetContainer, MediaContainer.mp4);
    });

    test('the same clip already in HEVC is left alone', () {
      // The branch that stops the app burning twenty minutes of battery for
      // three per cent.
      final MediaProbe probe = video(codec: VideoCodec.hevc, seconds: 300);
      final int size = videoBytesAt(probe, 0.06);

      expect(
        SavingsEstimator.plan(probe: probe, sizeInBytes: size).verdict,
        OptimizeVerdict.alreadyEfficient,
      );
    });

    test('an HEVC file well above its own efficient figure is still offered',
        () {
      // Being in a good codec is not the same as being encoded well. At three
      // times the efficient density there is real room in it.
      final MediaProbe probe = video(codec: VideoCodec.hevc, seconds: 300);
      final int size = videoBytesAt(probe, 0.18);

      expect(
        SavingsEstimator.plan(probe: probe, sizeInBytes: size).verdict,
        OptimizeVerdict.worthIt,
      );
    });

    test('AV1 is left alone even when large', () {
      final MediaProbe probe =
          video(codec: VideoCodec.av1, width: 3840, height: 2160, seconds: 600);
      final int size = videoBytesAt(probe, 0.05);

      expect(size, greaterThan(500 * AppByteUnits.megabyte));
      expect(
        SavingsEstimator.plan(probe: probe, sizeInBytes: size).verdict,
        OptimizeVerdict.alreadyEfficient,
      );
    });

    test('an old DivX AVI is the largest win on the list', () {
      final MediaProbe probe = video(
        codec: VideoCodec.mpeg4Part2,
        container: MediaContainer.avi,
        width: 720,
        height: 576,
        seconds: 5400,
        frameRate: 25,
      );
      final int size = videoBytesAt(probe, 0.25);

      final OptimizationPlan plan =
          SavingsEstimator.plan(probe: probe, sizeInBytes: size);

      expect(plan.verdict, OptimizeVerdict.worthIt);
      // Out of the AVI, because the stream is being rebuilt anyway and MP4 is
      // what every player opens. Never for the container alone.
      expect(plan.targetContainer, MediaContainer.mp4);
      expect(plan.estimatedBytes, lessThan(size ~/ 2));
    });

    test('a codec the header did not name is refused, not assumed', () {
      // "Probably H.264" is how a tool ends up re-encoding an archive master.
      final MediaProbe probe = video(codec: VideoCodec.unknown, seconds: 300);

      expect(
        SavingsEstimator.plan(
          probe: probe,
          sizeInBytes: videoBytesAt(probe, 0.4),
        ).verdict,
        OptimizeVerdict.unreadable,
      );
    });

    test('a video with no duration in the header is refused', () {
      const MediaProbe probe = MediaProbe(
        container: MediaContainer.mp4,
        width: 1920,
        height: 1080,
        codec: VideoCodec.h264,
        frameRate: 30,
      );

      expect(
        SavingsEstimator.plan(probe: probe, sizeInBytes: 500 * AppByteUnits.megabyte)
            .verdict,
        OptimizeVerdict.unreadable,
      );
    });

    test('an H.264 file already tighter than the target is refused', () {
      // Being in the old codec is not on its own a reason. At 0.045 this clip
      // is below what HEVC would spend, so the estimate comes out *larger* than
      // the file and there is nothing to win.
      final MediaProbe probe = video(seconds: 60);
      final int size = videoBytesAt(probe, 0.045);

      expect(
        SavingsEstimator.plan(probe: probe, sizeInBytes: size).verdict,
        OptimizeVerdict.alreadyEfficient,
      );
    });

    test('the size floor for short clips is the guard, not the estimator', () {
      // Three seconds of wasteful 1080p is only five megabytes, and the
      // estimator would happily offer it: two thirds of five megabytes clears
      // both of its thresholds. What keeps it off the list is
      // `minimumVideoBytes`, checked before the file is ever opened — which is
      // the division of labour `OptimizeGuard` documents.
      final MediaProbe probe = video(seconds: 3);
      final int size = videoBytesAt(probe, 0.2);

      expect(size, lessThan(AppOptimizerPolicy.minimumVideoBytes));
      expect(
        SavingsEstimator.plan(probe: probe, sizeInBytes: size).verdict,
        OptimizeVerdict.worthIt,
      );
    });

    test('the audio track is allowed for in the estimate', () {
      // A silent estimate would undercut the output by the size of the audio,
      // which on a long recording is not a rounding error.
      final MediaProbe probe = video(seconds: 3600);
      final OptimizationPlan plan = SavingsEstimator.plan(
        probe: probe,
        sizeInBytes: videoBytesAt(probe, 0.15),
      );

      final int videoOnly =
          videoBytesAt(probe, OptimizeQuality.fallback.targetBitsPerPixelPerFrame);
      final int audio =
          AppOptimizerPolicy.audioBitsPerSecond * 3600 ~/ 8;

      expect(plan.estimatedBytes, closeTo(videoOnly + audio, 2));
    });

    test('resolution drops out of the judgement', () {
      // The same density at 4K and at 1080p is the same answer. That is the
      // whole reason the measure is per pixel per frame rather than a bitrate.
      final MediaProbe hd = video(seconds: 300);
      final MediaProbe uhd =
          video(width: 3840, height: 2160, seconds: 300);

      expect(
        SavingsEstimator.plan(probe: hd, sizeInBytes: videoBytesAt(hd, 0.15))
            .verdict,
        SavingsEstimator.plan(probe: uhd, sizeInBytes: videoBytesAt(uhd, 0.15))
            .verdict,
      );
    });
  });

  group('the preset', () {
    test('a tighter one estimates a smaller video', () {
      final MediaProbe probe = video(seconds: 300);
      final int size = videoBytesAt(probe, 0.15);

      final int gentle = SavingsEstimator.plan(
        probe: probe,
        sizeInBytes: size,
        quality: OptimizeQuality.gentle,
      ).estimatedBytes!;
      final int balanced = SavingsEstimator.plan(
        probe: probe,
        sizeInBytes: size,
        quality: OptimizeQuality.balanced,
      ).estimatedBytes!;
      final int maximum = SavingsEstimator.plan(
        probe: probe,
        sizeInBytes: size,
        quality: OptimizeQuality.maximum,
      ).estimatedBytes!;

      expect(gentle, greaterThan(balanced));
      expect(balanced, greaterThan(maximum));
    });

    test('and offers a file the gentler one leaves alone', () {
      // The point of the switch. A video sitting just inside the gentle
      // threshold is a file the user is told nothing can be done about, and
      // pressing harder is the honest answer to "but my disk is full".
      final MediaProbe probe = video(seconds: 300);
      final int size = videoBytesAt(probe, 0.088);

      expect(
        SavingsEstimator.plan(
          probe: probe,
          sizeInBytes: size,
          quality: OptimizeQuality.gentle,
        ).isWorthIt,
        isFalse,
      );
      expect(
        SavingsEstimator.plan(
          probe: probe,
          sizeInBytes: size,
          quality: OptimizeQuality.maximum,
        ).isWorthIt,
        isTrue,
      );
    });

    test('rides along on the plan, so the encoder knows what it was', () {
      // Three encoders need three different numbers out of it — a JPEG
      // quality, an x265 CRF and a bitrate target — so the choice travels
      // rather than any one of them.
      final MediaProbe probe = video(seconds: 300);

      expect(
        SavingsEstimator.plan(
          probe: probe,
          sizeInBytes: videoBytesAt(probe, 0.15),
          quality: OptimizeQuality.maximum,
        ).preset,
        OptimizeQuality.maximum,
      );
    });
  });

  group('the thresholds', () {
    test('a saving under the fraction is refused however many bytes it is', () {
      // A four-gigabyte file losing ten per cent is four hundred megabytes, and
      // still not worth re-encoding somebody's film library for.
      final MediaProbe probe = video(width: 3840, height: 2160, seconds: 7200);
      final int estimated = SavingsEstimator.plan(
        probe: probe,
        sizeInBytes: videoBytesAt(probe, 0.15),
      ).estimatedBytes!;

      // Sized so the estimate is only a tenth below it.
      final int size = (estimated / 0.9).round();

      expect(size, greaterThan(4 * AppByteUnits.gigabyte));
      expect(
        SavingsEstimator.plan(probe: probe, sizeInBytes: size).verdict,
        OptimizeVerdict.alreadyEfficient,
      );
    });

    test('a broken probe is refused before anything else is asked', () {
      const MediaProbe probe =
          MediaProbe(container: MediaContainer.jpeg, width: 0, height: 0);

      expect(
        SavingsEstimator.plan(probe: probe, sizeInBytes: AppByteUnits.megabyte)
            .verdict,
        OptimizeVerdict.unreadable,
      );
    });

    test('a zero-byte file is refused rather than divided by', () {
      final MediaProbe probe = photo(container: MediaContainer.jpeg);

      expect(
        SavingsEstimator.plan(probe: probe, sizeInBytes: 0).verdict,
        OptimizeVerdict.unreadable,
      );
    });

    test('a skip never claims a saving', () {
      final MediaProbe probe = photo(container: MediaContainer.heif);
      final OptimizationPlan plan = SavingsEstimator.plan(
        probe: probe,
        sizeInBytes: 50 * AppByteUnits.megabyte,
      );

      expect(plan.isWorthIt, isFalse);
      expect(plan.estimatedBytes, isNull);
      expect(plan.targetContainer, isNull);
    });
  });
}
