import 'package:flutter/material.dart';

import 'package:archonex_cleaner/core/constants/app_radius.dart';
import 'package:archonex_cleaner/core/constants/app_spacing.dart';
import 'package:archonex_cleaner/core/theme/app_colors.dart';
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

  final JunkGroup group;
  final bool canEdit;
  final VoidCallback onToggled;
  final ValueChanged<String> onItemToggled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColors colors = AppColors.of(context);
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
        title: Row(
          children: <Widget>[
            Icon(
              group.category.icon,
              size: _iconSize,
              color: group.category.needsSecondLook
                  ? colors.caution
                  : theme.colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                group.category.title(context),
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (group.category.needsSecondLook)
              _SecondLookBadge(label: l10n.categorySecondLookBadge),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            group.isEmpty
                ? group.category.subtitle(context)
                : '${FileSizeFormatter.format(group.totalBytes)}'
                    ' · ${l10n.fileCount(group.totalCount)}',
            style: theme.textTheme.bodyMedium,
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
}

class _SecondLookBadge extends StatelessWidget {
  const _SecondLookBadge({required this.label});

  static const EdgeInsets _padding =
      EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs);

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColors colors = AppColors.of(context);

    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: colors.caution.withValues(alpha: 0.15),
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
