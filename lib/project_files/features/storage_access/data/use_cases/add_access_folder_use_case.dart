import 'package:storage_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/storage_access_repo.dart';

/// Opens the folder picker and returns the access the pick produced.
///
/// A closed picker returns the access unchanged, which the caller cannot tell
/// apart from a pick of a folder already on the list — and does not need to:
/// both mean the state does not change.
class AddAccessFolderUseCase {
  const AddAccessFolderUseCase(this._repo);

  final StorageAccessRepo _repo;

  Future<StorageAccess> call() => _repo.addFolder();
}
