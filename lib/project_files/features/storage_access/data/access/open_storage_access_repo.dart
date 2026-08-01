import 'package:archonex_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';
import 'package:archonex_cleaner/project_files/features/storage_access/domain/storage_access_repo.dart';

/// Windows, Linux and the unsandboxed macOS build: the process can already read
/// everything the rules name, and there is no dialog that would change that.
///
/// A constant rather than a stub. The three desktops genuinely have nothing to
/// ask for — a desktop process runs with the user's own rights — so the honest
/// implementation is one that always answers `full` and never offers a button.
class OpenStorageAccessRepo implements StorageAccessRepo {
  const OpenStorageAccessRepo();

  @override
  Future<StorageAccess> current() async => const StorageAccess.open();

  @override
  Future<StorageAccess> request() async => const StorageAccess.open();

  @override
  Future<StorageAccess> addFolder() async => const StorageAccess.open();
}
