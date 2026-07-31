import 'package:equatable/equatable.dart';

import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_category.dart';

/// One file the app moved aside instead of deleting.
final class QuarantineEntry extends Equatable {
  const QuarantineEntry({
    required this.originalPath,
    required this.storedName,
    required this.sizeInBytes,
    required this.category,
    this.wasDirectory = false,
  });

  /// Where it came from, and where a restore puts it back.
  final String originalPath;

  /// What it is called inside the batch directory.
  ///
  /// Not the original name: two caches on two drives routinely hold a
  /// `cache.db`, and a batch is one flat directory. The stored name is indexed,
  /// so nothing can collide and the original name is recovered from
  /// [originalPath] rather than from the file on disk.
  final String storedName;

  final int sizeInBytes;
  final JunkCategory category;
  final bool wasDirectory;

  @override
  List<Object?> get props => <Object?>[
        originalPath,
        storedName,
        sizeInBytes,
        category,
        wasDirectory,
      ];
}
