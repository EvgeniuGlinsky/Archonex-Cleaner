import 'package:flutter_test/flutter_test.dart';

import 'package:storage_cleaner/core/constants/app_byte_units.dart';
import 'package:storage_cleaner/project_files/features/device_storage/data/file_system/unsupported_device_storage_repo.dart';
import 'package:storage_cleaner/project_files/features/device_storage/domain/models/device_storage_snapshot.dart';

void main() {
  group('DeviceStorageSnapshot', () {
    test('used is what is left after free', () {
      const DeviceStorageSnapshot snapshot = DeviceStorageSnapshot(
        totalBytes: 256 * AppByteUnits.gigabyte,
        freeBytes: 64 * AppByteUnits.gigabyte,
      );

      expect(snapshot.usedBytes, 192 * AppByteUnits.gigabyte);
      expect(snapshot.usedFraction, 0.75);
    });

    test('a volume reporting more free than it holds reads as empty, not as a '
        'negative', () {
      // The two figures come from two separate platform calls, and a delete
      // between them can order them wrongly.
      const DeviceStorageSnapshot snapshot = DeviceStorageSnapshot(
        totalBytes: AppByteUnits.gigabyte,
        freeBytes: 2 * AppByteUnits.gigabyte,
      );

      expect(snapshot.usedBytes, 0);
      expect(snapshot.usedFraction, 0);
    });

    test('a volume of no size divides into nothing rather than NaN', () {
      // A `NaN` reaching a sweep angle throws inside the ring's painter.
      const DeviceStorageSnapshot snapshot = DeviceStorageSnapshot(
        totalBytes: 0,
        freeBytes: 0,
      );

      expect(snapshot.usedFraction, 0);
      expect(snapshot.usedFraction.isNaN, isFalse);
      expect(snapshot.fractionOf(1024), 0);
    });

    test('fractionOf is the share of the whole volume, never over all of it',
        () {
      const DeviceStorageSnapshot snapshot = DeviceStorageSnapshot(
        totalBytes: 100 * AppByteUnits.megabyte,
        freeBytes: 50 * AppByteUnits.megabyte,
      );

      expect(snapshot.fractionOf(25 * AppByteUnits.megabyte), 0.25);
      expect(snapshot.fractionOf(500 * AppByteUnits.megabyte), 1);
      expect(snapshot.fractionOf(0), 0);
    });
  });

  test('the unsupported reader answers null rather than throwing', () async {
    // macOS and web reach this one. Nobody presses anything to see a storage
    // ring, so the honest behaviour is for it to be absent and the rest of the
    // screen to carry on — unlike the cleaner's refusing siblings, which throw
    // because a user who pressed Clean is owed an explanation.
    const UnsupportedDeviceStorageRepo repo = UnsupportedDeviceStorageRepo();

    expect(await repo.read(), isNull);
  });
}
