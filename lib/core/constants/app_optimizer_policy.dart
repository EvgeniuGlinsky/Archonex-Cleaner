import 'package:storage_cleaner/core/constants/app_byte_units.dart';

/// The numbers that decide whether re-encoding a file is worth doing, and what
/// to aim at when it is.
///
/// Every one of them is a product decision rather than a technical constant,
/// which is why they are here and not scattered through `SavingsEstimator`. The
/// two that matter most are [minimumGainFraction] and the per-codec efficiency
/// figures on `VideoCodec`: together they are the difference between a tool
/// that frees forty per cent of a camera roll and a tool that spends twenty
/// minutes of battery to free three per cent.
///
/// The bytes-per-pixel figures are measured rather than derived. There is no
/// formula that turns a quality setting into a file size — it depends entirely
/// on how much detail the picture holds — so these are the sizes typical camera
/// output actually lands at, and the estimator is honest that they are
/// estimates. The real figure is reported after the run, from the disk.
class AppOptimizerPolicy {
  const AppOptimizerPolicy._();

  /// Nothing written more recently than this is offered.
  ///
  /// The same reason the cleaner has an age floor, for a different file: a
  /// video ninety seconds old is still being written by the camera app, and
  /// rewriting a growing file produces a broken one. An hour is long enough
  /// that the recording finished and short enough that today's clips are
  /// offered today.
  static const Duration minimumAge = Duration(hours: 1);

  /// Smallest photo worth re-encoding.
  ///
  /// Below a megabyte the best case frees a few hundred kilobytes and costs a
  /// full decode and encode. A camera roll has thousands of these and the sum
  /// of the savings is still less than one video.
  static const int minimumPhotoBytes = 1 * AppByteUnits.megabyte;

  /// Smallest video worth re-encoding.
  ///
  /// Higher than the photo floor by a lot, because the cost is different in
  /// kind: a photo is a second of CPU and a video is minutes of it, with the
  /// phone getting hot and the battery going down. Sixteen megabytes is roughly
  /// a fifteen-second 1080p clip.
  static const int minimumVideoBytes = 16 * AppByteUnits.megabyte;

  /// How much smaller the estimate has to be before a file is offered.
  ///
  /// A fifth. Below that the user is being asked to re-encode their photograph
  /// library for a rounding error, and the honest answer is that the file is
  /// already about as small as it goes. This is also why changing the container
  /// alone is never offered: MKV to MP4 moves the same video stream into a
  /// different box and frees well under one per cent.
  static const double minimumGainFraction = 0.20;

  /// And how much smaller in absolute terms.
  ///
  /// Both must hold. Twenty per cent of a two-megabyte photo is four hundred
  /// kilobytes, which is a real fraction of nothing.
  static const int minimumGainBytes = 1 * AppByteUnits.megabyte;

  /// JPEG quality the re-encode aims at.
  ///
  /// High enough that the difference is not visible on a phone screen at any
  /// zoom a person actually uses, low enough to halve a camera JPEG. The brief
  /// allowed up to a tenth of the quality; this spends rather less than that
  /// and takes most of the size anyway, because the top of the quality scale is
  /// where the bytes are and the detail is not.
  static const int photoQuality = 88;

  /// What a photograph re-encoded at [photoQuality] weighs per pixel.
  ///
  /// Deliberately on the pessimistic side. An estimate that is too low makes
  /// the app promise savings it will not deliver, and the number on the screen
  /// before the run is the one the user decides on.
  ///
  /// Camera content at this quality is usually quoted at 1.0–1.5 bits per
  /// pixel, which is 0.125–0.19 bytes. This sits above the top of that range
  /// because grain defeats the transform and a real sensor produces grain:
  /// `integration_test/optimize_probe_test.dart` re-encodes a picture with some
  /// on it and prints the estimate as a percentage of what actually came out.
  /// It was set from that figure and is worth re-reading whenever
  /// [photoQuality] moves.
  static const double photoTargetBytesPerPixel = 0.22;

  /// Above this, a lossily-compressed photo has room in it.
  ///
  /// Camera output at the "high quality" setting lands around 0.30–0.60 and an
  /// editor exporting at maximum quality goes past 1.0. Below it the file is
  /// already tight and re-encoding would spend quality for very little.
  static const double photoWorthwhileBytesPerPixel = 0.30;

