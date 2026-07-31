import 'package:archonex_cleaner/project_files/features/quarantine/domain/quarantine_repo.dart';

/// Puts one cleanup back.
///
/// Throws a `RestoreFailure` — nothing is wrapped and nothing is swallowed,
/// because both members of that hierarchy are things the user can act on.
class RestoreQuarantineBatchUseCase {
  const RestoreQuarantineBatchUseCase(this._repo);

  final QuarantineRepo _repo;

  Future<void> call(String batchId) => _repo.restore(batchId);
}
