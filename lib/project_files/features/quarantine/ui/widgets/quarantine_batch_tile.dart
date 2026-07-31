import 'package:flutter/material.dart';

import 'package:archonex_cleaner/core/constants/app_spacing.dart';
import 'package:archonex_cleaner/core/theme/app_colors.dart';
import 'package:archonex_cleaner/core/utils/file_size_formatter.dart';
import 'package:archonex_cleaner/l10n/app_localizations.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/domain/models/quarantine_batch.dart';

/// One cleanup, with the two things that can be done to it.
///
/// The days remaining are the point of the row: a batch with six days left is
/// a safety net, and one with none is about to stop being one.
class QuarantineBatchTile extends StatelessWidget {
  const QuarantineBatchTile({
    required this.batch,
    required this.now,
    required this.canAct,
    required this.onRestorePressed,
    required this.onPurgePressed,
    super.key,
  });

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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
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
            Text(
              l10n.quarantineExpiry(daysLeft),
              style: theme.textTheme.labelLarge?.copyWith(
                color: daysLeft == 0 ? colors.caution : null,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                FilledButton.tonal(
                  onPressed: canAct ? onRestorePressed : null,
                  child: Text(l10n.quarantineRestoreLabel),
                ),
                const SizedBox(width: AppSpacing.sm),
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
