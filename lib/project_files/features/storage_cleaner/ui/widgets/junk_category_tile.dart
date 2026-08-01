import 'package:flutter/material.dart';

import 'package:archonex_cleaner/core/constants/app_radius.dart';
import 'package:archonex_cleaner/core/constants/app_spacing.dart';
import 'package:archonex_cleaner/core/theme/app_colors.dart';
import 'package:archonex_cleaner/core/theme/app_typography.dart';
import 'package:archonex_cleaner/core/utils/file_size_formatter.dart';
import 'package:archonex_cleaner/l10n/app_localizations.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_group.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_item.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/ui/mappers/junk_category_ui.dart';

/// One category: what it is, how much of it there is, and every row inside.
///
/// Expandable rather than always open. A user who trusts the category deletes
/// it without reading twenty thousand paths; a user who does not can open it
/// and untick the one file they recognise, which is the whole reason the
/// per-row exclusions exist.
///
/// The size wants to be a column of its own on the right, because the one thing
/// a user does on this screen is compare categories, and figures buried at
/// different points in a sentence cannot be compared without reading all of
/// them. On a phone it cannot have one, so it drops under the title instead.
///
/// That is not a preference, it is arithmetic. A 360 dp screen leaves this tile
/// 312, the row padding takes 32, the checkbox 48, its gap 16 and the expansion
/// arrow another 40: 128 reaches the mark, the text and the figures together.
/// A 92 dp column of figures out of that leaves 24 for the name, and the first
/// build of this shipped exactly that — "Установщики и архивы" drawn one letter
/// per row, eighteen rows tall.
///
/// Nothing warns about it. A `Flexible` beside a child that cannot shrink is
/// given whatever is left over, and nothing is a legal amount: there is no
/// overflow to report, so the console stays silent and only a device says
/// anything. The rule that came out of it — no unshrinkable child on a line with
/// flexible text unless the line is provably wide enough — is why the badge has
/// a line of its own here and in `AppToolCard`, and why the countdown chip has
/// one in `QuarantineBatchTile`.
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

  static const double _iconSize = 22;
  static const double _markSize = 36;

  /// Width of the figures when they sit on the right. "465.1 GB" over
  /// "1 234 файла" is the widest either line gets on a real disk.
  static const double _amountWidth = 92;

  /// What the category name needs before the figures may take a column beside
  /// it. Two words of Russian at `titleMedium` on two lines; below it they start
  /// breaking mid-word, and well below it the row becomes a staircase.
  static const double _minTitleWidth = 132;

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
        // The checkbox goes in `leading`, not `trailing`: `ExpansionTile.trailing`
        // replaces the rotating arrow, and a row that opens with no affordance
        // saying so is a row nobody opens.
        leading: Checkbox(
          // `null` is the dash: ticked, but with rows unticked inside it.
          value: group.isPartiallySelected ? null : group.isSelected,
          tristate: true,
          onChanged: canEdit ? (_) => onToggled() : null,
        ),
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _Details(
                      group: group,
                      badge: l10n.categorySecondLookBadge,
                      // Only when there is no column to put them in.
                      size: beside ? null : size,
                      count: beside ? null : count,
                    ),
                  ),
                  if (beside) ...<Widget>[
                    const SizedBox(width: AppSpacing.md),
                    _Amount(size: size, count: count!),
                  ],
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

  /// Whether the figures can take a column beside the name without starving it.
  static bool _fitsBeside(double rowWidth) =>
      rowWidth - _markSize - AppSpacing.md - AppSpacing.md - _amountWidth >=
      _minTitleWidth;
}

/// The name, the warning and whatever else has to go under them.
///
/// One widget for both arrangements, taking the figures only when there is no
/// column for them: two columns kept in step by hand is how the wide layout ends
/// up saying something the narrow one does not.
class _Details extends StatelessWidget {
  const _Details({
    required this.group,
    required this.badge,
    this.size,
    this.count,
  });

  final JunkGroup group;
  final String badge;

  /// Set only in the stacked arrangement.
  final String? size;
  final String? count;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? size = this.size;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          group.category.title(context),
          style: theme.textTheme.titleMedium,
        ),
        if (group.category.needsSecondLook) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          _SecondLookBadge(label: badge),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          group.category.subtitle(context),
          style: theme.textTheme.bodyMedium,
        ),
        if (size != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$size · $count',
            style: theme.textTheme.titleMedium?.copyWith(
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
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

/// Size over count, right-aligned, in tabular figures so a column of them lines
/// up on the decimal point instead of jittering as a scan fills them in.
///
/// Capped, and single-line: this is the child of the title row that cannot
/// shrink, so whatever it asks for comes straight out of the category name
/// beside it. `JunkCategoryTile._amountWidth` is the most it may ask.
class _Amount extends StatelessWidget {
  const _Amount({required this.size, required this.count});

  final String size;
  final String count;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: JunkCategoryTile._amountWidth,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          _Figure(
            text: size,
            style: theme.textTheme.titleMedium,
          ),
          _Figure(
            text: count,
            style: theme.textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.text, required this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
      style: style?.copyWith(fontFeatures: AppTypography.tabularFigures),
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
