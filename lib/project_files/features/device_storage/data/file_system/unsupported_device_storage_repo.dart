import 'package:archonex_cleaner/project_files/features/device_storage/domain/device_storage_repo.dart';
import 'package:archonex_cleaner/project_files/features/device_storage/domain/models/device_storage_snapshot.dart';

/// The answer where nothing can measure the disk: web, which has none, and
/// macOS, which `disk_space_2` does not build for.
///
/// It answers `null` rather than throwing, which is what makes it different from
/// the cleaner's `unsupported_*` siblings. Those refuse because a user who
/// pressed Clean is owed an explanation; nobody presses anything to see a
/// storage ring, so the honest behaviour is for it to be absent and the rest of
/// the screen to carry on.
class UnsupportedDeviceStorageRepo implements DeviceStorageRepo {
  const UnsupportedDeviceStorageRepo();

  @override
  Future<DeviceStorageSnapshot?> read() async => null;
}
