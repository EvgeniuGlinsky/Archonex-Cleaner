import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/clean_job.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/junk_item.dart';

/// Deletes what a scan found. Finds nothing itself.
///
/// It never decides *what* to delete: the list it is handed is the list it
/// takes, and the guard that keeps a system directory off that list runs during
/// the scan, in `ProtectedPaths`. A deleter that re-derived the rules would be
/// a second place for them to be wrong.
abstract interface class JunkCleanRepo {
  /// Whether the platform lets anything be deleted.
  bool get isSupported;

  /// [quarantine] false deletes outright, and is the user's choice rather than
  /// a fallback — the repository still ignores it for a file too large or on
  /// the wrong volume to move, which the report counts separately.
  CleanJob clean({
    required List<JunkItem> items,
    bool quarantine = true,
  });
}
