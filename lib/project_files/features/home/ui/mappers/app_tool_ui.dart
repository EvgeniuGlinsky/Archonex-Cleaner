import 'package:flutter/material.dart';

import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/home/domain/models/app_tool.dart';

/// Everything a widget renders about an [AppTool].
///
/// The enum carries no copy and no icon, for the reason `JunkCategoryUi` gives:
/// translating the app is an ARB file and restyling it is this one.
extension AppToolUi on AppTool {
  String title(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return switch (this) {
      AppTool.cleaner => l10n.toolCleanerTitle,
      AppTool.optimizer => l10n.toolOptimizerTitle,
    };
  }

  String subtitle(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return switch (this) {
      AppTool.cleaner => l10n.toolCleanerSubtitle,
      AppTool.optimizer => l10n.toolOptimizerSubtitle,
    };
  }

  IconData get icon => switch (this) {
        AppTool.cleaner => Icons.cleaning_services_rounded,
        AppTool.optimizer => Icons.compress_rounded,
      };
}
