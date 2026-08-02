import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/insights_update.dart';

/// One measurement in flight.
///
/// The same contract as `MediaScanJob`: nothing happens until something listens
/// to [updates], and [cancel] ends the stream with
/// `InsightsScanCancelledFailure` rather than closing it normally. A plain
/// `StreamController()` would start walking the disk the moment the use case
/// returned, for a screen the user may already have left.
abstract interface class InsightsScanJob {
  Stream<InsightsUpdate> get updates;

  /// Stop after the file being measured. Safe to call twice.
  Future<void> cancel();
}
