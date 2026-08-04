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
/// both the narrow-phone layout bug these are written around and the reason the
/// figures now sit on the ends of the lines they belong to instead of in a
/// column of their own. Every number here — the mark, the gaps, the figure cap
/// and the width a name needs before a figure may share its line — is that
/// file's, restated rather than imported, because a tile that quietly followed
/// its neighbour's constants would break the moment the neighbour changed for
/// reasons of its own.
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
    required this.isVerdictKnown,
    required this.onToggled,
    required this.onCandidateToggled,
    super.key,
  });

  /// The most rows drawn at once. A camera roll is thousands, and a list that
  /// long is slow to build and useless to read.
  static const int _maxVisibleRows = 200;

  static const double _markSize = 24;
  static const double _iconSize = 16;

  /// Width a figure may take from the line it shares. "−4.8 GB" is the widest
  /// either of them gets, and `JunkCategoryTile._figureWidth` carries the rest
  /// of why it stayed at this number while everything around it shrank.
  static const double _figureWidth = 84;

  /// What the name needs before a figure may sit beside it.
  static const double _minTitleWidth = 96;

  /// A compact `Checkbox`, and the placeholder that stands in for it where the
  /// group has nothing worth ticking.
  static const double _checkboxWidth = 32;

  final MediaGroup group;
  final bool canEdit;

  /// Whether a walk has finished having a look at this group — see
  /// `MediaOptimizerState.isVerdictKnown`. It is what tells "found nothing worth
  /// doing" from "has not looked yet", which a `MediaGroup` cannot say for
  /// itself.
  final bool isVerdictKnown;

  final VoidCallback onToggled;
  final ValueChanged<String> onCandidateToggled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Card(
      child: ExpansionTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        // The leading width, the gap after it and the height floor come from
        // `listTileTheme` in `AppTheme`, and the radius is restated from
        // `cardTheme` — both for the reasons `JunkCategoryTile` gives.
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        // In `leading`, because `trailing` replaces the rotating arrow and a row
        // that opens with nothing saying so is a row nobody opens. Absent
        // entirely where a walk has looked and turned up nothing that can be
        // acted on: an unticked box and a box that does nothing look identical.
        //
        // Present before that walk, though, which it was not: an unscanned group
        // has no worthwhile files either, and for a while that read as the same
        // case. It left the two rows on this screen with no box at all while the
        // cleaner drew three beside its own, on a screen whose bloc toggles them
        // perfectly well and keeps the answer across the scan. The cleaner has
        // the same story written into `StorageCleanerState.canEditSelection`.
        leading: group.hasWorthwhile || !isVerdictKnown
            ? Checkbox(
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                // `null` is the dash: ticked, with rows unticked inside it.
                value: group.isPartiallySelected ? null : group.isSelected,
                tristate: true,
                onChanged: canEdit ? (_) => onToggled() : null,
              )
            : const SizedBox(width: _checkboxWidth),
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
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
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _Details(
                      group: group,
                      saving: saving,
                      count: count,
                      figuresOnTheEnds: beside,
                    ),
                  ),
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

  /// Whether a figure can sit on the end of a line without starving the text.
  static bool _fitsBeside(double rowWidth) =>
      rowWidth - _markSize - AppSpacing.sm - AppSpacing.sm - _figureWidth >=
      _minTitleWidth;
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

/// The name, what the group says about itself, and the figures wherever they
/// fit — beside the lines they belong to, or stacked underneath on a screen too
/// narrow for that.
class _Details extends StatelessWidget {
  const _Details({
    required this.group,
    required this.figuresOnTheEnds,
    this.saving,
    this.count,
  });

  final MediaGroup group;

  /// `null` where there is nothing worth re-encoding in this group.
  final String? saving;

  /// `null` until the walk has put something in it.
  final String? count;

  final bool figuresOnTheEnds;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColors colors = AppColors.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String? saving = this.saving;

    final TextStyle? savingStyle = theme.textTheme.titleMedium?.copyWith(
      color: colors.freed,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Line(
          text: Text(
            group.kind.title(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
          figure: figuresOnTheEnds && saving != null
              ? _Figure(text: saving, style: savingStyle)
              : null,
        ),
        const SizedBox(height: AppSpacing.xs),
        _Line(
          text: Text(
            group.isEmpty
                ? group.kind.subtitle(context)
                : l10n.mediaGroupSummary(
                    l10n.fileCount(group.worthwhile.length),
                    l10n.fileCount(group.totalCount),
                  ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          figure: figuresOnTheEnds && count != null
              ? _Figure(text: count!, style: theme.textTheme.labelLarge)
              : null,
        ),
        if (saving != null && !figuresOnTheEnds) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            count == null ? saving : '$saving · $count',
            style: savingStyle?.copyWith(
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
        ],
      ],
    );
  }
}

/// Flexible text with an optional figure pinned to the end of it.
///
/// The same shape as `JunkCategoryTile`'s, and for the same reason: the figure
/// is the child that cannot shrink, so it is capped and never wraps.
class _Line extends StatelessWidget {
  const _Line({required this.text, this.figure});

  final Widget text;
  final Widget? figure;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Expanded(child: text),
        if (figure != null) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          figure!,
        ],
      ],
    );
  }
}

/// A number on the end of a line, capped at [MediaGroupTile._figureWidth] and
/// set in tabular figures so a pair of tiles can be compared at a glance.
class _Figure extends StatelessWidget {
  const _Figure({required this.text, required this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: MediaGroupTile._figureWidth,
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        style: style?.copyWith(fontFeatures: AppTypography.tabularFigures),
      ),
    );
  }
}
