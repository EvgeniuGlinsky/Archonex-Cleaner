import 'package:storage_cleaner/project_files/features/storage_access/domain/storage_access_repo.dart';

/// Sends the user to the system page where a refused permission can be undone.
///
/// Answers nothing and cannot fail, which is what makes it the one access use
/// case with no guard in it: the app is going to the background, and the only
/// thing worth knowing afterwards is what `GetStorageAccessUseCase` reads when
/// the screen comes back. Reporting on the trip out would be reporting on a
/// question nobody has asked yet.
class OpenAccessSettingsUseCase {
  const OpenAccessSettingsUseCase(this._repo);

  final StorageAccessRepo _repo;

  Future<void> call() => _repo.openSettings();
}
