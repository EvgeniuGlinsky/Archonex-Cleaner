import 'package:archonex_cleaner/core/constants/app_byte_units.dart';
import 'package:archonex_cleaner/project_files/features/device_storage/domain/device_storage_repo.dart';
import 'package:archonex_cleaner/project_files/features/device_storage/domain/models/device_storage_snapshot.dart';

/// Hand-written fake for the disk reader. No mocking package here — see
/// `CLAUDE.md`.
///
/// It fakes the `domain/` interface, which is what lets both the home screen and
/// the cleaner be tested against a device of a known size on a machine whose own
/// disk is whatever the CI runner happens to have.
class FakeDeviceStorageRepo implements DeviceStorageRepo {
  FakeDeviceStorageRepo({this.snapshot = fakeSnapshot});

  /// A 256 GB device, three quarters full — round enough that a wrong figure in
  /// an expectation is obvious on sight.
  static const DeviceStorageSnapshot fakeSnapshot = DeviceStorageSnapshot(
    totalBytes: 256 * AppByteUnits.gigabyte,
    freeBytes: 64 * AppByteUnits.gigabyte,
  );

  /// `null` stands in for a platform that cannot measure the disk.
  DeviceStorageSnapshot? snapshot;

  int readCount = 0;

  @override
  Future<DeviceStorageSnapshot?> read() async {
    readCount++;

    return snapshot;
  }
}