  /// Above this, a PNG is a photograph rather than a screenshot.
  ///
  /// PNG is lossless, so its size follows how much detail is in the picture: a
  /// screenshot of flat interface colour lands at 0.1–0.4 bytes per pixel and a
  /// photograph at 1.5–3. That single number is what tells the two apart, and
  /// the difference matters because converting a screenshot to JPEG puts
  /// ringing around every letter of text while saving very little.
  static const double pngPhotographicBytesPerPixel = 1.0;

  /// Bits per pixel per frame the video re-encode aims at.
  ///
  /// HEVC at roughly this is where camera footage stops improving visibly. See
  /// `VideoCodec.efficientBitsPerPixelPerFrame` for what each source codec is
  /// measured against.
  static const double targetBitsPerPixelPerFrame = 0.06;

  /// How far above its codec's efficient figure a video may sit and still be
  /// left alone.
  ///
  /// Without the tolerance, a file encoded sensibly but not perfectly would be
  /// re-encoded for a handful of per cent. A quarter is the band inside which
  /// the answer is "this is fine".
  static const double efficientTolerance = 1.25;

  /// Audio is copied, not re-encoded, and this is what it is assumed to weigh.
  ///
  /// Re-encoding it would save single-digit megabytes on a file where the video
  /// stream is measured in hundreds, and it is the one part of a recording
  /// where a loss is heard rather than seen. 128 kbit/s is what phones record
  /// AAC at; the estimate only has to be close.
  static const int audioBitsPerSecond = 128000;

  /// The x265 constant-rate factor used on the desktops.
  ///
  /// Lower is better and larger. 24 is a little tighter than the commonly cited
  /// 28 default, chosen because this app rewrites the user's originals and has
  /// no undo: the cost of being one notch too conservative is some unclaimed
  /// megabytes, and the cost of being one notch too aggressive is somebody's
  /// holiday footage.
  static const int videoCrf = 24;

  /// How much smaller the output must actually be before it replaces the input.
  ///
  /// Checked against the finished file, not the estimate. An encoder that
  /// produced something the same size or larger has done nothing useful, and
  /// the original stays where it is.
  static const double verifyMinShrinkFraction = 0.05;

  /// How far a re-encoded video's duration may drift from the original's.
  ///
  /// A transcode that dropped frames or stopped early produces a shorter file,
  /// and length is the one property of a video cheap enough to verify. One per
  /// cent covers the frame-boundary rounding an honest encoder does.
  static const double durationTolerance = 0.01;

  /// Findings handed to the UI in one go.
  ///
  /// Smaller than the cleaner's batch because each finding here costs a header
  /// read rather than a `stat`, so they arrive slowly enough that a large batch
  /// would make the list look stalled.
  static const int foundBatchSize = 16;

  /// How long a partial batch waits before being flushed anyway.
  static const Duration foundFlushInterval = Duration(milliseconds: 250);

  /// Findings kept per root before the walk moves on.
  ///
  /// A camera roll of more than this is real, and the ones past the limit are
  /// still there for the next run. It bounds what the app holds in memory while
  /// the user decides, and the scan says it stopped early rather than implying
  /// the folder is accounted for.
  static const int maxItemsPerRoot = 2000;

  /// How deep a walk may descend from a media root.
  ///
  /// Shallower than the cleaner's twelve: these roots are the user's own
  /// folders, which people nest by year and event and not by hashed prefix.
  static const int maxScanDepth = 6;

  /// Prefix of the file an encode writes before it has earned the real name.
  ///
  /// Dotted so it is hidden on the platforms that hide dotfiles, and distinctive
  /// so a run interrupted by a crash can find and remove what the last one left
  /// behind. Nothing matching it is ever offered as a candidate.
  ///
  /// Named for the publisher rather than the product, alongside the application
  /// id and the transcoder's channel names. These two strings are written onto
  /// the user's disk, so renaming them with the product would strand the
  /// leavings of a crash the previous version never got to sweep — a file the
  /// user owns, left under a suffix nothing recognises any more.
  static const String workingPrefix = '.archonex-working-';

  /// What the original is renamed to for the moment between the replacement
  /// being verified and the original being dropped.
  ///
  /// The rename-rename-delete exists because replacing a file by renaming over
  /// it throws on Windows, and because the alternative — delete then rename —
  /// has a window where neither file exists.
  static const String supersededSuffix = '.archonex-old';
}
