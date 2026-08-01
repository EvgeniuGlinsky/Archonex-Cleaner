import 'package:archonex_cleaner/project_files/features/language_selection/domain/language_repo.dart';

class RestoreLanguageUseCase {
  const RestoreLanguageUseCase(this._repo);

  final LanguageRepo _repo;

  Future<void> call() => _repo.restore();
}
