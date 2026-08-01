import 'package:storage_cleaner/project_files/features/device_storage/domain/models/device_storage_snapshot.dart';

/// Reads how full the device is.
///
/// The return is nullable on purpose, and `null` is not an error: two of the
/// platforms this app builds for cannot answer at all, and a ring drawn from a
/// guess is worse than no ring. Every caller treats `null` as "do not draw it"
/// rather than as a failure to report, which is why there is no failure type
/// here and nothing throws.
abstract interface class DeviceStorageRepo {
  Future<DeviceStorageSnapshot?> read();
}
