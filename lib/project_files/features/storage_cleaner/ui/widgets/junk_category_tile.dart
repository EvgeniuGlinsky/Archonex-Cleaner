import 'package:flutter/material.dart';

import 'package:storage_cleaner/core/constants/app_radius.dart';
import 'package:storage_cleaner/core/constants/app_spacing.dart';
import 'package:storage_cleaner/core/theme/app_colors.dart';
import 'package:storage_cleaner/core/theme/app_typography.dart';
import 'package:storage_cleaner/core/utils/file_size_formatter.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/junk_group.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/junk_item.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/ui/mappers/junk_category_ui.dart';

/// One category: what it is, how much of it there is, and every row inside.
///
/// Expandable rather than always open. A user who trusts the category deletes
/// it without reading twenty thousand paths; a user who does not can open it
/// and untick the one file they recognise, which is the whole reason the
/// per-row exclusions exist.
///
/// The figures sit on the *ends of the lines they belong to* — the size beside
/// the name, the count beside the description — rather than in a column of
/// their own. That column is what the first two versions of this had, and the
/// arithmetic never let it happen. It needed 284 dp of title row and a phone
/// gave it 192, so every tile fell back to the tall arrangement: four stacked
/// lines of small text in a 144 dp column inside a 312 dp card, with the other
/// half of the card empty. Nothing was wrong with the fallback except that it
/// was the only thing anyone ever saw.
///
/// It still switches, and the switch still matters, because the trap underneath
/// it is real. A 360 dp screen leaves this tile 328, the row padding takes 24,
/// the checkbox 32, its gap 8 and the expansion arrow 24: 240 reaches the mark,
/// the text and the figures. The mark and its gap take 36 and a figure may ask
/// for [_figureWidth], which leaves the name 112 — enough. Below that the
/// figures drop under the text instead, because a `Flexible` beside a child
/// that cannot shrink is given whatever is left over and nothing is a legal
/// amount: there is no overflow to report, so the console stays silent and only
/// a device says anything. The first build of this shipped exactly that —
/// "Установщики и архивы" drawn one letter per row, eighteen rows tall. The
/// rule it left behind — no unshrinkable child on a line with flexible text
/// unless the line is provably wide enough — is why the badge has a line of its
/// own here and in `AppToolCard`, and why the countdown chip has one in
/// `QuarantineBatchTile`.
///
/// The width is read with `LayoutBuilder` rather than `MediaQuery`, per the
/// Constants section of the skill: `AppScreenLayout` caps the content far below
/// the window, so the window would say the tile is roomy when it is not.
class JunkCategoryTile extends StatelessWidget {
  const JunkCategoryTile({
    required this.group,
    required this.canEdit,
    required this.onToggled,
    required this.onItemToggled,
    super.key,
  });

  /// How many rows one category will draw before the list is cut off.
  ///
  /// A cache directory can hold thousands, and an expanded tile builds all of
  /// them at once — `ExpansionTile` has no lazy children. The rows exist to let
  /// somebody spot a file they recognise, and nobody reads past two hundred.
  static const int _maxVisibleItems = 200;

  static const double _iconSize = 18;
  static const double _markSize = 28;

  /// Width a figure may take from the line it shares. "465.1 GB" at
  /// `titleMedium` is about 72 on a device, so this has a little room in it and
  /// no more: every point of it comes out of the category name.
  static const double _figureWidth = 84;

  /// What the category name needs before a figure may sit beside it. Two words
  /// of Russian at `titleMedium` on two lines; below it they start breaking
  /// mid-word, and well below it the row becomes a staircase.
  static const double _minTitleWidth = 96;

  final JunkGroup group;
  final bool canEdit;
  final VoidCallback onToggled;
  final ValueChanged<String> onItemToggled;

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
        // The gap between the checkbox and the title, and the width reserved
        // for the checkbox itself, come from `listTileTheme` in `AppTheme` —
        // `ExpansionTile` takes neither directly, and the `ListTile` it builds
        // reads them from there.
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        // The checkbox goes in `leading`, not `trailing`: `ExpansionTile.trailing`
        // replaces the rotating arrow, and a row that opens with no affordance
        // saying so is a row nobody opens.
        leading: Checkbox(
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          // `null` is the dash: ticked, but with rows unticked inside it.
          value: group.isPartiallySelected ? null : group.isSelected,
          tristate: true,
          onChanged: canEdit ? (_) => onToggled() : null,
        ),
        // Four either side, on top of the four `ListTile` insists on. Eight is
        // what keeps a two-line name off the card's own edge; the sixteen this
        // had before was half the height the tile did not need.
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final String? size = group.isEmpty
                  ? null
                  : FileSizeFormatter.format(group.totalBytes);
              final String? count =
                  group.isEmpty ? null : l10n.fileCount(group.totalCount);
              final bool beside =
                  size != null && _fitsBeside(constraints.maxWidth);

