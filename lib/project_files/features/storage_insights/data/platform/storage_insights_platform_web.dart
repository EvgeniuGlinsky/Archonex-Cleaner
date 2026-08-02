import 'package:storage_cleaner/project_files/features/storage_insights/data/file_system/unsupported_storage_insights_repo.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/storage_insights_repo.dart';

/// A tab has no disk. `dart:io` is not there to walk one with either, which is
/// what makes this the compile-time half of the question.
StorageInsightsRepo createStorageInsightsRepo() =>
    const UnsupportedStorageInsightsRepo();
