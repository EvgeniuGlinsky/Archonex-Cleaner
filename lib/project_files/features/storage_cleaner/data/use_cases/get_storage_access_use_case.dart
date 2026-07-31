import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/storage_access.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/storage_access_repo.dart';

/// What the app may currently look at.
class GetStorageAccessUseCase {
  const GetStorageAccessUseCase(this._repo);

  final StorageAccessRepo _repo;

  Future<StorageAccess> call() => _repo.current();
}
