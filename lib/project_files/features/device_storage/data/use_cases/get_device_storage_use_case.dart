import 'package:storage_cleaner/project_files/features/device_storage/domain/device_storage_repo.dart';
import 'package:storage_cleaner/project_files/features/device_storage/domain/models/device_storage_snapshot.dart';

class GetDeviceStorageUseCase {
  const GetDeviceStorageUseCase(this._repo);

  final DeviceStorageRepo _repo;

  Future<DeviceStorageSnapshot?> call() => _repo.read();
}
