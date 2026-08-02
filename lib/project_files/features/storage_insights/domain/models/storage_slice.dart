import 'package:equatable/equatable.dart';

/// What one kind of file adds up to.
///
/// The categories are coarse on purpose. A breakdown with twenty rows is a
/// directory listing with extra steps; the question this screen answers is
/// "where did it go", and the answer a person can act on has half a dozen
/// parts. Each one maps onto something the user could then *do* — the two media
/// rows lead to the optimiser, the archive and installer row is what the
/// cleaner already offers to delete.
enum StorageSliceCategory {
  photos,
  videos,
  audio,
  documents,
  archives,

  /// Everything measured that fitted none of the above.
  other,

  /// Used space the walk could not see into.
  ///
  /// Derived rather than measured: the total the platform reports minus
  /// everything above. On Android that is the applications themselves and their
  /// private directories, which no permission opens to a normal app, plus the
  /// system partition. Calling it what it is beats leaving a pie chart that
  /// silently does not add up to the disk.
  system,

  /// What is left. Not a file category, and the reason the ring closes.
  free,
}

/// One row of the breakdown.
final class StorageSlice extends Equatable {
  const StorageSlice({
    required this.category,
    required this.bytes,
    this.fileCount = 0,
  });

  final StorageSliceCategory category;
  final int bytes;

  /// Zero for the two derived rows, which are not made of files anybody
  /// counted.
  final int fileCount;

  StorageSlice plus({required int bytes, int fileCount = 1}) => StorageSlice(
        category: category,
        bytes: this.bytes + bytes,
        fileCount: this.fileCount + fileCount,
      );

  @override
  List<Object?> get props => <Object?>[category, bytes, fileCount];
}
