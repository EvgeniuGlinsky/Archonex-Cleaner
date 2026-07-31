import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/scan_update.dart';

/// One run of the scanner, exposed as a stream that can be stopped.
///
/// Implementations are built on `StreamController(onListen: _start)`, so the
/// walk begins when something subscribes rather than when the use case returns
/// — a plain controller would start crawling the disk for a screen the user has
/// already left.
///
/// The stream closing means the walk is over, not that anything was found. A
/// cancellation, and only a cancellation, ends it with `ScanCancelledFailure`;
/// nothing was deleted, so there is nothing to report and an error is the
/// honest ending. The cleanup deliberately does the opposite — see
/// `CleanReport.wasCancelled`.
abstract interface class ScanJob {
  Stream<ScanUpdate> get updates;

  Future<void> cancel();
}
