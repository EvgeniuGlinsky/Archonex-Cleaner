/// Everything that can go wrong on the quarantine screen.
///
/// Its own sealed hierarchy rather than more members of `CleanFailure`, and the
/// reason is the dependency rather than the taxonomy: the cleaner depends on
/// this feature's `QuarantineRepo`, so this feature must not depend back on the
/// cleaner's failures. One hierarchy per feature keeps the arrow pointing one
/// way, and each gets its own exhaustive mapper.
///
/// Named for the screen rather than for restoring, which is what it was called
/// while restoring was the only thing on it wrapped in a `try`. Emptying the
/// quarantine was not, and an exception from it left the screen in `working`
/// for good — every button disabled, with nothing said about why.
sealed class QuarantineFailure implements Exception {
  const QuarantineFailure();
}

/// Something is at the original path again, so putting the file back would
/// overwrite it.
///
/// Checked for every entry *before* anything is moved: half a restore is worse
/// than none, because the user is left not knowing which files came back.
final class RestoreTargetOccupiedFailure extends QuarantineFailure {
  const RestoreTargetOccupiedFailure({required this.path});

  /// The occupied destination, so the message can name it.
  final String path;
}

/// Some of the quarantined files are no longer on disk.
///
/// The directory was emptied from outside the app, or a backup restored the
/// manifest without the files beside it. What could be put back was put back;
/// the counts say how the run split.
final class PartialRestoreFailure extends QuarantineFailure {
  const PartialRestoreFailure({
    required this.restoredCount,
    required this.lostCount,
  });

  final int restoredCount;
  final int lostCount;
}

/// Emptying the quarantine broke — the directory is unreadable, or the
/// manifest cannot be rewritten to match what was deleted.
///
/// Carries nothing. Unlike a restore, there is no split worth reporting: the
/// files the user wanted gone are the files that were going to be deleted
/// anyway, and what matters is that the screen comes back to life and says the
/// batch is still there.
final class PurgeFailure extends QuarantineFailure {
  const PurgeFailure();
}
