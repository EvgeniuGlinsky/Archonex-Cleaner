import 'package:equatable/equatable.dart';

/// How full the volume the app lives on is, at one moment.
///
/// A snapshot rather than a stream: the number moves when files are deleted, and
/// the two things that delete files here — a cleanup and a quarantine purge —
/// both end with an event the screen already rebuilds on. Watching the disk
/// would be a poll that is wrong between ticks instead of right on demand.
final class DeviceStorageSnapshot extends Equatable {
  const DeviceStorageSnapshot({
    required this.totalBytes,
    required this.freeBytes,
  });

  final int totalBytes;
  final int freeBytes;

  /// What the ring fills. Clamped at zero because the two numbers come from two
  /// separate platform calls and a delete between them can order them wrongly.
  int get usedBytes {
    final int used = totalBytes - freeBytes;

    return used < 0 ? 0 : used;
  }

  /// `0` on a volume that reports no size at all, which is a plugin answering
  /// badly rather than a disk. Dividing anyway would put a `NaN` in a sweep
  /// angle, and a `NaN` angle throws inside the painter.
  double get usedFraction => totalBytes <= 0 ? 0 : usedBytes / totalBytes;

  /// The share one number of bytes takes of the whole volume, for the segment
  /// the found junk paints over the used one.
  double fractionOf(int bytes) {
    if (totalBytes <= 0 || bytes <= 0) {
      return 0;
    }

    final double fraction = bytes / totalBytes;

    return fraction > 1 ? 1 : fraction;
  }

  @override
  List<Object?> get props => <Object?>[totalBytes, freeBytes];
}
