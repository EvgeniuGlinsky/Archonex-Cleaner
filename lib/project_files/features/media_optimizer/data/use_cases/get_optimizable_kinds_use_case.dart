import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/media_scan_repo.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/media_kind.dart';
import 'package:archonex_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';

/// Which kinds this platform can turn up, given what the access allows.
///
/// The optimiser's `GetScannableCategoriesUseCase`, and it exists for the same
/// reason: the answer is a rule, `MediaRuleset` owns it, and a bloc that
/// derived it from the access level would be a second copy to drift.
///
/// The case that forces it is an Android with all-files access refused.
/// `StorageAccess.canScan` is true there — the cleaner can still empty its own
/// cache — and this tool can reach nothing at all, because an app's own
/// container holds no photographs the user took. Empty, and the screen offers
/// no groups and no button.
class GetOptimizableKindsUseCase {
  const GetOptimizableKindsUseCase(this._repo);

  final MediaScanRepo _repo;

  Future<Set<MediaKind>> call(StorageAccess access) async {
    if (!_repo.isSupported) {
      return const <MediaKind>{};
    }

    return _repo.kindsFor(access);
  }
}
