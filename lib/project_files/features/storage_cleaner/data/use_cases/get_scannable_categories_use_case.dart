import 'package:archonex_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/junk_scan_repo.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_category.dart';

/// Which categories this platform, at this access level, can fill.
///
/// Asked on every access change rather than once: granting all-files access on
/// Android takes the list from two rows to nine, and the screen has to grow
/// with it.
class GetScannableCategoriesUseCase {
  const GetScannableCategoriesUseCase(this._repo);

  final JunkScanRepo _repo;

  Future<Set<JunkCategory>> call(StorageAccess access) =>
      _repo.categoriesFor(access);
}
