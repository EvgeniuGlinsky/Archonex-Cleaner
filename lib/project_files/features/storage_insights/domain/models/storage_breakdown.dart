import 'package:equatable/equatable.dart';

import 'package:storage_cleaner/project_files/features/device_storage/domain/models/device_storage_snapshot.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/storage_slice.dart';

/// The whole disk, in the order the chart draws it.
///
/// Built from two different kinds of knowledge and honest about which is which.
/// [measured] is what the walk actually added up, file by file;
/// `StorageSliceCategory.system` and `.free` are arithmetic on the figures the
/// platform reports, and neither was ever visited. Presenting them as the same
/// kind of answer is how a storage screen ends up confidently wrong — Android
/// will not let any app see another's private data, so a measured "apps" row
/// would be a guess with a number on it.
///
/// Everything below is derived. Nothing is stored twice, for the reason the
/// Bloc state section of the skill gives: two records of one figure is how a
/// screen disagrees with itself.
final class StorageBreakdown extends Equatable {
  const StorageBreakdown({
    required this.measured,
    this.storage,
    this.isTruncated = false,
  });

  /// What the walk counted, by category. Never holds `system` or `free`.
  final List<StorageSlice> measured;

  /// How full the platform says the volume is. `null` where it will not say,
  /// and then there is no ring and no system row — only what was counted.
  final DeviceStorageSnapshot? storage;

  /// The walk stopped at its ceiling with more still there.
  final bool isTruncated;

  int get measuredBytes =>
      measured.fold(0, (sum, slice) => sum + slice.bytes);

  int get measuredCount =>
      measured.fold(0, (sum, slice) => sum + slice.fileCount);

  /// Used space the walk could not account for.
  ///
  /// Floored at zero rather than allowed to go negative. It can: the platform
  /// reports the volume and the walk covers the user-visible part of it, and on
  /// a device where those disagree — a card counted by one and not the other —
  /// a negative slice would silently make every percentage wrong instead of
  /// obviously wrong.
  int get systemBytes {
    final DeviceStorageSnapshot? storage = this.storage;

    if (storage == null) {
      return 0;
    }

    final int unaccounted = storage.usedBytes - measuredBytes;

    return unaccounted > 0 ? unaccounted : 0;
  }

  int get freeBytes => storage?.freeBytes ?? 0;

  /// Every row the chart draws, largest measured category first and the two
  /// derived ones after them.
  ///
  /// Sorted rather than declared in enum order, because the point of the screen
  /// is which one is biggest and a fixed order makes that a reading exercise.
  /// The derived pair stay at the end regardless: they are the frame the rest
  /// sits in, not competitors in the same list.
  ///
  /// Empty until something has been counted, and that is not the same as the
  /// list of measured rows being empty with the frame still drawn. Before a
  /// measurement the frame alone would be one enormous row reading "system and
  /// apps" over the whole used disk — a confident claim about content nothing
  /// has looked at yet, which is exactly the lie the system slice exists to
  /// avoid telling.
  List<StorageSlice> get slices {
    final List<StorageSlice> ordered = measured
        .where((slice) => slice.bytes > 0)
        .toList(growable: true)
      ..sort((a, b) => b.bytes.compareTo(a.bytes));

    if (storage == null || ordered.isEmpty) {
      return List<StorageSlice>.unmodifiable(ordered);
    }

    return List<StorageSlice>.unmodifiable(<StorageSlice>[
      ...ordered,
      StorageSlice(category: StorageSliceCategory.system, bytes: systemBytes),
      StorageSlice(category: StorageSliceCategory.free, bytes: freeBytes),
    ]);
  }

  /// A slice as a fraction of the whole volume, for the ring.
  ///
  /// Nought where the volume is unknown or nought: a fraction of an unknown
  /// total is not a number, and dividing by zero puts a `NaN` into a sweep
  /// angle, which throws inside the canvas.
  double fractionOf(int bytes) {
    final int total = storage?.totalBytes ?? 0;

    return total <= 0 ? 0 : bytes / total;
  }

  @override
  List<Object?> get props => <Object?>[measured, storage, isTruncated];
}
