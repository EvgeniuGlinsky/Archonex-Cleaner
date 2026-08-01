import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/junk_clean_repo.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/clean_failure.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/clean_job.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/junk_item.dart';

/// Starts a cleanup.
///
/// The one guard worth having here is the empty list: a run with nothing in it
/// would emit a report saying nothing happened, and the screen would show a
/// result card for a cleanup that never ran.
class CleanJunkUseCase {
  const CleanJunkUseCase(this._repo);

  final JunkCleanRepo _repo;

  CleanJob call({
    required List<JunkItem> items,
    bool quarantine = true,
  }) {
    if (!_repo.isSupported) {
      throw const CleanUnsupportedFailure();
    }

    if (items.isEmpty) {
      throw StateError('CleanJunkUseCase was called with nothing to delete.');
    }

    return _repo.clean(items: items, quarantine: quarantine);
  }
}
