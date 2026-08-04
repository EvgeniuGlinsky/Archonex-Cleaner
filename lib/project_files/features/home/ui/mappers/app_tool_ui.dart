import 'package:flutter/material.dart';

import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/home/domain/models/app_tool.dart';

/// Everything a widget renders about an [AppTool].
///
/// The enum carries no copy and no icon, for the reason `JunkCategoryUi` gives:
/// translating the app is an ARB file and restyling it is this one.
extension AppToolUi on AppTool {
  /// The card's name, which is the screen's own title and not a second phrasing
  /// of it.
  ///
  /// There used to be a `toolCleanerTitle` beside `cleanerTitle` — "Clean up
  /// storage" leading to a screen headed "Free up space" — and three such pairs
  /// meant a user pressed one name and arrived at another, in three languages.
  /// The screen titles won because they are the shorter half: "See what is
  /// taking up space" set in `headlineMedium` is three lines on a phone.
  String title(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return switch (this) {
      AppTool.insights => l10n.insightsTitle,
      AppTool.cleaner => l10n.cleanerTitle,
      AppTool.optimizer => l10n.optimizerTitle,
    };
  }

  String subtitle(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return switch (this) {
      AppTool.insights => l10n.toolInsightsSubtitle,
      AppTool.cleaner => l10n.toolCleanerSubtitle,
      AppTool.optimizer => l10n.toolOptimizerSubtitle,
    };
  }

  IconData get icon => switch (this) {
        AppTool.insights => Icons.donut_large_rounded,
        AppTool.cleaner => Icons.cleaning_services_rounded,
        AppTool.optimizer => Icons.compress_rounded,
      };
}
