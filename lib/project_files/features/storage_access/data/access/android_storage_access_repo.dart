import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:storage_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/storage_access_repo.dart';

/// The only implementation with anything to do.
///
/// Android is the one platform where what may be read changes at runtime, and
/// it changes in two directions: all-files access, which covers the device, and
/// the folder picker, which covers one folder at a time. Both are offered,
/// because the first can be refused and the second is then the only route left.
///
/// The granted folders are held in memory for the session rather than
/// persisted. A picked folder is a decision about *this* cleanup; remembering
/// it would mean scanning, weeks later, a folder the user picked once and has
/// forgotten agreeing to.
class AndroidStorageAccessRepo implements StorageAccessRepo {
  AndroidStorageAccessRepo();

  final List<String> _grantedFolders = <String>[];

  @override
  Future<StorageAccess> current() async {
    // Re-read every time. The permission is revocable from Settings while the
    // app sits in the background, and a cached `full` would send the walk at
    // directories it can no longer open.
    final PermissionStatus status =
        await Permission.manageExternalStorage.status;

    return _accessFor(status);
  }

  @override
  Future<StorageAccess> request() async {
    final PermissionStatus status =
        await Permission.manageExternalStorage.request();

    // `permanentlyDenied` on this permission means the system will not show the
    // sheet again, and only the Settings screen will do. Offering *Grant* a
    // second time would be a button that visibly does nothing.
    return _accessFor(status);
  }

  @override
  Future<StorageAccess> addFolder() async {
    final String? picked = await FilePicker.getDirectoryPath();

    if (_isUsable(picked) && !_grantedFolders.contains(picked)) {
      _grantedFolders.add(picked!);
    }

    return current();
  }

  @override
  Future<void> openSettings() => openAppSettings();

  /// Whether the picker gave back a path `dart:io` can actually walk.
  ///
  /// It hands back `/` for a folder Android refuses to resolve to a real path —
  /// a storage-access URI the plugin could not turn into one — and a rule
  /// rooted at `/` would be a scan of the whole device by accident. `null` is
  /// the user closing the dialog, which is the same non-event.
  static bool _isUsable(String? path) =>
      path != null && path.isNotEmpty && path != '/';

  StorageAccess _accessFor(PermissionStatus status) {
    if (status.isGranted) {
      return const StorageAccess(
        level: StorageAccessLevel.full,
        canRequestMore: false,
        canAddFolder: false,
      );
    }

    return StorageAccess(
      // A folder handed over by the picker is more than the app's own cache and
      // less than the device, which is exactly what `scopedFolders` means.
      level: _grantedFolders.isEmpty
          ? StorageAccessLevel.appOnly
          : StorageAccessLevel.scopedFolders,
      grantedRoots: List<String>.unmodifiable(_grantedFolders),
      canRequestMore: !status.isPermanentlyDenied,
      canAddFolder: true,
      // Carried rather than left to be inferred from `!canRequestMore`, which
      // is also true of iOS. The two produce the same buttons and completely
      // different sentences, and this is the field that tells them apart.
      isPermanentlyDenied: status.isPermanentlyDenied,
    );
  }
}
