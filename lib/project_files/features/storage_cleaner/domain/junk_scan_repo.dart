import 'package:archonex_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_category.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/scan_job.dart';

/// Finds junk. Deletes nothing.
///
/// Split from `JunkCleanRepo` for the reason the two halves of every converter
/// are split: reading the disk and writing to it are different risks, and a
/// test that wants a thousand fake findings should not have to hand a fake
/// deleter to the same object.
abstract interface class JunkScanRepo {
  /// Whether this platform has a file system to walk at all.
  bool get isSupported;

  /// Which categories the rules for this platform can produce.
  ///
  /// Asked before a scan so the screen shows nine categories on Windows and the
  /// two iOS can actually fill, rather than seven permanently empty rows.
  ///
  /// A `Future` because the roots the rules are built from come from a plugin.
  /// It is answered from a cache after the first call — the paths do not move
  /// while the app is running, and the granted folders arrive in [access].
  Future<Set<JunkCategory>> categoriesFor(StorageAccess access);

  /// Starts a run. Nothing happens until something listens to
  /// `ScanJob.updates` — see `ScanJob`.
  Future<ScanJob> scan({
    required Set<JunkCategory> categories,
    required StorageAccess access,
  });
}
