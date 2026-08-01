import 'package:flutter/material.dart';

import 'package:storage_cleaner/core/constants/app_radius.dart';
import 'package:storage_cleaner/core/constants/app_spacing.dart';
import 'package:storage_cleaner/core/theme/app_colors.dart';
import 'package:storage_cleaner/core/theme/app_typography.dart';
import 'package:storage_cleaner/core/utils/file_size_formatter.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_candidate.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_group.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/ui/mappers/media_kind_ui.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/ui/widgets/media_candidate_row.dart';

/// One kind of media, collapsed to a line and openable to the files.
///
/// `JunkCategoryTile` next door is the same shape and carries the full story of
/// the narrow-phone layout bug both of them are written around: no unshrinkable
/// child on a line with flexible text unless the line is provably wide enough,
/// and the width read with `LayoutBuilder` rather than `MediaQuery`, because
/// `AppScreenLayout` caps the content far below the window.
///
/// What differs is which figure the collapsed line shows. The cleaner shows how
/// much is there, because all of it is going; this shows how much would be
/// *saved*, because the files are staying and only their weight is changing.
/// A tile reporting "12.4 GB" for a folder of videos that will still be there
/// afterwards would be answering a question nobody asked.
class MediaGroupTile extends StatelessWidget {
  const MediaGroupTile({
    required this.group,
    required this.canEdit,
    required this.onToggled,
    required this.onCandidateToggled,
    super.key,
  });

  /// The most rows drawn at once. A camera roll is thousands, and a list that
  /// long is slow to build and useless to read.
  static const int _maxVisibleRows = 200;

  static const double _markSize = 36;
  static const double _iconSize = 22;

  /// Width of the figures when they sit on the right. "−4.8 GB" over "12 files"
  /// is the widest either line gets.
  static const double _amountWidth = 92;

  /// What the name needs before the figures may take a column beside it.
  static const double _minTitleWidth = 132;

  final MediaGroup group;
  final bool canEdit;
  final VoidCallback onToggled;
  final ValueChanged<String> onCandidateToggled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Card(
      child: ExpansionTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        // In `leading`, because `trailing` replaces the rotating arrow and a row
        // that opens with nothing saying so is a row nobody opens. Absent
        // entirely where the group turned up nothing that can be acted on:
        // an unticked box and a box that does nothing look identical.
        leading: group.hasWorthwhile
            ? Checkbox(
                // `null` is the dash: ticked, with rows unticked inside it.
                value: group.isPartiallySelected ? null : group.isSelected,
                tristate: true,
                onChanged: canEdit ? (_) => onToggled() : null,
              )
            : const SizedBox(width: _checkboxWidth),
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final String? saving = group.hasWorthwhile
                  ? '−${FileSizeFormatter.format(group.estimatedSaving)}'
                  : null;
              final String? count =
                  group.isEmpty ? null : l10n.fileCount(group.totalCount);
              final bool beside =
                  saving != null && _fitsBeside(constraints.maxWidth);

              return Row(
                children: <Widget>[
                  _KindMark(group: group),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _Details(
                      group: group,
                      // Only when there is no column to put them in.
                      saving: beside ? null : saving,
                      count: beside ? null : count,
                    ),
                  ),
                  if (beside) ...<Widget>[
                    const SizedBox(width: AppSpacing.md),
                    _Amount(saving: saving, count: count ?? ''),
                  ],
                ],
              );
            },
          ),
        ),
        // A group with nothing in it has nothing to expand into, so it loses the
        // arrow — an empty list alone still draws one, which promises a row that
        // opens onto nothing.
        showTrailingIcon: !group.isEmpty,
        children: group.isEmpty
            ? const <Widget>[]
            : <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    0,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    children: <Widget>[
                      ..._visibleCandidates.map(
                        (candidate) => MediaCandidateRow(
                          candidate: candidate,
                          isExcluded: group.isExcluded(candidate.path),
                          canEdit: canEdit && group.isSelected,
                          onToggled: () => onCandidateToggled(candidate.path),
                        ),
                      ),
                      if (_hiddenCount > 0 || group.isTruncated)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Text(
                            l10n.truncatedNotice(_maxVisibleRows),
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
      ),
    );
  }

  /// Worth doing first, then the rest.
  ///
  /// Not the order the walk produced. The rows that can be acted on are the
  /// point of the screen, and burying them under forty already-efficient
  /// photographs is how a list stops being read.
  List<MediaCandidate> get _ordered =>
      <MediaCandidate>[...group.worthwhile, ...group.leftAlone];

  List<MediaCandidate> get _visibleCandidates {
    final List<MediaCandidate> ordered = _ordered;

    return ordered.length <= _maxVisibleRows
        ? ordered
        : ordered.sublist(0, _maxVisibleRows);
  }

  int get _hiddenCount => group.totalCount - _visibleCandidates.length;

  /// Whether the figures can take a column beside the name without starving it.
  static bool _fitsBeside(double rowWidth) =>
      rowWidth - _markSize - AppSpacing.md - AppSpacing.md - _amountWidth >=
      _minTitleWidth;

  static const double _checkboxWidth = 48;
}

/// The icon in its circle, tinted by whether there is anything to do.
class _KindMark extends StatelessWidget {
  const _KindMark({required this.group});

  final MediaGroup group;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColors colors = AppColors.of(context);

    final Color accent =
        group.hasWorthwhile ? colors.freed : theme.colorScheme.onSurfaceVariant;

    return Container(
      width: MediaGroupTile._markSize,
      height: MediaGroupTile._markSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Icon(
        group.kind.icon,
        size: MediaGroupTile._iconSize,
        color: accent,
      ),
    );
  }
}

/// The name, what it says about itself, and whatever the wide layout did not
/// take away into a column.
class _Details extends StatelessWidget {
  const _Details({required this.group, this.saving, this.count});

  final MediaGroup group;
  final String? saving;
  final String? count;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColors colors = AppColors.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(group.kind.title(context), style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          group.isEmpty
              ? group.kind.subtitle(context)
              : l10n.mediaGroupSummary(
                  l10n.fileCount(group.worthwhile.length),
                  l10n.fileCount(group.totalCount),
                ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (saving != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            count == null ? saving! : '$saving · $count',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.freed,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
        ],
      ],
    );
  }
}

/// The figures in a column of their own, where the row is wide enough.
///
/// A column because the one thing anybody does on this screen is compare the
/// two groups, and figures buried at different points in a sentence cannot be
/// compared without reading all of them.
class _Amount extends StatelessWidget {
  const _Amount({required this.saving, required this.count});

  final String? saving;
  final String count;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColors colors = AppColors.of(context);

    return SizedBox(
      width: MediaGroupTile._amountWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            saving ?? '',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.freed,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
          Text(
            count,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
