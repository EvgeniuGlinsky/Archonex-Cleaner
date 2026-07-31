import 'package:flutter/foundation.dart';

import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/access/android_storage_access_repo.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/access/open_storage_access_repo.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/access/sandbox_storage_access_repo.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/file_system/io_junk_clean_repo.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/file_system/io_junk_scan_repo.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/junk_clean_repo.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/junk_scan_repo.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/domain/quarantine_repo.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/storage_access_repo.dart';

/// Android, iOS, macOS, Windows and Linux — everything with a file system.
///
/// The scanner and the deleter are the same class on all five: what differs per
/// platform is which rules they are given, and `JunkRuleset` answers that. Only
/// the access repository is chosen here, because only that question has five
/// genuinely different answers.
JunkScanRepo createJunkScanRepo() => IoJunkScanRepo();

/// Takes the quarantine rather than building one: it is an app-wide singleton,
/// constructed in `archonex_app.dart` because the quarantine screen reads the
/// same object this writes into.
JunkCleanRepo createJunkCleanRepo(QuarantineRepo quarantine) =>
    IoJunkCleanRepo(quarantine: quarantine);

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
