import 'package:storage_cleaner/project_files/features/storage_insights/domain/storage_insights_repo.dart';

/// Whether this platform has a volume to measure at all.
///
/// One line and a class, matching `GetCleanerAvailabilityUseCase`: the bloc
/// asks a use case rather than a repository, so that no screen has to know
/// which repositories exist or how many of them agree.
class GetInsightsAvailabilityUseCase {
  const GetInsightsAvailabilityUseCase(this._repo);

  final StorageInsightsRepo _repo;

  bool call() => _repo.isSupported;
}
