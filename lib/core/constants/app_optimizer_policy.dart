import 'package:storage_cleaner/core/constants/app_byte_units.dart';

/// The numbers that decide whether re-encoding a file is worth doing, and what
/// to aim at when it is.
///
/// Every one of them is a product decision rather than a technical constant,
/// which is why they are here and not scattered through `SavingsEstimator`.
///
/// What is *not* here any more is the half-dozen that move together when the
/// user picks how hard to press: the targets, the JPEG quality and the two
/// gain thresholds are `OptimizeQuality`'s now. The split is the useful one —
/// everything left in this class is a number the app decided on the user's
/// behalf, and everything over there is a number the user decides.
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
  /// Half a megabyte. Below it the best case frees a couple of hundred
  /// kilobytes and costs a full decode and encode; a camera roll holds
  /// thousands of them and the sum is still less than one video. It was a whole
  /// megabyte, which on a modern phone excluded most of what a messenger saves
  /// and every screenshot — categories that are individually small and, on a
  /// full device, collectively not.
  static const int minimumPhotoBytes = AppByteUnits.megabyte ~/ 2;

  /// Smallest video worth re-encoding.
  ///
  /// Higher than the photo floor, because the cost is different in kind: a
  /// photo is a second of CPU and a video is minutes of it, with the phone
  /// getting hot and the battery going down. Eight megabytes is roughly a
  /// seven-second 1080p clip, and it was sixteen — which quietly excluded the
  /// entire contents of a messenger's video folder, where the files are short
  /// and there are hundreds of them.
  static const int minimumVideoBytes = 8 * AppByteUnits.megabyte;

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
  /// the folder is accounted for. Raised from two thousand along with the size
  /// floors: the roots now include the folders messengers write into, where the
  /// files are small and there are a great many of them.
  static const int maxItemsPerRoot = 5000;

  /// How deep a walk may descend from a media root.
  ///
  /// Still shallower than the cleaner's twelve: these roots are the user's own
  /// folders, which people nest by year and event and not by hashed prefix.
  /// Eight rather than six because `Android/media` is itself three deep before
  /// an application's own folders begin.
  static const int maxScanDepth = 8;

  /// Prefix of the file an encode writes before it has earned the real name.
  ///
  /// Dotted so it is hidden on the platforms that hide dotfiles, and distinctive
  /// so a run interrupted by a crash can find and remove what the last one left
  /// behind. Nothing matching it is ever offered as a candidate.
  static const String workingPrefix = '.storage-cleaner-working-';

  /// What the original is renamed to for the moment between the replacement
  /// being verified and the original being dropped.
  ///
  /// The rename-rename-delete exists because replacing a file by renaming over
  /// it throws on Windows, and because the alternative — delete then rename —
  /// has a window where neither file exists.
  static const String supersededSuffix = '.storage-cleaner-old';

  /// The two names the app wrote under its working title. Read, never written.
  ///
  /// These are the only strings this app leaves on the user's disk under a name
  /// of its own, which is what separates them from the application id and the
  /// channel names renamed alongside them: those describe a build, and these
  /// describe a file that is already there. A run killed inside the swap left a
  /// `.archonex-old` beside the original — the user's photograph, under a name
  /// only the sweeper knows — and a sweeper that stopped recognising it would
  /// strand that file rather than put it back.
  ///
  /// Removable once no build old enough to have written them can still be
  /// installed anywhere. `AppOptimizerPolicy` is the one place to delete from,
  /// and `IoMediaOptimizeRepo` and `MediaRule` are the two that read them.
  static const String legacyWorkingPrefix = '.archonex-working-';

  /// The superseded suffix of the same generation. See [legacyWorkingPrefix].
  static const String legacySupersededSuffix = '.archonex-old';
}
