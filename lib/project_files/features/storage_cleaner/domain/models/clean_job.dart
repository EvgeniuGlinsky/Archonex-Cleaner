import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/clean_update.dart';

/// One run of the deleter, exposed as a stream that can be stopped.
///
/// Same shape as `ScanJob` and one deliberate difference: this stream always
/// ends with a `CleanFinished` and then closes, cancellation included. Deleting
/// cannot be undone by stopping, so the count of what already went is owed to
/// the user whatever happened.
abstract interface class CleanJob {
  Stream<CleanUpdate> get updates;

  /// Stops after the file currently in flight. Nothing already deleted comes
  /// back; the quarantine is what brings files back, not this.
  Future<void> cancel();
}
