import 'dart:async';

import 'package:storage_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/insights_failure.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/insights_scan_job.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/insights_update.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/storage_insights_repo.dart';

/// The answer where there is no volume to walk: web, and iOS.
///
/// `Unsupported…` rather than a name of its own, because it genuinely refuses —
/// unlike `EmptyQuarantineRepo`, which answers correctly. `isSupported` is what
/// the screen reads, and the job errors rather than closing empty: a stream
/// that ended with nothing measured would draw a chart of a disk with nothing
/// on it, which is the one thing it is certainly not saying.
class UnsupportedStorageInsightsRepo implements StorageInsightsRepo {
  const UnsupportedStorageInsightsRepo();

  @override
  bool get isSupported => false;

  @override
  Future<InsightsScanJob> measure(StorageAccess access) async =>
      const _RefusingScanJob();
}

class _RefusingScanJob implements InsightsScanJob {
  const _RefusingScanJob();

  @override
  Stream<InsightsUpdate> get updates =>
      Stream<InsightsUpdate>.error(const InsightsUnsupportedFailure());

  @override
  Future<void> cancel() async {}
}
