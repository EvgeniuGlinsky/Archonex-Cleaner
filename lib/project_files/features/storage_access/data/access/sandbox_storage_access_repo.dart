import 'package:archonex_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';
import 'package:archonex_cleaner/project_files/features/storage_access/domain/storage_access_repo.dart';

/// iOS: the container, permanently, and no permission exists that widens it.
///
/// The opposite of `AndroidStorageAccessRepo` in the one way that matters:
/// both report `appOnly`, and here `canRequestMore` is false, so the screen
/// explains the sandbox instead of offering a button that would do nothing.
/// That distinction is why `StorageAccess` carries the flag as a field rather
/// than deriving it from the level.
///
/// It is also what a sandboxed macOS build would use, if one is ever made for
/// the Mac App Store — see `Release.entitlements`.
class SandboxStorageAccessRepo implements StorageAccessRepo {
  const SandboxStorageAccessRepo();

  @override
  Future<StorageAccess> current() async => const StorageAccess.sandboxed();

  @override
  Future<StorageAccess> request() async => const StorageAccess.sandboxed();

  @override
  Future<StorageAccess> addFolder() async => const StorageAccess.sandboxed();
}
