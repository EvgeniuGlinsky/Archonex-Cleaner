import 'package:flutter/material.dart';

import 'package:archonex_cleaner/core/constants/app_radius.dart';
import 'package:archonex_cleaner/core/constants/app_spacing.dart';
import 'package:archonex_cleaner/core/theme/app_colors.dart';
import 'package:archonex_cleaner/core/theme/app_typography.dart';
import 'package:archonex_cleaner/core/utils/file_size_formatter.dart';
import 'package:archonex_cleaner/l10n/app_localizations.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/optimize_report.dart';

/// The full outcome of a run, including the parts that are not good news.
///
/// The figure at the top is measured from the disk, not the estimate the screen
/// showed beforehand — and that distinction is the reason this card is written
/// the way it is. A tool that promises 40% and quietly reports its own promise
/// back is one nobody can check.
///
/// Everything else on it exists because it can be non-zero: files left exactly
/// as they were, files the encoder could not handle, files that came back with
/// a different name, and a run that was stopped part way. A card showing only
/// the freed figure is the version of this screen that lies by omission —
/// `CleanResultCard` next door carries the same paragraph.
class OptimizeResultCard extends StatelessWidget {
  const OptimizeResultCard({
    required this.report,
    required this.onDismissed,
    super.key,
  });

  static const double _markSize = 56;
  static const double _iconSize = 30;
  static const double _tintAlpha = 0.12;

  final OptimizeReport report;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
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
              color: colors.freed.withValues(alpha: _tintAlpha),
            ),
            child: Icon(
              didFree ? Icons.check_rounded : Icons.done_all_rounded,
              size: _iconSize,
              color: colors.freed,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            didFree
                ? l10n.optimizeFreed(FileSizeFormatter.format(report.freedBytes))
                : l10n.optimizeFreedNothing,
            textAlign: TextAlign.center,
            style: AppTypography.amount(colors.freed),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.optimizeRewroteCount(report.optimizedCount),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          ..._caveats(context, theme, l10n),
          const SizedBox(height: AppSpacing.lg),
          TextButton(onPressed: onDismissed, child: Text(l10n.doneLabel)),
        ],
      ),
    );
  }

  /// One line each, and only where the count is not zero.
  ///
  /// Separate lines rather than one sentence with three clauses: a user reading
  /// "and 2 could not be read" at the end of a paragraph is a user who has
  /// already stopped reading.
  List<Widget> _caveats(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final AppColors colors = AppColors.of(context);

    final List<(String, Color)> lines = <(String, Color)>[
      if (report.renamedCount > 0)
        (l10n.optimizeRenamedNote(report.renamedCount), colors.caution),
      if (report.skippedCount > 0)
        (l10n.optimizeSkippedNote(report.skippedCount), colors.caution),
      if (report.failedCount > 0)
        (l10n.optimizeFailedNote(report.failedCount), colors.danger),
      if (report.wasCancelled) (l10n.optimizeCancelledNote, colors.caution),
    ];

    if (lines.isEmpty) {
      return const <Widget>[];
    }

    return <Widget>[
      const SizedBox(height: AppSpacing.md),
      for (final (String text, Color colour) in lines)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: colour),
          ),
        ),
    ];
  }
}
