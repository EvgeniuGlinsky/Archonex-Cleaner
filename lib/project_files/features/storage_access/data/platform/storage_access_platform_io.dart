import 'package:flutter/foundation.dart';

import 'package:archonex_cleaner/project_files/features/storage_access/data/access/android_storage_access_repo.dart';
import 'package:archonex_cleaner/project_files/features/storage_access/data/access/open_storage_access_repo.dart';
import 'package:archonex_cleaner/project_files/features/storage_access/data/access/sandbox_storage_access_repo.dart';
import 'package:archonex_cleaner/project_files/features/storage_access/domain/storage_access_repo.dart';

/// Android, iOS, macOS, Windows and Linux — everything with a file system.
///
/// The one question with five genuinely different answers, which is why this
/// is the only factory here.
StorageAccessRepo createStorageAccessRepo() {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => AndroidStorageAccessRepo(),
    // The sandbox is permanent on iOS, and this build of macOS has none — see
    // `Release.entitlements`.
    TargetPlatform.iOS => const SandboxStorageAccessRepo(),
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      const OpenStorageAccessRepo(),
    // No runner exists and none is planned. The sandboxed answer is the
    // conservative one: it promises nothing.
    TargetPlatform.fuchsia => const SandboxStorageAccessRepo(),
  };
}
