import 'package:storage_cleaner/core/constants/app_byte_units.dart';

/// How hard to press, as one choice the user makes once.
///
/// Six numbers move together and they are the whole of the trade this feature
/// asks the user to make. They live here rather than in `AppOptimizerPolicy`
/// because they stopped being one answer: everything left in that class is a
/// number this app has decided on the user's behalf, and everything here is a
/// number the user decides.
///
/// The values are measured rather than derived — there is no formula turning a
/// quality setting into a file size, because the answer depends on how much
/// detail the picture holds. What is in each row is what typical camera output
/// actually lands at, and the estimates lean pessimistic on purpose: a promise
/// the run does not keep is worse than an unclaimed megabyte.
///
/// [balanced] is the default and is what the app shipped as its only setting,
/// pressed a little harder — the first release aimed at 0.06 bits per pixel per
/// frame and estimated photographs at 0.22 bytes per pixel, and a real phone
/// gave back 2.6 GB out of 128. The photo figure in particular was above the
/// top of the range it was meant to cover: camera JPEGs at this quality are
/// 0.125–0.19, and the pessimism was rejecting files that would have shrunk.
///
/// Nothing here changes the *resolution*. That is the one thing this feature
/// refuses to trade at any setting, and it is why the Kotlin pipeline exists —
/// see `MediaTranscoder`.
enum OptimizeQuality {
  /// Barely visible even side by side, and it shows.
  ///
  /// For somebody who edits or prints what the camera gave them. Frees roughly
  /// half what [maximum] does.
  gentle(
    targetBitsPerPixelPerFrame: 0.075,
    videoCrf: 22,
    photoQuality: 92,
    photoTargetBytesPerPixel: 0.22,
    minimumGainFraction: 0.20,
    minimumGainBytes: 1 * AppByteUnits.megabyte,
  ),

  /// The default, and what a phone should be set to.
  ///
  /// HEVC at 0.05 is where camera footage stops improving visibly on anything
  /// smaller than a television, and JPEG at 85 is below the point where the
  /// scale is spending bytes on detail nobody sees.
  balanced(
    targetBitsPerPixelPerFrame: 0.05,
    videoCrf: 26,
    photoQuality: 85,
    photoTargetBytesPerPixel: 0.18,
    minimumGainFraction: 0.15,
    minimumGainBytes: AppByteUnits.megabyte ~/ 2,
  ),

  /// Visible if you look for it, and much smaller.
  ///
  /// For a full disk, which is the situation the app is usually opened in. The
  /// thresholds come down with the targets, because at this setting a ten per
  /// cent saving on a 4 GB film is 400 MB and worth offering.
  maximum(
    targetBitsPerPixelPerFrame: 0.035,
    videoCrf: 30,
    photoQuality: 78,
    photoTargetBytesPerPixel: 0.14,
    minimumGainFraction: 0.10,
    minimumGainBytes: AppByteUnits.megabyte ~/ 2,
  );

  const OptimizeQuality({
    required this.targetBitsPerPixelPerFrame,
    required this.videoCrf,
    required this.photoQuality,
    required this.photoTargetBytesPerPixel,
    required this.minimumGainFraction,
    required this.minimumGainBytes,
  });

  /// What a preference store that has never been written answers.
  static const OptimizeQuality fallback = balanced;

  /// Bits per pixel per frame the video re-encode aims at.
  ///
  /// Sent across the channel to `MediaTranscoder`, which keeps a constant of
  /// its own as the value to use when the argument is missing. That is a
  /// deliberate exception to the rule in the Native channels section of the
  /// skill: the figure was restated on both sides while it was fixed, and it
  /// has to be passed now that the user picks it.
  final double targetBitsPerPixelPerFrame;

  /// The x265 constant-rate factor the desktops hand to `ffmpeg`.
  ///
  /// Lower is better and larger, and it is not the same scale as
  /// [targetBitsPerPixelPerFrame] — x265 targets quality and lets the size fall
  /// where it will, and Android's encoder targets a bitrate. The two rows are
  /// matched by eye to land in the same place, and `ffmpeg` gets the easier
  /// job of the two.
  final int videoCrf;

  /// JPEG quality the photo re-encode aims at.
  final int photoQuality;

  /// What a photograph re-encoded at [photoQuality] is assumed to weigh.
  ///
  /// `integration_test/optimize_probe_test.dart` re-encodes a picture with
  /// grain on it and prints the estimate as a percentage of what actually came
  /// out. These were set from that figure and are worth re-reading whenever
  /// [photoQuality] moves.
  final double photoTargetBytesPerPixel;

  /// How much smaller the estimate has to be before a file is offered at all.
  ///
  /// Both this and [minimumGainBytes] must hold. The fraction alone would offer
  /// a two-megabyte photo for four hundred kilobytes; the absolute figure alone
  /// would offer a four-gigabyte film for the two per cent that is its
  /// container overhead.
  final double minimumGainFraction;

  /// And how much smaller in absolute terms.
  final int minimumGainBytes;
}