              return Row(
                children: <Widget>[
                  _CategoryMark(
                    icon: group.category.icon,
                    needsSecondLook: group.category.needsSecondLook,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _Details(
                      group: group,
                      badge: l10n.categorySecondLookBadge,
                      size: size,
                      count: count,
                      figuresOnTheEnds: beside,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        // A category with nothing in it has nothing to expand into, so it loses
        // the arrow too — an empty list alone still draws one, which promises a
        // row that opens onto nothing.
        showTrailingIcon: !group.isEmpty,
        children: group.isEmpty
            ? const <Widget>[]
            : <Widget>[
                ..._visibleItems.map(
                  (item) => _JunkItemRow(
                    item: item,
                    isSelected:
                        group.isSelected && !group.isExcluded(item.path),
                    canEdit: canEdit && group.isSelected,
                    onToggled: () => onItemToggled(item.path),
                  ),
                ),
                // Two different truncations with one sentence between them:
                // the scan stopped early, or the list is too long to draw. The
                // user acts on both the same way — run it again after cleaning
                // — so telling them apart would be detail without a decision.
                if (_hiddenCount > 0 || group.isTruncated)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: Text(
                      l10n.truncatedNotice(_maxVisibleItems),
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
              ],
      ),
    );
  }

  List<JunkItem> get _visibleItems => group.items.length <= _maxVisibleItems
      ? group.items
      : group.items.sublist(0, _maxVisibleItems);

  int get _hiddenCount => group.items.length - _visibleItems.length;

  /// Whether a figure can sit on the end of a line without starving the text.
  static bool _fitsBeside(double rowWidth) =>
      rowWidth - _markSize - AppSpacing.sm - AppSpacing.sm - _figureWidth >=
      _minTitleWidth;
}

/// The name, the warning, the description, and the figures wherever they fit.
///
/// One widget for both arrangements, taking a flag rather than two different
/// sets of arguments: two columns kept in step by hand is how the wide layout
/// ends up saying something the narrow one does not.
class _Details extends StatelessWidget {
  const _Details({
    required this.group,
    required this.badge,
    required this.figuresOnTheEnds,
    this.size,
    this.count,
  });

  final JunkGroup group;
  final String badge;

  /// `null` until the scan has put something in this category.
  final String? size;
  final String? count;

  /// The size beside the name and the count beside the description, rather than
  /// both on a line of their own underneath.
  final bool figuresOnTheEnds;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? size = this.size;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Line(
          text: Text(
            group.category.title(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
          figure: figuresOnTheEnds && size != null
              ? _Figure(text: size, style: theme.textTheme.titleMedium)
              : null,
        ),
        const SizedBox(height: AppSpacing.xs),
        _Line(
          text: Text(
            group.category.subtitle(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          figure: figuresOnTheEnds && count != null
              ? _Figure(text: count!, style: theme.textTheme.labelLarge)
              : null,
        ),
        if (size != null && !figuresOnTheEnds) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$size · $count',
            style: theme.textTheme.titleMedium?.copyWith(
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
        ],
        if (group.category.needsSecondLook) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          _SecondLookBadge(label: badge),
        ],
      ],
    );
  }
}

/// Flexible text with an optional figure pinned to the end of it.
///
/// The figure is the child that cannot shrink, so it is capped and never wraps;
/// `JunkCategoryTile._fitsBeside` is what decides whether it may be here at all.
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

class _CategoryMark extends StatelessWidget {
  const _CategoryMark({required this.icon, required this.needsSecondLook});

  final IconData icon;
  final bool needsSecondLook;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColors colors = AppColors.of(context);
    final Color tint =
        needsSecondLook ? colors.caution : theme.colorScheme.primary;

    return Container(
      width: JunkCategoryTile._markSize,
      height: JunkCategoryTile._markSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tint.withValues(alpha: _tintAlpha),
      ),
      child: Icon(icon, size: JunkCategoryTile._iconSize, color: tint),
    );
  }

  static const double _tintAlpha = 0.14;
}

/// A number on the end of a line, in tabular figures so a column of them lines
/// up on the decimal point instead of jittering as a scan fills them in.
///
/// Capped and single-line: this is the child of the row that cannot shrink, so
/// whatever it asks for comes straight out of the text beside it.
/// [JunkCategoryTile._figureWidth] is the most it may ask.
class _Figure extends StatelessWidget {
  const _Figure({required this.text, required this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: JunkCategoryTile._figureWidth,
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

class _SecondLookBadge extends StatelessWidget {
  const _SecondLookBadge({required this.label});

  static const EdgeInsets _padding =
      EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs);
  static const double _tintAlpha = 0.15;

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColors colors = AppColors.of(context);

    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: colors.caution.withValues(alpha: _tintAlpha),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(color: colors.caution),
      ),
    );
  }
}

class _JunkItemRow extends StatelessWidget {
  const _JunkItemRow({
    required this.item,
    required this.isSelected,
    required this.canEdit,
    required this.onToggled,
  });

  final JunkItem item;
  final bool isSelected;
  final bool canEdit;
  final VoidCallback onToggled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return CheckboxListTile(
      dense: true,
      value: isSelected,
      onChanged: canEdit ? (_) => onToggled() : null,
      controlAffinity: ListTileControlAffinity.trailing,
      title: Text(
        item.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        FileSizeFormatter.format(item.sizeInBytes),
        style: theme.textTheme.labelLarge,
      ),
      secondary: item.isDirectory
          ? const Icon(Icons.folder_outlined)
          : const Icon(Icons.insert_drive_file_outlined),
    );
  }
}
