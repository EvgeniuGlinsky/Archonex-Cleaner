import 'package:archonex_cleaner/project_files/features/quarantine/domain/quarantine_repo.dart';

/// Reads the manifest and drops whatever has run out of retention.
///
/// Called once, from the splash screen, and not on a timer: the app is not
/// running when the week is up, and a background job whose only purpose is to
/// delete a temporary file is more machinery than the problem is worth. The
/// consequence is that an expired batch survives until the next launch, which
/// costs disk and nothing else.
class PurgeExpiredQuarantineUseCase {
  const PurgeExpiredQuarantineUseCase(this._repo);

  final QuarantineRepo _repo;

  Future<void> call() async {
    await _repo.load();
    await _repo.purgeExpired();
  }
}
