import 'package:flutter/foundation.dart';

import 'package:storage_cleaner/project_files/features/quarantine/domain/models/quarantine_batch.dart';
import 'package:storage_cleaner/project_files/features/quarantine/domain/quarantine_writer.dart';

/// Holds what a cleanup moved aside, and puts it back.
///
/// It outlives the cleaner screen — a batch made this morning has to still be
/// there this evening — so it is one of the two objects constructed in
/// `storage_cleaner_app.dart` rather than in a page.
///
/// [batchesListenable] rather than a `Stream`: the quarantine screen and the
/// banner on the cleaner screen both show the same list and both have to
/// change the moment a cleanup finishes. A `watch*UseCase` adapts it to the
/// stream a bloc lives on, the way `LanguageRepo` is adapted.
abstract interface class QuarantineRepo {
  /// Newest first. Empty until the first cleanup, and after the last expiry.
  ValueListenable<List<QuarantineBatch>> get batchesListenable;

  /// Reads the manifest from disk. Called once, at startup, before anything
  /// reads [batchesListenable].
  Future<void> load();

  /// Opens a batch for a cleanup to move files into. See `QuarantineWriter`.
  Future<QuarantineWriter> openBatch();

  /// Puts every file in the batch back where it came from, then forgets it.
  ///
  /// Throws `RestoreTargetOccupiedFailure` when something is at the old path
  /// again, and `PartialRestoreFailure` when the files are gone from under the
  /// manifest. A partial restore is still a restore: the files that made it
  /// stay put and the count says how many did not.
  Future<void> restore(String batchId);

  /// Deletes one batch for good, ahead of its expiry.
  Future<void> purge(String batchId);

  /// Deletes everything, ahead of every expiry.
  Future<void> purgeAll();

  /// Deletes the batches whose retention has run out.
  ///
  /// Called at startup rather than on a timer: this app is not running when the
  /// week is up, and a background task for deleting a temporary file is more
  /// machinery than the problem is worth.
  Future<void> purgeExpired();
}
