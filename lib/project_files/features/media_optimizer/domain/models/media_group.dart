import 'package:equatable/equatable.dart';

import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_candidate.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_kind.dart';

/// Everything one kind of media turned up, and how much of it the user has
/// agreed to have rewritten.
///
/// The same shape as `JunkGroup` and for the same reason: the agreement is
/// stored as the *exclusions*, never as the selection, because a walk that is
/// still finding files while the user unticks rows would otherwise have to
/// decide whether each new finding counts as agreed to.
///
/// What differs is that only some rows can be ticked at all. [candidates] holds
/// every media file the walk measured; [worthwhile] holds the ones the
/// estimator said something could be done about, and it is the only list the
/// checkboxes and the totals ever look at. The rest are shown with their
/// verdict and no box, because a row that cannot be actioned and a row that is
/// merely unticked must not look the same.
final class MediaGroup extends Equatable {
  const MediaGroup({
    required this.kind,
    required this.candidates,
    required this.isSelected,
    this.excludedPaths = const <String>{},
    this.isTruncated = false,
  });

  /// A group as a fresh scan produces it, before the user has said anything.
  ///
  /// Ticked by default. Unlike the cleaner, where three categories arrive off
  /// because they are occasionally the only copy of something, nothing here is
  /// destroyed: the picture stays, at the same resolution, in the same place.
  ///
  /// [isSelected] is passed as false for a kind this machine has no encoder for.
  /// It has to be settable rather than always true, because `canOptimize` needs
  /// an encoder for every ticked group: a desktop with no `ffmpeg` that found
  /// both photographs and video had the video group ticked, which turned the
  /// button off for the photographs as well — the one kind it could have
  /// re-encoded.
  const MediaGroup.fresh(this.kind, {this.isSelected = true})
      : candidates = const <MediaCandidate>[],
        excludedPaths = const <String>{},
        isTruncated = false;

  final MediaKind kind;

  /// Every media file measured, in the order the walk produced them.
  final List<MediaCandidate> candidates;

  final bool isSelected;

  /// Rows the user unticked by hand. Only meaningful while [isSelected].
  final Set<String> excludedPaths;

  /// Whether the walk stopped at `AppOptimizerPolicy.maxItemsPerRoot` with more
  /// still there.
  final bool isTruncated;

  bool get isEmpty => candidates.isEmpty;

  int get totalCount => candidates.length;

  /// The ones something can be done about.
  List<MediaCandidate> get worthwhile => candidates
      .where((candidate) => candidate.isWorthIt)
      .toList(growable: false);

  /// The ones nothing can be done about, each carrying its reason.
  List<MediaCandidate> get leftAlone => candidates
      .where((candidate) => !candidate.isWorthIt)
      .toList(growable: false);

  bool get hasWorthwhile => candidates.any((candidate) => candidate.isWorthIt);

  /// What a run would actually rewrite.
  List<MediaCandidate> get selectedCandidates {
    if (!isSelected) {
      return const <MediaCandidate>[];
    }

    final List<MediaCandidate> worth = worthwhile;

    if (excludedPaths.isEmpty) {
      return worth;
    }

    return worth
        .where((candidate) => !excludedPaths.contains(candidate.path))
        .toList(growable: false);
  }

  int get selectedCount => selectedCandidates.length;

  int get selectedBytes =>
      selectedCandidates.fold(0, (sum, candidate) => sum + candidate.sizeInBytes);

  /// What the run is expected to free from this group.
  int get estimatedSaving => selectedCandidates.fold(
        0,
        (sum, candidate) => sum + candidate.estimatedSaving,
      );

  /// How many of the ticked rows would end up with a different file name.
  int get renamedCount =>
      selectedCandidates.where((candidate) => candidate.changesExtension).length;

  /// Whether the group is ticked but not entirely — what draws the tristate box.
  bool get isPartiallySelected =>
      isSelected && excludedPaths.isNotEmpty && selectedCount > 0;

  bool isExcluded(String path) => excludedPaths.contains(path);

  MediaGroup copyWith({
    List<MediaCandidate>? candidates,
    bool? isSelected,
    Set<String>? excludedPaths,
    bool? isTruncated,
  }) {
    return MediaGroup(
      kind: kind,
      candidates: candidates ?? this.candidates,
      isSelected: isSelected ?? this.isSelected,
      excludedPaths: excludedPaths ?? this.excludedPaths,
      isTruncated: isTruncated ?? this.isTruncated,
    );
  }

  /// Appends findings, which is the only way [candidates] ever grows — a scan
  /// streams and the group is rebuilt per batch.
  MediaGroup withMore(Iterable<MediaCandidate> found) => copyWith(
        candidates: <MediaCandidate>[...candidates, ...found],
      );

  /// Flips one row, and nothing else.
  MediaGroup toggleCandidate(String path) => copyWith(
        excludedPaths: excludedPaths.contains(path)
            ? (Set<String>.from(excludedPaths)..remove(path))
            : (Set<String>.from(excludedPaths)..add(path)),
      );

  /// Drops what a run rewrote, keeping what it did not.
  ///
  /// A rewritten file is a different file — smaller, sometimes differently
  /// named — and the row describing the old one is stale the moment the encode
  /// lands. What was skipped or failed is still on disk exactly as measured, so
  /// it stays where the next run can try again.
  MediaGroup without(Set<String> paths) {
    if (paths.isEmpty) {
      return this;
    }

    return copyWith(
      candidates: candidates
          .where((candidate) => !paths.contains(candidate.path))
          .toList(growable: false),
      excludedPaths: excludedPaths.difference(paths),
    );
  }

  @override
  List<Object?> get props => <Object?>[
        kind,
        candidates,
        isSelected,
        excludedPaths,
        isTruncated,
      ];
}
