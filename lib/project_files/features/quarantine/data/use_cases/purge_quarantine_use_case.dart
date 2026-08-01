import 'package:storage_cleaner/project_files/features/quarantine/domain/quarantine_repo.dart';

/// Deletes quarantined files ahead of their expiry — one batch, or all of them.
///
/// One use case rather than two: the two calls differ by an argument, take the
/// same confirmation and produce the same outcome, and a second file would say
/// nothing a `null` does not.
class PurgeQuarantineUseCase {
  const PurgeQuarantineUseCase(this._repo);

  final QuarantineRepo _repo;

  /// [batchId] `null` empties the quarantine.
  Future<void> call({String? batchId}) =>
      batchId == null ? _repo.purgeAll() : _repo.purge(batchId);
}
