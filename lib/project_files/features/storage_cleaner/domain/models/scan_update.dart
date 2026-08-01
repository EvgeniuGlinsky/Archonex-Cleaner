import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/junk_category.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/junk_item.dart';

/// What a running scan reports.
sealed class ScanUpdate {
  const ScanUpdate();
}

/// The walk moved to a new root, named by a label the screen can show.
///
/// A label rather than the path: on Android the path is
/// `/storage/emulated/0/Android/data/…` and means nothing to anyone. The label
/// is a key the mapper turns into copy, plus the raw path for the ones that are
/// worth showing literally.
final class ScanLocationChanged extends ScanUpdate {
  const ScanLocationChanged({required this.label});

  final String label;
}

/// A batch of findings.
///
/// A batch and never a single item: a Windows `%TEMP%` routinely holds tens of
/// thousands of files, and one event each means one bloc rebuild each. See
/// `AppCleanPolicy.foundBatchSize`.
final class JunkFound extends ScanUpdate {
  const JunkFound(this.items);

  final List<JunkItem> items;
}

/// The walk hit `AppCleanPolicy.maxItemsPerRule` and moved on.
///
/// Reported rather than swallowed: the screen has to be able to say that the
/// number it shows is a floor, not a total.
final class ScanTruncated extends ScanUpdate {
  const ScanTruncated({required this.category});

  final JunkCategory category;
}
