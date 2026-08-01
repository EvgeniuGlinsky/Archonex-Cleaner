import 'package:storage_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/storage_access_repo.dart';

/// Web: no file system, so no access to grant and nothing to ask for.
class UnsupportedStorageAccessRepo implements StorageAccessRepo {
  const UnsupportedStorageAccessRepo();

  @override
  Future<StorageAccess> current() async => const StorageAccess.unavailable();

  @override
  Future<StorageAccess> request() async => const StorageAccess.unavailable();

  @override
  Future<StorageAccess> addFolder() async => const StorageAccess.unavailable();
}
