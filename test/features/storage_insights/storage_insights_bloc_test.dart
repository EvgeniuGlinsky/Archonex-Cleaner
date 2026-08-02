import 'package:flutter_test/flutter_test.dart';

import 'package:storage_cleaner/core/constants/app_byte_units.dart';
import 'package:storage_cleaner/project_files/features/device_storage/data/use_cases/get_device_storage_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/add_access_folder_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/get_storage_access_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/open_access_settings_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/request_storage_access_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/data/use_cases/get_insights_availability_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/data/use_cases/measure_storage_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/insights_failure.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/insights_update.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/storage_slice.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/ui/bloc/storage_insights_bloc.dart';

import '../device_storage/fakes.dart';
import '../storage_access/fakes.dart';
import 'fakes.dart';

/// There is no `bloc_test` here, so nothing else drains the event queue before
/// an assertion reads `bloc.state`.
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeStorageInsightsRepo insightsRepo;
  late FakeStorageAccessRepo accessRepo;
  late FakeDeviceStorageRepo storageRepo;

  setUp(() {
    insightsRepo = FakeStorageInsightsRepo();
    accessRepo = FakeStorageAccessRepo();
    storageRepo = FakeDeviceStorageRepo();
  });

  StorageInsightsBloc build() => StorageInsightsBloc(
        getAvailability: GetInsightsAvailabilityUseCase(insightsRepo),
        getAccess: GetStorageAccessUseCase(accessRepo),
        requestAccess: RequestStorageAccessUseCase(accessRepo),
        addFolder: AddAccessFolderUseCase(accessRepo),
        openAccessSettings: OpenAccessSettingsUseCase(accessRepo),
        measureStorage: MeasureStorageUseCase(insightsRepo),
        getDeviceStorage: GetDeviceStorageUseCase(storageRepo),
      );

  Future<StorageInsightsBloc> started() async {
    final StorageInsightsBloc bloc = build();
    bloc.add(const StorageInsightsStarted());
    await settle();

    return bloc;
  }

  StorageSlice slice(StorageSliceCategory category, int bytes) =>
      StorageSlice(category: category, bytes: bytes, fileCount: 1);

  test('the disk is read before anything is measured', () async {
    // It is the denominator for every percentage on the screen, and the only
    // thing there is to draw before the button is pressed.
    final StorageInsightsBloc bloc = await started();

    expect(bloc.state.storage, isNotNull);
    expect(bloc.state.hasChart, isTrue);
    expect(bloc.state.hasFindings, isFalse);
    await bloc.close();
  });

  test('batches accumulate rather than replace', () async {
    // The job sends deltas so it can forget them, which is what keeps a walk of
    // a hundred thousand files from holding a hundred thousand anything.
    insightsRepo.updates = <InsightsUpdate>[
      InsightsMeasured(<StorageSlice>[
        slice(StorageSliceCategory.photos, 2 * AppByteUnits.megabyte),
      ]),
      InsightsMeasured(<StorageSlice>[
        slice(StorageSliceCategory.photos, 3 * AppByteUnits.megabyte),
        slice(StorageSliceCategory.videos, 10 * AppByteUnits.megabyte),
      ]),
    ];

    final StorageInsightsBloc bloc = await started();
    bloc.add(const InsightsMeasureRequested());
    await settle();

    expect(
      bloc.state.measured[StorageSliceCategory.photos]?.bytes,
      5 * AppByteUnits.megabyte,
    );
    expect(
      bloc.state.measured[StorageSliceCategory.videos]?.bytes,
      10 * AppByteUnits.megabyte,
    );
    expect(bloc.state.hasMeasured, isTrue);
    await bloc.close();
  });

  test('a measurement that found nothing says so rather than drawing zero',
      () async {
    final StorageInsightsBloc bloc = await started();
    bloc.add(const InsightsMeasureRequested());
    await settle();

    expect(bloc.state.foundNothing, isTrue);
    await bloc.close();
  });

  test('cancelling surfaces the failure and goes back to idle', () async {
    insightsRepo.holdOpen = true;

    final StorageInsightsBloc bloc = await started();
    bloc.add(const InsightsMeasureRequested());
    await settle();

    expect(bloc.state.isMeasuring, isTrue);

    bloc.add(const InsightsMeasureCancelled());
    await settle();

    expect(insightsRepo.wasCancelled, isTrue);
    expect(bloc.state.failure, isA<InsightsScanCancelledFailure>());
    expect(bloc.state.isMeasuring, isFalse);
    await bloc.close();
  });

  test('a platform with nothing to walk offers no button', () async {
    insightsRepo.isSupported = false;

    final StorageInsightsBloc bloc = await started();

    expect(bloc.state.isSupported, isFalse);
    expect(bloc.state.canMeasure, isFalse);
    await bloc.close();
  });

  test('closing the bloc stops a walk that is still running', () async {
    insightsRepo.holdOpen = true;

    final StorageInsightsBloc bloc = await started();
    bloc.add(const InsightsMeasureRequested());
    await settle();

    await bloc.close();

    expect(insightsRepo.wasCancelled, isTrue);
  });

  test('a folder handed over afterwards drops what was measured before it',
      () async {
    // The totals were counted under the old permission, and a chart mixing two
    // walks is a chart nobody can reason about.
    insightsRepo.updates = <InsightsUpdate>[
      InsightsMeasured(<StorageSlice>[
        slice(StorageSliceCategory.photos, AppByteUnits.megabyte),
      ]),
    ];

    final StorageInsightsBloc bloc = await started();
    bloc.add(const InsightsMeasureRequested());
    await settle();

    expect(bloc.state.hasFindings, isTrue);

    bloc.add(const InsightsFolderRequested());
    await settle();

    expect(bloc.state.hasFindings, isFalse);
    await bloc.close();
  });
}
