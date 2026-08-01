import 'package:storage_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/storage_access_repo.dart';

/// Hand-written fake for the access question. There is no mocking package in
/// this project and none is to be added — see `CLAUDE.md`.
///
/// One file rather than one per consumer: both tools ask the same repository
/// whether they may touch the device, and a second copy of this in the
/// optimiser's fakes would be a second answer to drift out of step with.
class FakeStorageAccessRepo implements StorageAccessRepo {
  FakeStorageAccessRepo({
    this.access = const StorageAccess.open(),
    this.granted,
    this.picked,
  });

  StorageAccess access;

  /// What `request()` answers. Falls back to [access] — a refusal.
  StorageAccess? granted;

  /// What `addFolder()` answers. Falls back to [access] — a closed picker.
  StorageAccess? picked;

  int requestCount = 0;
  int addFolderCount = 0;

  @override
  Future<StorageAccess> current() async => access;

  @override
  Future<StorageAccess> request() async {
    requestCount++;
    access = granted ?? access;

    return access;
  }

  @override
  Future<StorageAccess> addFolder() async {
    addFolderCount++;
    access = picked ?? access;

    return access;
  }
}
