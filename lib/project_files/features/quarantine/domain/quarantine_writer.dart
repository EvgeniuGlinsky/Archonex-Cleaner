import 'package:storage_cleaner/project_files/features/quarantine/domain/models/quarantine_batch.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/junk_item.dart';

/// One cleanup's open batch, handed to the deleter for the length of the run.
///
/// It exists so the two halves stay apart: `JunkCleanRepo` knows how to delete
/// and nothing about retention, and `QuarantineRepo` knows the retention and
/// nothing about the queue. The deleter offers each file; the writer says
/// whether it took it.
abstract interface class QuarantineWriter {
  /// Tries to move [item] aside.
  ///
  /// `true` — it is in the batch, and the caller must not delete it. `false` —
  /// the caller deletes it outright, which is the answer for a file above
  /// `AppQuarantinePolicy.maxEntryBytes`, a file on another volume where moving
  /// would mean copying, and a batch that has run out of budget.
  Future<bool> keep(JunkItem item);

  /// Writes the index and publishes the batch.
  ///
  /// `null` when nothing was kept, in which case no directory is left behind.
  Future<QuarantineBatch?> commit();
}
