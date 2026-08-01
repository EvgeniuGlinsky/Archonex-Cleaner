import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/media_scan_update.dart';

/// One walk of the user's media folders, exposed as a stream that can be
/// stopped.
///
/// Nothing happens until something listens. The implementation is built on
/// `StreamController(onListen:)` for the reason `ScanJob` is: a plain
/// controller starts crawling the disk the moment the use case returns, for a
/// screen the user may already have left.
///
/// A cancellation, and only a cancellation, ends it with
/// `MediaScanCancelledFailure`. Nothing was rewritten, so there is nothing to
/// report and an error is the honest ending — the run job deliberately does the
/// opposite, see `OptimizeReport.wasCancelled`.
abstract interface class MediaScanJob {
  Stream<MediaScanUpdate> get updates;

  /// Asks the walk to stop. Cooperative: the loop notices at the next file
  /// rather than being torn down mid-read.
  Future<void> cancel();
}
