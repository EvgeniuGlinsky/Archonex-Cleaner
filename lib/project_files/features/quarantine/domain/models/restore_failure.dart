/// Everything that can go wrong putting a cleanup back.
///
/// Its own sealed hierarchy rather than two more members of `CleanFailure`,
/// and the reason is the dependency rather than the taxonomy: the cleaner
/// depends on this feature's `QuarantineRepo`, so this feature must not depend
/// back on the cleaner's failures. One hierarchy per feature keeps the arrow
/// pointing one way, and each gets its own exhaustive mapper.
sealed class RestoreFailure implements Exception {
  const RestoreFailure();
}

/// Something is at the original path again, so putting the file back would
/// overwrite it.
///
/// Checked for every entry *before* anything is moved: half a restore is worse
/// than none, because the user is left not knowing which files came back.
final class RestoreTargetOccupiedFailure extends RestoreFailure {
  const RestoreTargetOccupiedFailure({required this.path});

  /// The occupied destination, so the message can name it.
  final String path;
}

/// Some of the quarantined files are no longer on disk.
///
/// The directory was emptied from outside the app, or a backup restored the
/// manifest without the files beside it. What could be put back was put back;
/// the counts say how the run split.
final class PartialRestoreFailure extends RestoreFailure {
  const PartialRestoreFailure({
    required this.restoredCount,
    required this.lostCount,
  });

  final int restoredCount;
  final int lostCount;
}
