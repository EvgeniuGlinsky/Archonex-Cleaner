import 'package:flutter/material.dart';

import 'package:storage_cleaner/core/constants/app_radius.dart';
import 'package:storage_cleaner/core/constants/app_spacing.dart';
import 'package:storage_cleaner/core/theme/app_colors.dart';
import 'package:storage_cleaner/core/utils/file_size_formatter.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/quarantine/domain/models/quarantine_batch.dart';

/// One cleanup, with the two things that can be done to it.
///
/// The days remaining are the point of the row: a batch with six days left is
/// a safety net, and one with none is about to stop being one. That is why the
/// countdown is a chip rather than another line of grey text.
///
/// Under the title, not beside it. "Осталось 7 дней" is a chip that cannot
/// shrink, and on a narrow phone it would take its width out of the `Expanded`
/// next to it until the batch title had none left — the same trap
/// `JunkCategoryTile` documents, where the text collapses to one letter per row
/// without anything reporting an overflow.
class QuarantineBatchTile extends StatelessWidget {
  const QuarantineBatchTile({
    required this.batch,
    required this.now,
    required this.canAct,
    required this.onRestorePressed,
    required this.onPurgePressed,
    super.key,
  });

  static const double _markSize = 40;
  static const double _iconSize = 22;
  static const double _tintAlpha = 0.14;
  static const EdgeInsets _chipPadding =
      EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs);

  final QuarantineBatch batch;

  /// Passed in rather than read from `DateTime.now()` here, so a widget test
  /// can put the expiry a known number of days away.
  final DateTime now;

  final bool canAct;
  final VoidCallback onRestorePressed;
  final VoidCallback onPurgePressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColors colors = AppColors.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final int daysLeft = batch.daysLeftAt(now);
    final bool isLastDay = daysLeft == 0;
    final Color accent = isLastDay ? colors.caution : theme.colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: _markSize,
                  height: _markSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: _tintAlpha),
                  ),
                  child: Icon(
                    Icons.restore_from_trash_outlined,
                    size: _iconSize,
                    color: accent,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.quarantineBatchTitle(
                          l10n.fileCount(batch.fileCount),
                          FileSizeFormatter.format(batch.totalBytes),
                        ),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Container(
                        padding: _chipPadding,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: _tintAlpha),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          l10n.quarantineExpiry(daysLeft),
                          style: theme.textTheme.labelLarge
                              ?.copyWith(color: accent),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // A `Wrap`, not a `Row`, and not for the wrapping: `AppTheme` gives
            // every filled button `minimumSize: Size.fromHeight(…)`, whose width
            // is `infinity`, and a `Row` hands an inflexible child unbounded
            // main-axis room to ask in. The button asks for all of it and the
            // layout asserts. `StorageAccessNotice` pairs its two buttons the
            // same way, which is why that one never fell over.
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                FilledButton.tonal(
                  onPressed: canAct ? onRestorePressed : null,
                  child: Text(l10n.quarantineRestoreLabel),
                ),
                TextButton(
                  onPressed: canAct ? onPurgePressed : null,
                  child: Text(l10n.quarantinePurgeLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
