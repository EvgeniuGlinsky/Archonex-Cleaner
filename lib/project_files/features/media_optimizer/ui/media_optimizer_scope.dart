import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:storage_cleaner/project_files/features/device_storage/data/platform/device_storage_platform.dart';
import 'package:storage_cleaner/project_files/features/device_storage/data/use_cases/get_device_storage_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/platform/media_optimizer_platform.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/platform/run_notice_platform.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/prefs_optimize_quality_repo.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/fetch_encoder_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/get_encoder_support_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/get_optimizable_kinds_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/get_optimizer_availability_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/optimize_media_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/scan_for_media_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/encoder_supply_repo.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/media_optimize_repo.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/media_scan_repo.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/optimize_quality_repo.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/run_notice.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/ui/bloc/media_optimizer_bloc.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/ui/widgets/run_notice_listener.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/add_access_folder_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/get_storage_access_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/open_access_settings_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/request_storage_access_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/storage_access_repo.dart';

/// Dependency injection and `BlocProvider` for the optimiser. No UI.
///
/// It wraps the whole app rather than the optimiser's route, and that is the
/// point. This was a page, and the bloc died with the screen: `close()` cancels
/// the run, so a user who started a two-hour transcode and pressed Back lost
/// all of it, silently, with the button back to "Look for large files" as
/// though nothing had happened. Nothing about the cancel was wrong — a walk of
/// a camera roll really must not outlive the screen that has no reason to want
/// it any more — but the *screen* was the wrong thing to measure it against.
/// The work outlives the screen; it does not outlive the app, and `close()` now
/// means exactly that.
///
/// It is `lazy`, which `BlocProvider` is by default: nothing is built until the
/// user first opens the tool, so an app that never leaves the home screen never
/// asks the platform whether it has an HEVC encoder.
///
/// Placed in `MaterialApp.builder`, so it sits below `Localizations` and above
/// the `Navigator`. Below matters as much as above: the foreground-service
/// notice reads its copy from `AppLocalizations` here, and has to be able to
/// keep writing it while the user is on another screen entirely.
///
/// The access repository stays app-wide for its own reason, in
/// `storage_cleaner_app.dart`: it holds the folders the user handed over
/// through the picker, and the cleaner may well be the screen that asked.
class MediaOptimizerScope extends StatefulWidget {
  const MediaOptimizerScope({required this.child, super.key});

  final Widget child;

  @override
  State<MediaOptimizerScope> createState() => _MediaOptimizerScopeState();
}

class _MediaOptimizerScopeState extends State<MediaOptimizerScope> {
  // Fields rather than locals in `build`. `MaterialApp.builder` runs again on
  // every language change, and a repository built there would be a new object
  // each time — thrown away unread, because `BlocProvider.create` only fires
  // once, but the notice holds a channel subscription and a foreground service
  // and would not be so harmless.
  final MediaScanRepo _scanRepo = createMediaScanRepo();
  final MediaOptimizeRepo _optimizeRepo = createMediaOptimizeRepo();
  final RunNotice _notice = createRunNotice();

  // A field for the same reason, and one more: a download in flight is held by
  // its job, and a repository rebuilt under it on a language change would leave
  // the running fetch with nobody able to cancel it.
  final EncoderSupplyRepo _supplyRepo = createEncoderSupplyRepo();

  // Not in `storage_cleaner_app.dart` beside the language, although it is the
  // same kind of thing. Nothing outside this feature asks what it says, and a
  // scope that already lives as long as the app is a shorter way to say "as
  // long as the app" than a provider two files away.
  final OptimizeQualityRepo _quality = PrefsOptimizeQualityRepo();

  @override
  void dispose() {
    unawaited(_notice.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MediaScanRepo scanRepo = _scanRepo;
    final MediaOptimizeRepo optimizeRepo = _optimizeRepo;
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
          fetchEncoder: FetchEncoderUseCase(_supplyRepo),
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
          quality: _quality,
        );

        return bloc..add(const MediaOptimizerStarted());
      },
      child: RunNoticeListener(notice: _notice, child: widget.child),
    );
  }
}
