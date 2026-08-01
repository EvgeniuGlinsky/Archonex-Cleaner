import 'package:flutter/material.dart';

import 'package:storage_cleaner/core/constants/app_radius.dart';
import 'package:storage_cleaner/core/constants/app_spacing.dart';
import 'package:storage_cleaner/core/theme/app_colors.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';
import 'package:storage_cleaner/project_files/features/storage_access/ui/mappers/storage_access_ui.dart';

/// Says what the scan will and will not cover, and offers the way to widen it.
///
/// Drawn only when there is something to say — `StorageAccess.isNarrowed` — so
/// a desktop, where the app can already see everything, never shows it. Both
/// tools draw it, which is why it moved out of the cleaner along with the rest
/// of the access question.
class StorageAccessNotice extends StatelessWidget {
  const StorageAccessNotice({
    required this.access,
    required this.onGrantPressed,
    required this.onAddFolderPressed,
    required this.onOpenSettingsPressed,
    super.key,
  });

  static const double _iconSize = 20;

  final StorageAccess access;
  final VoidCallback onGrantPressed;
  final VoidCallback onAddFolderPressed;

  /// Offered instead of *Grant* once the system has stopped showing the sheet.
  ///
  /// Never beside it: the two are the same intention taking the only route
  /// still open to it, and a screen showing both would be offering a button the
  /// platform has already decided will do nothing.
  final VoidCallback onOpenSettingsPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColors colors = AppColors.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.info_outline,
                size: _iconSize,
                color: colors.caution,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  access.title(context),
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(access.body(context), style: theme.textTheme.bodyMedium),
          if (access.canRequestMore ||
              access.isPermanentlyDenied ||
              access.canAddFolder) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                if (access.canRequestMore)
                  FilledButton.tonal(
                    onPressed: onGrantPressed,
                    child: Text(l10n.accessGrantLabel),
                  )
                else if (access.isPermanentlyDenied)
                  FilledButton.tonal(
                    onPressed: onOpenSettingsPressed,
                    child: Text(l10n.accessSettingsLabel),
                  ),
                if (access.canAddFolder)
                  TextButton(
                    onPressed: onAddFolderPressed,
                    child: Text(l10n.accessAddFolderLabel),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
