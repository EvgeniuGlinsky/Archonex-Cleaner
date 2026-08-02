import 'package:storage_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/insights_scan_job.dart';

/// Adds up what is on the volume, and changes nothing.
///
/// The read-only third of the app, beside `JunkScanRepo` and `MediaScanRepo`.
/// It has no deleting or rewriting counterpart at all and never will: this
/// screen exists to answer a question, and the two things a user might do about
/// the answer are the two tools that already exist.
///
/// It is a size-only walk — `stat` and an extension, never an open — which is
/// what makes it perhaps ten times faster than the optimiser's over the same
/// files. That is the whole reason it is a separate repository rather than a
/// mode of that one.
abstract interface class StorageInsightsRepo {
  /// Whether this platform has a volume the app can walk at all.
  bool get isSupported;

  /// Starts a measurement. Nothing happens until something listens to
  /// `InsightsScanJob.updates`.
  Future<InsightsScanJob> measure(StorageAccess access);
}
