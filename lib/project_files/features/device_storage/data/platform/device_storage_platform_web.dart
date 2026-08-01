import 'package:archonex_cleaner/project_files/features/device_storage/data/file_system/unsupported_device_storage_repo.dart';
import 'package:archonex_cleaner/project_files/features/device_storage/domain/device_storage_repo.dart';

/// Web. A browser has no volume to report on, so the ring is simply absent —
/// which matches the rest of the web build, where nothing can be cleaned either.
DeviceStorageRepo createDeviceStorageRepo() =>
    const UnsupportedDeviceStorageRepo();
