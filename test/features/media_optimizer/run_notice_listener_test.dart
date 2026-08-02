import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:storage_cleaner/core/theme/app_theme.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/device_storage/data/use_cases/get_device_storage_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/get_encoder_support_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/get_optimizable_kinds_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/get_optimizer_availability_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/optimize_media_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/scan_for_media_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_candidate.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_scan_update.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/ui/bloc/media_optimizer_bloc.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/ui/widgets/run_notice_listener.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/add_access_folder_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/get_storage_access_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/open_access_settings_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/request_storage_access_use_case.dart';

import '../device_storage/fakes.dart';
import '../storage_access/fakes.dart';
import 'fakes.dart';

void main() {
  late FakeMediaScanRepo scanRepo;
  late FakeMediaOptimizeRepo optimizeRepo;
  late FakeStorageAccessRepo accessRepo;
  late FakeDeviceStorageRepo storageRepo;
  late FakeRunNotice notice;
  late MediaOptimizerBloc bloc;

  setUp(() {
    scanRepo = FakeMediaScanRepo();
    optimizeRepo = FakeMediaOptimizeRepo();
    accessRepo = FakeStorageAccessRepo();
    storageRepo = FakeDeviceStorageRepo();
    notice = FakeRunNotice();

    scanRepo.updates = <MediaScanUpdate>[
      MediaFound(<MediaCandidate>[fakeCandidate()]),
    ];
  });

  /// The listener sits above the navigator in the real app, so it is driven
  /// here with a bare child rather than with the screen.
  ///
  /// The bloc goes inside `BlocProvider.create` and its handle is kept from
  /// there, per the rule in `CLAUDE.md`. Owning it any other way costs more
  /// than the rule lets on: a bloc the test holds has to be closed by the test,
  /// and `await bloc.close()` inside `testWidgets` never returns — closing a
  /// `StreamController` completes on the next turn of the event loop, and in a
  /// widget test the clock only turns when something pumps. The test hangs with
  /// no error and no frame to point at.
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<MediaOptimizerBloc>(
          create: (_) {
            late final MediaOptimizerBloc created;

            created = MediaOptimizerBloc(
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
                support: () => created.state.support,
              ),
              getDeviceStorage: GetDeviceStorageUseCase(storageRepo),
            );

            bloc = created;

            return created..add(const MediaOptimizerStarted());
          },
          child: RunNoticeListener(
            notice: notice,
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    bloc.add(const MediaScanRequested());
    await tester.pumpAndSettle();
  }

  testWidgets('nothing is in the shade until a run starts', (tester) async {
    await pump(tester);

    expect(notice.shown, isEmpty);
  });

  testWidgets('a run raises the notice and keeps it in step', (tester) async {
    optimizeRepo.holdOpen = true;

    await pump(tester);
    bloc.add(const OptimizeRequested());
    await tester.pumpAndSettle();

    expect(notice.isShowing, isTrue);
    // The count and the space freed, not the file name — a path in a
    // notification is truncated to nothing anybody can read.
    expect(notice.shown.last, contains('of'));
  });

  testWidgets('the notice comes down when the run ends', (tester) async {
    await pump(tester);
    bloc.add(const OptimizeRequested());
    await tester.pumpAndSettle();

    expect(notice.hideCount, greaterThan(0));
  });

  testWidgets('Stop in the shade cancels the run', (tester) async {
    optimizeRepo.holdOpen = true;

    await pump(tester);
    bloc.add(const OptimizeRequested());
    await tester.pumpAndSettle();

    expect(bloc.state.isOptimizing, isTrue);

    notice.pressStop();
    await tester.pumpAndSettle();

    expect(optimizeRepo.wasCancelled, isTrue);
  });
}
