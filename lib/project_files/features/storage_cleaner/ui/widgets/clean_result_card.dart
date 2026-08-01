import 'package:flutter/material.dart';

import 'package:storage_cleaner/core/constants/app_radius.dart';
import 'package:storage_cleaner/core/constants/app_spacing.dart';
import 'package:storage_cleaner/core/theme/app_colors.dart';
import 'package:storage_cleaner/core/theme/app_typography.dart';
import 'package:storage_cleaner/core/utils/file_size_formatter.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/clean_report.dart';

/// What the cleanup did, said in full.
///
/// Every line here exists because leaving it out would be a half-truth: the
/// files that cannot be restored, the ones that would not go, and — after a
/// cancel — that the run stopped early. A card that only shows the freed figure
/// is the version of this screen that lies by omission.
///
/// It is the one panel in the app that is tinted rather than plain, because it
/// is the one moment worth a moment: the user pressed a button that cannot be
/// undone and it worked.
class CleanResultCard extends StatelessWidget {
  const CleanResultCard({
    required this.report,
    required this.onQuarantinePressed,
    required this.onDismissed,
    super.key,
  });

  static const double _markSize = 56;
  static const double _iconSize = 30;
  static const double _tintAlpha = 0.12;

  final CleanReport report;
  final VoidCallback onQuarantinePressed;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool didFree = report.freedBytes > 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.freed.withValues(alpha: _tintAlpha),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: _markSize,
            height: _markSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.freed.withValues(alpha: _tintAlpha * 2),
            ),
            child: Icon(
              didFree ? Icons.check_rounded : Icons.remove_rounded,
              size: _iconSize,
              color: colors.freed,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FittedBox(
            child: Text(
              didFree
                  ? l10n.resultTitle(
                      FileSizeFormatter.format(report.freedBytes),
                    )
                  : l10n.resultNothingFreed,
              maxLines: 1,
              style: AppTypography.amount(colors.freed),
            ),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              if (report.isRestorable)
                TextButton(
                  onPressed: onQuarantinePressed,
                  child: Text(l10n.quarantineOpenLabel),
                )
              else
                const SizedBox.shrink(),
              TextButton(
                onPressed: onDismissed,
                child: Text(l10n.doneLabel),
              ),
            ],
          ),
        ],
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
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
