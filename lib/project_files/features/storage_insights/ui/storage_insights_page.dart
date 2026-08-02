import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:storage_cleaner/project_files/features/device_storage/data/platform/device_storage_platform.dart';
import 'package:storage_cleaner/project_files/features/device_storage/data/use_cases/get_device_storage_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/add_access_folder_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/get_storage_access_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/open_access_settings_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/request_storage_access_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/storage_access_repo.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/data/platform/storage_insights_platform.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/data/use_cases/get_insights_availability_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/data/use_cases/measure_storage_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/storage_insights_repo.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/ui/bloc/storage_insights_bloc.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/ui/storage_insights_view.dart';

/// Dependency injection and `BlocProvider`. No UI.
///
/// A page, unlike the two tools, which had to grow scopes above the navigator
/// so their work could outlive the screen. Nothing here is worth keeping alive:
/// a measurement is a few seconds, it writes nothing, and running it again is
/// cheaper than remembering it. So the bloc dies with the screen and `close()`
/// stops the walk, which is the arrangement every screen in this app had until
/// a transcode made it untenable for two of them.
///
/// The access repository comes from the app-wide provider, as everywhere: it
/// holds the folders the user handed over, and either tool may have been the
/// screen that asked for them.
class StorageInsightsPage extends StatelessWidget {
  const StorageInsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final StorageAccessRepo accessRepo = context.read<StorageAccessRepo>();
    final StorageInsightsRepo insightsRepo = createStorageInsightsRepo();

    return BlocProvider<StorageInsightsBloc>(
      create: (_) => StorageInsightsBloc(
        getAvailability: GetInsightsAvailabilityUseCase(insightsRepo),
        getAccess: GetStorageAccessUseCase(accessRepo),
        requestAccess: RequestStorageAccessUseCase(accessRepo),
        addFolder: AddAccessFolderUseCase(accessRepo),
        openAccessSettings: OpenAccessSettingsUseCase(accessRepo),
        measureStorage: MeasureStorageUseCase(insightsRepo),
        getDeviceStorage: GetDeviceStorageUseCase(createDeviceStorageRepo()),
      )..add(const StorageInsightsStarted()),
      child: const StorageInsightsView(),
    );
  }
}
