import 'package:flutter_test/flutter_test.dart';

import 'package:storage_cleaner/core/constants/app_byte_units.dart';
import 'package:storage_cleaner/project_files/features/device_storage/domain/models/device_storage_snapshot.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/storage_breakdown.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/storage_slice.dart';

void main() {
  const int gb = AppByteUnits.gigabyte;

  StorageSlice slice(StorageSliceCategory category, int bytes) =>
      StorageSlice(category: category, bytes: bytes, fileCount: 1);

  const DeviceStorageSnapshot disk =
      DeviceStorageSnapshot(totalBytes: 128 * gb, freeBytes: 28 * gb);

  test('what the walk could not see becomes the system slice', () {
    // 100 GB used, 60 of it counted. The rest is the applications and their
    // private directories, which no permission opens to a normal app.
    final StorageBreakdown breakdown = StorageBreakdown(
      storage: disk,
      measured: <StorageSlice>[
        slice(StorageSliceCategory.videos, 40 * gb),
        slice(StorageSliceCategory.photos, 20 * gb),
      ],
    );

    expect(breakdown.measuredBytes, 60 * gb);
    expect(breakdown.systemBytes, 40 * gb);
    expect(breakdown.freeBytes, 28 * gb);
  });

  test('the rows add up to the whole disk', () {
    final StorageBreakdown breakdown = StorageBreakdown(
      storage: disk,
      measured: <StorageSlice>[
        slice(StorageSliceCategory.videos, 40 * gb),
        slice(StorageSliceCategory.photos, 20 * gb),
      ],
    );

    expect(
      breakdown.slices.fold<int>(0, (sum, s) => sum + s.bytes),
      disk.totalBytes,
    );
  });

  test('a walk that measured more than the disk says is used does not go '
      'negative', () {
    // It can happen: the platform reports one volume and the walk covers a
    // slightly different notion of it. A negative slice would make every
    // percentage silently wrong instead of obviously wrong.
    final StorageBreakdown breakdown = StorageBreakdown(
      storage: disk,
      measured: <StorageSlice>[slice(StorageSliceCategory.videos, 120 * gb)],
    );

    expect(breakdown.systemBytes, 0);
  });

  test('the biggest measured category comes first', () {
    final StorageBreakdown breakdown = StorageBreakdown(
      storage: disk,
      measured: <StorageSlice>[
        slice(StorageSliceCategory.photos, 5 * gb),
        slice(StorageSliceCategory.videos, 40 * gb),
        slice(StorageSliceCategory.audio, 12 * gb),
      ],
    );

    expect(
      breakdown.slices.take(3).map((s) => s.category),
      <StorageSliceCategory>[
        StorageSliceCategory.videos,
        StorageSliceCategory.audio,
        StorageSliceCategory.photos,
      ],
    );
  });

  test('and the two derived rows stay at the end whatever their size', () {
    // They are the frame the rest sits in, not competitors in the same list.
    final StorageBreakdown breakdown = StorageBreakdown(
      storage: disk,
      measured: <StorageSlice>[slice(StorageSliceCategory.photos, 1 * gb)],
    );

    expect(
      breakdown.slices.map((s) => s.category).toList(),
      <StorageSliceCategory>[
        StorageSliceCategory.photos,
        StorageSliceCategory.system,
        StorageSliceCategory.free,
      ],
    );
  });

  test('an empty category is not drawn', () {
    final StorageBreakdown breakdown = StorageBreakdown(
      storage: disk,
      measured: <StorageSlice>[
        slice(StorageSliceCategory.photos, 1 * gb),
        const StorageSlice(category: StorageSliceCategory.audio, bytes: 0),
      ],
    );

    expect(
      breakdown.slices.map((s) => s.category),
      isNot(contains(StorageSliceCategory.audio)),
    );
  });

  test('a platform that will not say how big the disk is draws no frame', () {
    // Not a zeroed ring. A system slice of the whole volume and a free slice of
    // nothing would both be inventions.
    final StorageBreakdown breakdown = StorageBreakdown(
      measured: <StorageSlice>[slice(StorageSliceCategory.photos, 1 * gb)],
    );

    expect(breakdown.slices, hasLength(1));
    expect(breakdown.systemBytes, 0);
    expect(breakdown.fractionOf(1 * gb), 0);
  });
}
