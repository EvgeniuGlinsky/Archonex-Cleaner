import 'package:flutter/material.dart';

import 'package:archonex_cleaner/core/constants/app_spacing.dart';
import 'package:archonex_cleaner/core/theme/app_colors.dart';
import 'package:archonex_cleaner/core/theme/app_typography.dart';
import 'package:archonex_cleaner/core/utils/file_size_formatter.dart';
import 'package:archonex_cleaner/l10n/app_localizations.dart';

/// The one number the user came for, and what it is made of.
class ScanSummaryCard extends StatelessWidget {
  const ScanSummaryCard({
    required this.foundBytes,
    required this.selectedBytes,
    required this.selectedCount,
    super.key,
  });

  final int foundBytes;
  final int selectedBytes;
  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColors colors = AppColors.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              FileSizeFormatter.format(selectedBytes),
              style: AppTypography.amount(colors.freed),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${l10n.selectedSummary(l10n.fileCount(selectedCount))}'
              ' · ${l10n.foundSummary(FileSizeFormatter.format(foundBytes))}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
