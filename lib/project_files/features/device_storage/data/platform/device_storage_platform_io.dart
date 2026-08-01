import 'package:flutter/foundation.dart';

import 'package:storage_cleaner/project_files/features/device_storage/data/file_system/plugin_device_storage_repo.dart';
import 'package:storage_cleaner/project_files/features/device_storage/data/file_system/unsupported_device_storage_repo.dart';
import 'package:storage_cleaner/project_files/features/device_storage/domain/device_storage_repo.dart';

/// Four of the five platforms with a file system can be measured.
///
/// macOS is the exception, and not because it has nothing to measure:
/// `disk_space_2` simply registers no plugin class for it, so the method channel
/// is not there and the call would come back as a `MissingPluginException` on
/// every launch. Answered here, where the platform is known, rather than caught
/// downstream as if it were a device that failed.
DeviceStorageRepo createDeviceStorageRepo() {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      const PluginDeviceStorageRepo(),
    TargetPlatform.macOS ||
    TargetPlatform.fuchsia =>
      const UnsupportedDeviceStorageRepo(),
  };
}
