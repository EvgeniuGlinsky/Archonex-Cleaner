import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:storage_cleaner/project_files/features/device_storage/data/platform/device_storage_platform.dart';
import 'package:storage_cleaner/project_files/features/device_storage/data/use_cases/get_device_storage_use_case.dart';
import 'package:storage_cleaner/project_files/features/quarantine/data/use_cases/watch_quarantine_use_case.dart';
import 'package:storage_cleaner/project_files/features/quarantine/domain/quarantine_repo.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/add_access_folder_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/get_storage_access_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/open_access_settings_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/request_storage_access_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/storage_access_repo.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/platform/storage_cleaner_platform.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/use_cases/clean_junk_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/use_cases/get_cleaner_availability_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/use_cases/get_scannable_categories_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/use_cases/scan_for_junk_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/junk_clean_repo.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/junk_scan_repo.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/ui/bloc/storage_cleaner_bloc.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/ui/storage_cleaner_view.dart';

/// Dependency injection and `BlocProvider`. No UI.
///
/// The scanner and the deleter are built here and die with the screen. The
/// quarantine and the access repository are not: both are read from the
/// app-wide provider. The batch this screen writes is the batch the quarantine
/// screen reads, and the folders the user hands over here are the folders the
/// optimiser is meant to see — a second instance of either would be a second
/// answer to a question with one.
class StorageCleanerPage extends StatelessWidget {
  const StorageCleanerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final QuarantineRepo quarantine = context.read<QuarantineRepo>();
    final StorageAccessRepo accessRepo = context.read<StorageAccessRepo>();

    final JunkScanRepo scanRepo = createJunkScanRepo();
    final JunkCleanRepo cleanRepo = createJunkCleanRepo(quarantine);

    return BlocProvider<StorageCleanerBloc>(
      create: (_) => StorageCleanerBloc(
        getAvailability: GetCleanerAvailabilityUseCase(
          scanRepo: scanRepo,
          cleanRepo: cleanRepo,
        ),
        getAccess: GetStorageAccessUseCase(accessRepo),
        requestAccess: RequestStorageAccessUseCase(accessRepo),
        addScanFolder: AddAccessFolderUseCase(accessRepo),
        openAccessSettings: OpenAccessSettingsUseCase(accessRepo),
        getCategories: GetScannableCategoriesUseCase(scanRepo),
        scanForJunk: ScanForJunkUseCase(scanRepo),
        cleanJunk: CleanJunkUseCase(cleanRepo),
        watchQuarantine: WatchQuarantineUseCase(quarantine),
        getDeviceStorage: GetDeviceStorageUseCase(createDeviceStorageRepo()),
      )..add(const StorageCleanerStarted()),
      child: const StorageCleanerView(),
    );
  }
}
