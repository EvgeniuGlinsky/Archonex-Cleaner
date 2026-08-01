import 'package:archonex_cleaner/project_files/features/storage_access/domain/models/access_failure.dart';
import 'package:archonex_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';
import 'package:archonex_cleaner/project_files/features/storage_access/domain/storage_access_repo.dart';

/// Asks for wider access and reports what came back.
///
/// A refusal is returned rather than thrown — the user said no, which is an
/// answer. What *is* thrown is a refusal the user cannot undo from inside the
/// app: once the system stops showing the sheet, the screen has to send them to
/// Settings, and that is a different message from "not granted".
class RequestStorageAccessUseCase {
  const RequestStorageAccessUseCase(this._repo);

  final StorageAccessRepo _repo;

  Future<StorageAccess> call() async {
    final StorageAccess granted = await _repo.request();

    if (!granted.isComplete && !granted.canRequestMore && !granted.canAddFolder) {
      throw StorageAccessDeniedFailure(canAskAgain: granted.canRequestMore);
    }

    return granted;
  }
}
