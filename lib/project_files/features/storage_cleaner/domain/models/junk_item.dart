import 'package:equatable/equatable.dart';

import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_category.dart';

/// One thing a scan found and is willing to delete.
///
/// A directory is an item in its own right rather than a bag of items: an empty
/// folder weighs nothing and has to be removed as a unit, and a cache directory
/// whose whole contents are junk is one line on the screen instead of nine
/// thousand.
final class JunkItem extends Equatable {
  const JunkItem({
    required this.path,
    required this.name,
    required this.sizeInBytes,
    required this.category,
    required this.modifiedAt,
    this.isDirectory = false,
  });

  /// Absolute path. It is also the identity: two findings with the same path
  /// are the same finding, which is what lets the excluded set be a set of
  /// strings rather than of items.
  final String path;

  /// Last segment of [path], kept rather than derived so the UI does not split
  /// a path on every rebuild.
  final String name;

  /// Total bytes, summed over the contents when [isDirectory].
  final int sizeInBytes;

  final JunkCategory category;

  /// When it last changed. Read by the age guard, and shown on the row so a
  /// user can tell yesterday's leftovers from last year's.
  final DateTime modifiedAt;

  final bool isDirectory;

  @override
  List<Object?> get props => <Object?>[
        path,
        name,
        sizeInBytes,
        category,
        modifiedAt,
        isDirectory,
      ];
}
