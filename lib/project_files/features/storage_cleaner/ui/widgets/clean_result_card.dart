import 'package:flutter/material.dart';

import 'package:archonex_cleaner/core/constants/app_spacing.dart';
import 'package:archonex_cleaner/core/theme/app_colors.dart';
import 'package:archonex_cleaner/core/theme/app_typography.dart';
import 'package:archonex_cleaner/core/utils/file_size_formatter.dart';
import 'package:archonex_cleaner/l10n/app_localizations.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/clean_report.dart';

/// What the cleanup did, said in full.
///
/// Every line here exists because leaving it out would be a half-truth: the
/// files that cannot be restored, the ones that would not go, and — after a
/// cancel — that the run stopped early. A card that only shows the freed figure
/// is the version of this screen that lies by omission.
class CleanResultCard extends StatelessWidget {
  const CleanResultCard({
    required this.report,
    required this.onQuarantinePressed,
    required this.onDismissed,
    super.key,
  });

  final CleanReport report;
  final VoidCallback onQuarantinePressed;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              report.freedBytes > 0
                  ? l10n.resultTitle(
                      FileSizeFormatter.format(report.freedBytes),
                    )
                  : l10n.resultNothingFreed,
              style: AppTypography.amount(colors.freed),
            ),
            const SizedBox(height: AppSpacing.md),
            if (report.quarantinedCount > 0)
              _Line(text: l10n.resultQuarantined(report.quarantinedCount)),
            if (report.permanentCount > 0)
              _Line(text: l10n.resultPermanent(report.permanentCount)),
            if (report.skippedCount > 0)
              _Line(text: l10n.resultSkipped(report.skippedCount)),
            if (report.wasCancelled) _Line(text: l10n.resultCancelled),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                if (report.isRestorable)
                  TextButton(
                    onPressed: onQuarantinePressed,
                    child: Text(l10n.quarantineOpenLabel),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: onDismissed,
                  child: Text(l10n.doneLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
