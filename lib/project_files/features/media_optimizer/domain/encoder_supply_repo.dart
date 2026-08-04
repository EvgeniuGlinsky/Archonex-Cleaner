import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/encoder_supply_job.dart';

/// Where a machine with no video encoder gets one.
///
/// The desktops have no video encoder of their own — Windows ships an H.264 one
/// and no HEVC one, and re-encoding H.264 as H.264 buys space by spending
/// quality, which is the one trade this app promises not to make. So the encoder
/// has to come from somewhere, and the screen used to say "install FFmpeg and
/// put it on your path", which is a sentence that asks the user to do the
/// application's job.
///
/// Fetched rather than bundled. Bundling would add the download to every copy of
/// the app, including the ones that never touch a video, and it would mean
/// *distributing* a GPL encoder — with the licence text and the corresponding
/// sources that obliges. Fetching on request distributes nothing: the machine
/// downloads a published build from its publisher, the way a package manager
/// would, and the app is only the thing that asked.
///
/// A separate repository from `MediaOptimizeRepo` because it answers a different
/// question with a different lifetime. That one is asked what this machine can do
/// right now; this one changes the answer. Keeping them apart is also what lets
/// the phones say "not applicable" — see `UnsupportedEncoderSupplyRepo` — rather
/// than inheriting a download nothing on Android would use.
abstract interface class EncoderSupplyRepo {
  /// Whether fetching an encoder is a thing that can be done here at all.
  ///
  /// False on the phones, where the platform's own codec is the encoder and
  /// there is nothing to fetch, and on web. A screen that reads this false and a
  /// missing encoder together is a screen that must say "this device cannot",
  /// not "press here".
  bool get isSupported;

  /// Whether an encoder this app fetched earlier is already in place.
  ///
  /// Asked so a fetch is not offered twice. It is not the same question as
  /// `MediaOptimizeRepo.support()`, which also answers true for an `ffmpeg` the
  /// user installed themselves — that one is the question about *encoding*, this
  /// is the question about *fetching*.
  Future<bool> get isInstalled;

  /// Roughly how much comes down the wire, for the sentence offering it.
  ///
  /// Stated by whichever build this platform fetches rather than averaged, so
  /// the number on the button is the number the user waits for. Zero where
  /// [isSupported] is false.
  int get downloadBytes;

  /// Starts nothing until the returned job is listened to.
  EncoderSupplyJob fetch();
}
