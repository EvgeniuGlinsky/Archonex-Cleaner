import 'package:flutter/foundation.dart';

import 'package:storage_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/rules/android_junk_rules.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/rules/apple_junk_rules.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/rules/cleaner_roots.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/rules/junk_rule.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/rules/linux_junk_rules.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/rules/windows_junk_rules.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/junk_category.dart';

/// Picks the table for the platform and filters it down to what will actually
/// be scanned.
///
/// The one place the four `*_junk_rules.dart` tables are consulted, so the
/// walker never asks which platform it is on. It also drops the two kinds of
/// row that exist to be read rather than run — the ones needing elevation — in
/// one place instead of at every use.
class JunkRuleset {
  const JunkRuleset._();

  /// Everything the table for [platform] declares, including the rows that
  /// exist to be read rather than run.
  ///
  /// Public so a test can assert that a row was declared *and* dropped — a test
  /// that re-declared it would only be checking its own copy.
  static List<JunkRule> declaredFor({
    required TargetPlatform platform,
    required CleanerRoots roots,
    required StorageAccess access,
  }) {
    return switch (platform) {
      TargetPlatform.windows => WindowsJunkRules.of(roots),
      TargetPlatform.linux => LinuxJunkRules.of(roots),
      TargetPlatform.macOS => AppleJunkRules.macOS(roots),
      TargetPlatform.iOS => AppleJunkRules.iOS(roots),
      TargetPlatform.android => AndroidJunkRules.of(roots, access),
      // No file system, so no table. `UnsupportedJunkScanRepo` answers before
      // this is ever reached; the empty list is what keeps that true if it is
      // reached anyway.
      TargetPlatform.fuchsia => const <JunkRule>[],
    };
  }

  /// The rules a scan actually walks: elevation-only rows removed, and narrowed
  /// to [categories] when one is given.
  static List<JunkRule> of({
    required TargetPlatform platform,
    required CleanerRoots roots,
    required StorageAccess access,
    Set<JunkCategory>? categories,
  }) {
    return declaredFor(platform: platform, roots: roots, access: access)
        .where((rule) => !rule.needsElevation)
        .where(
          (rule) => categories == null || categories.contains(rule.category),
        )
        .toList(growable: false);
  }

  /// Which categories [platform] can produce anything for.
  ///
  /// Asked before the first scan so the screen lists the two categories iOS can
  /// fill rather than nine rows that will stay at zero for ever.
  static Set<JunkCategory> categoriesFor({
    required TargetPlatform platform,
    required CleanerRoots roots,
    required StorageAccess access,
  }) {
    final List<JunkRule> rules =
        of(platform: platform, roots: roots, access: access);

    // Declaration order of the enum is display order, so the set is rebuilt in
    // that order rather than in the order the rules happen to be listed.
    final Set<JunkCategory> present =
        rules.map((rule) => rule.category).toSet();

    return JunkCategory.values
        .where(present.contains)
        .toSet();
  }
}
