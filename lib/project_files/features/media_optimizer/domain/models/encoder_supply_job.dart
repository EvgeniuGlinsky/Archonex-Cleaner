/// One attempt to put a video encoder on this machine, as a stream that can be
/// stopped.
///
/// Nothing happens until something listens, for the reason `MediaScanJob` gives:
/// a plain `StreamController` would start a hundred-megabyte download the moment
/// the use case returned, for a screen the user may already have left.
///
/// The stream carries the fraction downloaded and ends by closing. Closing is
/// the success — there is nothing to report but the encoder now being there, and
/// the screen re-asks what the machine can do rather than taking a report's word
/// for it. A failure ends the stream with an `OptimizeFailure`; a cancellation
/// ends it with `EncoderFetchCancelledFailure`, because a half-downloaded
/// archive is not an encoder and nothing was installed.
///
/// [Stream<double>] rather than an update hierarchy: the only thing worth saying
/// during a download is how far along it is, and the phases it passes through —
/// fetch, verify, unpack — are not decisions the user makes. They are folded
/// into the one fraction, which is what a progress bar can show.
abstract interface class EncoderSupplyJob {
  /// `0`–`1` of the download. Never `null`: the publisher sends a content
  /// length, and a bar that could be indeterminate here would be indeterminate
  /// for the minutes this takes.
  Stream<double> get progress;

  /// Asks the download to stop. Cooperative: it ends at the next chunk rather
  /// than tearing the socket down mid-write, and whatever was written is
  /// deleted.
  Future<void> cancel();
}
