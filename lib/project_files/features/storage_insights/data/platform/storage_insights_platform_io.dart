import 'package:storage_cleaner/project_files/features/storage_insights/data/file_system/io_storage_insights_repo.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/storage_insights_repo.dart';

/// Every platform with a file system. The ones that have one and still cannot
/// help — iOS, Fuchsia — say so through `isSupported` rather than through a
/// different class, because the walk itself is identical and only the volume is
/// missing.
StorageInsightsRepo createStorageInsightsRepo() => IoStorageInsightsRepo();
