import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:archonex_cleaner/project_files/features/quarantine/data/use_cases/watch_quarantine_use_case.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/domain/quarantine_repo.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/platform/storage_cleaner_platform.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/use_cases/add_scan_folder_use_case.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/use_cases/clean_junk_use_case.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/use_cases/get_cleaner_availability_use_case.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/use_cases/get_scannable_categories_use_case.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/use_cases/get_storage_access_use_case.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/use_cases/request_storage_access_use_case.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/use_cases/scan_for_junk_use_case.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/junk_clean_repo.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/junk_scan_repo.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/storage_access_repo.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/ui/bloc/storage_cleaner_bloc.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/ui/storage_cleaner_view.dart';

/// Dependency injection and `BlocProvider`. No UI.
///
/// The scanner, the deleter and the access repository are built here and die
/// with the screen. The quarantine is not: it is read from the app-wide
/// provider, because the batch this screen writes is the batch the quarantine
/// screen reads, and a second instance would be a second index of the same
/// directory.
class StorageCleanerPage extends StatelessWidget {
  const StorageCleanerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final QuarantineRepo quarantine = context.read<QuarantineRepo>();

    final JunkScanRepo scanRepo = createJunkScanRepo();
    final JunkCleanRepo cleanRepo = createJunkCleanRepo(quarantine);
    final StorageAccessRepo accessRepo = createStorageAccessRepo();

    return BlocProvider<StorageCleanerBloc>(
      create: (_) => StorageCleanerBloc(
        getAvailability: GetCleanerAvailabilityUseCase(
          scanRepo: scanRepo,
          cleanRepo: cleanRepo,
        ),
        getAccess: GetStorageAccessUseCase(accessRepo),
        requestAccess: RequestStorageAccessUseCase(accessRepo),
        addScanFolder: AddScanFolderUseCase(accessRepo),
        getCategories: GetScannableCategoriesUseCase(scanRepo),
        scanForJunk: ScanForJunkUseCase(scanRepo),
        cleanJunk: CleanJunkUseCase(cleanRepo),
        watchQuarantine: WatchQuarantineUseCase(quarantine),
      )..add(const StorageCleanerStarted()),
      child: const StorageCleanerView(),
    );
  }
}
