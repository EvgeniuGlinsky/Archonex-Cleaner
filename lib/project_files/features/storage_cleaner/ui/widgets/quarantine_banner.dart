import 'package:flutter/material.dart';

import 'package:archonex_cleaner/core/constants/app_radius.dart';
import 'package:archonex_cleaner/core/constants/app_spacing.dart';
import 'package:archonex_cleaner/l10n/app_localizations.dart';

/// The reminder that the last cleanup can still be taken back.
///
/// On the cleaner screen rather than only on the quarantine one, because the
/// moment a user realises they wanted something back is the moment they are
/// looking at the screen that removed it.
class QuarantineBanner extends StatelessWidget {
  const QuarantineBanner({
    required this.fileCount,
    required this.onPressed,
    super.key,
  });

  static const double _iconSize = 20;

  final int fileCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Material(
      color: theme.colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.restore_from_trash_outlined,
                size: _iconSize,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.quarantineBannerTitle(fileCount),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
