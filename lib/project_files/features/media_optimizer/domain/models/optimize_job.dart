import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_update.dart';

/// One re-encoding run, exposed as a stream that can be stopped.
///
/// It ends the opposite way to `MediaScanJob`, and the asymmetry is deliberate.
/// A cancelled scan errors and hands over nothing; a cancelled run emits
/// `OptimizeFinished` and closes normally, with `OptimizeReport.wasCancelled`
/// set, because by then files have already been rewritten and the count is owed
/// to the user. `CleanJob` makes the same distinction for the same reason.
///
/// Cancelling stops the run *between* files, never inside one. A half-written
/// encode is deleted and its original is left alone: the point of the ladder in
/// `IoMediaOptimizeRepo` is that there is no moment where the only copy of
/// something is the one being written.
abstract interface class OptimizeJob {
  Stream<OptimizeUpdate> get updates;

  Future<void> cancel();
}
