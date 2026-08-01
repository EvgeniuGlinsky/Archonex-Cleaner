import 'package:archonex_cleaner/project_files/features/storage_access/data/access/unsupported_storage_access_repo.dart';
import 'package:archonex_cleaner/project_files/features/storage_access/domain/storage_access_repo.dart';

/// Web: no file system, so no access to grant and nothing to ask for.
StorageAccessRepo createStorageAccessRepo() =>
    const UnsupportedStorageAccessRepo();
