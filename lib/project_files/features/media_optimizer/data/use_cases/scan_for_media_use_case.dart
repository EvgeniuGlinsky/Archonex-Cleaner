import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/media_scan_repo.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/media_kind.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/media_scan_job.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/optimize_failure.dart';
import 'package:archonex_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';

/// Starts a walk of the user's media folders.
///
/// Re-checks the guards the button already enforces, as `ScanForJunkUseCase`
/// does, so the contract holds however the call was assembled and no bloc has
/// to decide whether a platform has folders to look in.
class ScanForMediaUseCase {
  const ScanForMediaUseCase(this._repo);

  final MediaScanRepo _repo;

  Future<MediaScanJob> call({
    required Set<MediaKind> kinds,
    required StorageAccess access,
  }) async {
    if (!_repo.isSupported || !access.canScan || kinds.isEmpty) {
      throw const OptimizeUnsupportedFailure();
    }

    return _repo.scan(kinds: kinds, access: access);
  }
}
