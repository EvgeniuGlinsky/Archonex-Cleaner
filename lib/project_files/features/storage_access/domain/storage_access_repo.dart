import 'package:storage_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';

/// Answers where the app is allowed to look, and asks for more.
///
/// Its own interface rather than two methods on `JunkScanRepo`, because on five
/// of the six platforms there is nothing to ask and the implementation is a
/// constant — see `OpenStorageAccessRepo`. Only Android has a real one.
abstract interface class StorageAccessRepo {
  /// What is granted right now. Cheap, and re-read on every screen entry: the
  /// user can revoke all-files access from Settings while the app is backgrounded.
  Future<StorageAccess> current();

  /// Opens the platform's permission flow, then re-reads.
  ///
  /// Returns the access that ended up granted, which may be the same one it
  /// started with — a refusal is an answer, not an error.
  Future<StorageAccess> request();

  /// Adds one folder through the system picker.
  ///
  /// Returns the access unchanged when the user closed the picker.
  Future<StorageAccess> addFolder();

  /// Opens the system settings page where a refused permission can be undone.
  ///
  /// Returns nothing, and deliberately: the app is leaving the foreground, and
  /// whatever the user does there is read back by [current] when they return.
  /// A refusal the system has stopped asking about is only reversible here, so
  /// on the platforms with no such page this is a no-op rather than an error —
  /// they are the platforms that never report `isPermanentlyDenied` either.
  Future<void> openSettings();
}
