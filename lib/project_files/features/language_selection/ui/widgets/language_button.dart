import 'package:flutter/material.dart';

import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/language_selection/ui/language_dialog.dart';

/// The one way into the language dialog, wherever a screen puts it.
///
/// It was the same eight lines inlined on three screens, and that was fine
/// while all three put it in the same place. It stopped being fine when the two
/// tool screens moved it into `AppBar.actions` — where it has to stay put while
/// everything under it scrolls — and the home screen kept it in its header, for
/// want of an `AppBar` to hold it. One widget, two positions, no chance of the
/// tooltip or the icon drifting between them.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return IconButton(
      tooltip: l10n.languageButtonTooltip,
      icon: const Icon(Icons.language),
      onPressed: () => showLanguageDialog(context),
    );
  }
}
