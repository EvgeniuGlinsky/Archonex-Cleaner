import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_kind.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_scan_job.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';

/// Finds the user's large photos and videos and works out what could be done
/// about each, and rewrites nothing.
///
/// Split from `MediaOptimizeRepo` the way `JunkScanRepo` is split from
/// `JunkCleanRepo`: reading the device and rewriting it are different risks,
/// and the half that only reads is the half a probe can run against a real
/// machine without anybody worrying.
abstract interface class MediaScanRepo {
  /// Whether this platform has media folders the app can reach at all.
  ///
  /// False on web, and on iOS — the photo library lives behind an API that
  /// hands out copies rather than paths, and the container this app can see
  /// holds nothing the user put there.
  bool get isSupported;

  /// Which kinds the rules for this platform and this access level can produce.
  ///
  /// A narrowed Android with one picked folder can still turn up both, so this
  /// answers what the *rules* cover rather than what the disk holds.
  Future<Set<MediaKind>> kindsFor(StorageAccess access);

  /// Starts a walk. Nothing happens until something listens to
  /// `MediaScanJob.updates`.
  Future<MediaScanJob> scan({
    required Set<MediaKind> kinds,
    required StorageAccess access,
  });
}
