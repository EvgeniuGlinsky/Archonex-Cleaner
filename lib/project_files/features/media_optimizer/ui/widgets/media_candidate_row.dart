import 'package:flutter/material.dart';

import 'package:storage_cleaner/core/constants/app_spacing.dart';
import 'package:storage_cleaner/core/theme/app_colors.dart';
import 'package:storage_cleaner/core/theme/app_typography.dart';
import 'package:storage_cleaner/core/utils/file_size_formatter.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_candidate.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/ui/mappers/optimize_verdict_ui.dart';

/// One file, and either what would be saved or why nothing will be.
///
/// Two rows in one widget rather than two widgets, because they differ by one
/// trailing element and share the name, the truncation and the resolution line
/// — and two files would be two places to fix the next time a phone turns a
/// long file name into a staircase.
///
/// The actionable row gets a checkbox and an arrow: `1.8 GB → ~940 MB`. The
/// other gets no checkbox at all and its reason instead, because a row that
/// cannot be ticked and a row that is merely unticked must not look the same.
class MediaCandidateRow extends StatelessWidget {
  const MediaCandidateRow({
    required this.candidate,
    required this.isExcluded,
    required this.canEdit,
    required this.onToggled,
    super.key,
  });

  static const double _gap = AppSpacing.sm;

  final MediaCandidate candidate;
  final bool isExcluded;
  final bool canEdit;
  final VoidCallback onToggled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColors colors = AppColors.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final bool isActionable = candidate.isWorthIt;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (isActionable)
            // Compact and shrink-wrapped, like the two group tiles above it.
            // Left at its defaults this was 48 across against their 32, so the
            // rows inside a group indented further than the group's own name
            // and the file names lost 16 dp for nothing.
            Checkbox(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              value: !isExcluded,
              onChanged: canEdit ? (_) => onToggled() : null,
            )
          else
            // The width a checkbox would have taken, so the names line up down
            // the column whether or not a row can be acted on.
            const SizedBox(width: _placeholderWidth),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  candidate.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  isActionable
                      ? l10n.candidateSaving(
                          FileSizeFormatter.format(candidate.sizeInBytes),
                          FileSizeFormatter.format(
                            candidate.plan.estimatedBytes ?? 0,
                          ),
                        )
                      : l10n.candidateLeftAlone(
                          FileSizeFormatter.format(candidate.sizeInBytes),
                          candidate.plan.verdict.reason(context) ?? '',
                        ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isActionable
                        ? colors.freed
                        : theme.colorScheme.onSurfaceVariant,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
          if (candidate.changesExtension) ...<Widget>[
            const SizedBox(width: _gap),
            Tooltip(
              message: l10n.candidateRenamedTooltip,
              child: Icon(
                Icons.drive_file_rename_outline,
                size: _iconSize,
                color: colors.caution,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// What a compact `Checkbox` occupies, so an unactionable row indents to
  /// match one.
  static const double _placeholderWidth = 32;
  static const double _iconSize = 18;
}
