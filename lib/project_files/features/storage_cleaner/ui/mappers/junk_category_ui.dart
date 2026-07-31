import 'package:flutter/material.dart';

import 'package:archonex_cleaner/l10n/app_localizations.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_category.dart';

/// Everything a widget renders about a [JunkCategory].
///
/// The enum carries no copy and no icon, so translating the app is an ARB file
/// and restyling it is this one.
extension JunkCategoryUi on JunkCategory {
  String title(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return switch (this) {
      JunkCategory.appCache => l10n.categoryAppCacheTitle,
      JunkCategory.systemTemp => l10n.categorySystemTempTitle,
      JunkCategory.thumbnails => l10n.categoryThumbnailsTitle,
      JunkCategory.logs => l10n.categoryLogsTitle,
      JunkCategory.crashDumps => l10n.categoryCrashDumpsTitle,
      JunkCategory.emptyFolders => l10n.categoryEmptyFoldersTitle,
      JunkCategory.browserCache => l10n.categoryBrowserCacheTitle,
      JunkCategory.installerLeftovers => l10n.categoryInstallerLeftoversTitle,
      JunkCategory.trash => l10n.categoryTrashTitle,
    };
  }

  String subtitle(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return switch (this) {
      JunkCategory.appCache => l10n.categoryAppCacheSubtitle,
      JunkCategory.systemTemp => l10n.categorySystemTempSubtitle,
      JunkCategory.thumbnails => l10n.categoryThumbnailsSubtitle,
      JunkCategory.logs => l10n.categoryLogsSubtitle,
      JunkCategory.crashDumps => l10n.categoryCrashDumpsSubtitle,
      JunkCategory.emptyFolders => l10n.categoryEmptyFoldersSubtitle,
      JunkCategory.browserCache => l10n.categoryBrowserCacheSubtitle,
      JunkCategory.installerLeftovers =>
        l10n.categoryInstallerLeftoversSubtitle,
      JunkCategory.trash => l10n.categoryTrashSubtitle,
    };
  }

  IconData get icon => switch (this) {
        JunkCategory.appCache => Icons.apps_outlined,
        JunkCategory.systemTemp => Icons.folder_delete_outlined,
        JunkCategory.thumbnails => Icons.image_outlined,
        JunkCategory.logs => Icons.description_outlined,
        JunkCategory.crashDumps => Icons.bug_report_outlined,
        JunkCategory.emptyFolders => Icons.folder_off_outlined,
        JunkCategory.browserCache => Icons.public_outlined,
        JunkCategory.installerLeftovers => Icons.download_outlined,
        JunkCategory.trash => Icons.delete_outline,
      };
}
