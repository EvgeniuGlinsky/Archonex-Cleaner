import 'package:archonex_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/junk_scan_repo.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/clean_failure.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_category.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/scan_job.dart';

/// Starts a scan, after checking the two things the screen might have got wrong.
///
/// The guards repeat what the button already enforces, on purpose: the engine
/// contract has to hold however the call was assembled, and a bloc is not the
/// place that decides whether a platform has a file system.
class ScanForJunkUseCase {
  const ScanForJunkUseCase(this._repo);

  final JunkScanRepo _repo;

  Future<ScanJob> call({
    required Set<JunkCategory> categories,
    required StorageAccess access,
  }) async {
    if (!_repo.isSupported || !access.canScan) {
      throw const CleanUnsupportedFailure();
    }

    return _repo.scan(categories: categories, access: access);
  }
}
