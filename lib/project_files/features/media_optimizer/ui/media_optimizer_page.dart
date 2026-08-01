import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:storage_cleaner/project_files/features/device_storage/data/platform/device_storage_platform.dart';
import 'package:storage_cleaner/project_files/features/device_storage/data/use_cases/get_device_storage_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/platform/media_optimizer_platform.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/get_encoder_support_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/get_optimizable_kinds_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/get_optimizer_availability_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/optimize_media_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/scan_for_media_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/media_optimize_repo.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/media_scan_repo.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/ui/bloc/media_optimizer_bloc.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/ui/media_optimizer_view.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/add_access_folder_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/get_storage_access_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/open_access_settings_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/request_storage_access_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/storage_access_repo.dart';

/// Dependency injection and `BlocProvider`. No UI.
///
/// The scanner and the optimiser die with the screen. Nothing in this feature
/// holds an index of anything — a rewritten file leaves no record behind,
/// deliberately, and the two encoders are stateless behind their channels.
///
/// The access repository is the exception, and comes from the app-wide provider
/// in `storage_cleaner_app.dart`. It is the one thing here with memory: the
/// folders the user handed over through the picker, which the cleaner may well
/// be the screen that asked for them.
class MediaOptimizerPage extends StatelessWidget {
  const MediaOptimizerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final MediaScanRepo scanRepo = createMediaScanRepo();
    final MediaOptimizeRepo optimizeRepo = createMediaOptimizeRepo();
    final StorageAccessRepo accessRepo = context.read<StorageAccessRepo>();

    return BlocProvider<MediaOptimizerBloc>(
      create: (_) {
        late final MediaOptimizerBloc bloc;

        bloc = MediaOptimizerBloc(
          getAvailability: GetOptimizerAvailabilityUseCase(
            scanRepo: scanRepo,
            optimizeRepo: optimizeRepo,
          ),
          getSupport: GetEncoderSupportUseCase(optimizeRepo),
          getKinds: GetOptimizableKindsUseCase(scanRepo),
          getAccess: GetStorageAccessUseCase(accessRepo),
          requestAccess: RequestStorageAccessUseCase(accessRepo),
          addFolder: AddAccessFolderUseCase(accessRepo),
          openAccessSettings: OpenAccessSettingsUseCase(accessRepo),
          scanForMedia: ScanForMediaUseCase(scanRepo),
          optimizeMedia: OptimizeMediaUseCase(
            repo: optimizeRepo,
            // Read from the state at call time rather than passed as a value:
            // the answer arrives asynchronously when the screen opens, and a
            // use case built with whatever was known at construction would
            // still be holding "unknown" by the time the button is pressed.
            support: () => bloc.state.support,
          ),
          getDeviceStorage: GetDeviceStorageUseCase(createDeviceStorageRepo()),
        );

        return bloc..add(const MediaOptimizerStarted());
      },
      child: const MediaOptimizerView(),
    );
  }
}
