import 'package:disk_space_2/disk_space_2.dart';

import 'package:archonex_cleaner/core/constants/app_byte_units.dart';
import 'package:archonex_cleaner/project_files/features/device_storage/domain/device_storage_repo.dart';
import 'package:archonex_cleaner/project_files/features/device_storage/domain/models/device_storage_snapshot.dart';

/// `disk_space_2` behind `DeviceStorageRepo`.
///
/// The plugin reports **mebibytes as a `double`**, not bytes, which is the one
/// thing worth knowing about it: everything else in this app counts in whole
/// bytes, so the conversion happens here, at the edge, and no widget ever sees
/// the plugin's unit.
///
/// Both calls are made together and either one coming back `null` throws the
/// whole snapshot away. A total with no free figure draws a full ring, and a
/// free figure with no total draws nothing sensible at all — half an answer is
/// the one outcome the ring must never render.
class PluginDeviceStorageRepo implements DeviceStorageRepo {
  const PluginDeviceStorageRepo();

  @override
  Future<DeviceStorageSnapshot?> read() async {
    final double? totalMib;
    final double? freeMib;

    // The channel is missing rather than failing on a platform the plugin was
    // not built for, and a device can refuse to stat its own volume. Neither is
    // worth a failure type: the caller's answer to both is the same as its
    // answer to web, which is not to draw the ring.
    try {
      totalMib = await DiskSpace.getTotalDiskSpace;
      freeMib = await DiskSpace.getFreeDiskSpace;
    } catch (_) {
      return null;
    }

    if (totalMib == null || freeMib == null) {
      return null;
    }

    return DeviceStorageSnapshot(
      totalBytes: _toBytes(totalMib),
      freeBytes: _toBytes(freeMib),
    );
  }

  static int _toBytes(double mebibytes) =>
      (mebibytes * AppByteUnits.megabyte).round();
}
