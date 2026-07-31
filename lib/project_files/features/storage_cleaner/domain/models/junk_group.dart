import 'package:equatable/equatable.dart';

import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_category.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_item.dart';

/// Everything one category turned up, and how much of it the user has agreed
/// to delete.
///
/// The agreement is stored as the *exclusions* rather than the selection: a
/// scan that keeps finding files while the user is already unticking rows would
/// otherwise have to decide whether each new finding counts as selected, and
/// every answer to that is surprising to someone. Excluded, a row the user has
/// touched stays untouched and everything else follows the category.
final class JunkGroup extends Equatable {
  const JunkGroup({
    required this.category,
    required this.items,
    required this.isSelected,
    this.excludedPaths = const <String>{},
    this.isTruncated = false,
  });

  /// A group as a fresh scan produces it, before the user has said anything.
  JunkGroup.fresh(this.category)
      : items = const <JunkItem>[],
        isSelected = category.selectedByDefault,
        excludedPaths = const <String>{},
        isTruncated = false;

  final JunkCategory category;

  /// The findings, in the order the walk produced them.
  final List<JunkItem> items;

  /// Whether the category as a whole is ticked.
  final bool isSelected;

  /// Rows the user unticked by hand. Only meaningful while [isSelected].
  final Set<String> excludedPaths;

  /// Whether the walk stopped at `AppCleanPolicy.maxItemsPerRule` with more
  /// still there. The screen says so rather than implying the number below is
  /// everything.
  final bool isTruncated;

  int get totalCount => items.length;

  int get totalBytes =>
      items.fold(0, (sum, item) => sum + item.sizeInBytes);

  bool get isEmpty => items.isEmpty;

  /// What a cleanup would actually take from this group.
  List<JunkItem> get selectedItems {
    if (!isSelected) {
      return const <JunkItem>[];
    }

    if (excludedPaths.isEmpty) {
      return items;
    }

    return items
        .where((item) => !excludedPaths.contains(item.path))
        .toList(growable: false);
  }

  int get selectedCount => selectedItems.length;

  int get selectedBytes =>
      selectedItems.fold(0, (sum, item) => sum + item.sizeInBytes);

  /// Whether the group is ticked but not entirely — what draws the tristate box.
  bool get isPartiallySelected =>
      isSelected && excludedPaths.isNotEmpty && selectedCount > 0;

  bool isExcluded(String path) => excludedPaths.contains(path);

  JunkGroup copyWith({
    List<JunkItem>? items,
    bool? isSelected,
    Set<String>? excludedPaths,
    bool? isTruncated,
  }) {
    return JunkGroup(
      category: category,
      items: items ?? this.items,
      isSelected: isSelected ?? this.isSelected,
      excludedPaths: excludedPaths ?? this.excludedPaths,
      isTruncated: isTruncated ?? this.isTruncated,
    );
  }

  /// Appends findings, which is the only way [items] ever grows — a scan
  /// streams and the group is rebuilt per batch.
  JunkGroup withMore(Iterable<JunkItem> found) => copyWith(
        items: <JunkItem>[...items, ...found],
      );

  /// Flips one row, and nothing else.
  JunkGroup toggleItem(String path) => copyWith(
        excludedPaths: excludedPaths.contains(path)
            ? (Set<String>.from(excludedPaths)..remove(path))
            : (Set<String>.from(excludedPaths)..add(path)),
      );

  @override
  List<Object?> get props => <Object?>[
        category,
        items,
        isSelected,
        excludedPaths,
        isTruncated,
      ];
}
