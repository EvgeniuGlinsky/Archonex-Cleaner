import 'package:storage_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/insights_failure.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/insights_scan_job.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/storage_insights_repo.dart';

/// Starts a measurement of the volume.
///
/// Re-checks the guard the button already enforces, as `ScanForJunkUseCase` and
/// `ScanForMediaUseCase` do, so the contract holds however the call was
/// assembled.
class MeasureStorageUseCase {
  const MeasureStorageUseCase(this._repo);

  final StorageInsightsRepo _repo;

  Future<InsightsScanJob> call(StorageAccess access) async {
    if (!_repo.isSupported || !access.canScan) {
      throw const InsightsUnsupportedFailure();
    }

    return _repo.measure(access);
  }
}
