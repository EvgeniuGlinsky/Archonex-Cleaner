import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:storage_cleaner/core/constants/app_byte_units.dart';
import 'package:storage_cleaner/core/theme/app_theme.dart';
import 'package:storage_cleaner/core/widgets/app_primary_button.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/device_storage/data/use_cases/get_device_storage_use_case.dart';
import 'package:storage_cleaner/project_files/features/device_storage/ui/widgets/storage_ring.dart';
import 'package:storage_cleaner/project_files/features/language_selection/data/language_repo_impl.dart';
import 'package:storage_cleaner/project_files/features/language_selection/domain/language_repo.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/add_access_folder_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/get_storage_access_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/open_access_settings_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/request_storage_access_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/data/use_cases/get_insights_availability_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/data/use_cases/measure_storage_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/insights_update.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/storage_slice.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/ui/bloc/storage_insights_bloc.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/ui/storage_insights_view.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/ui/widgets/storage_breakdown_ring.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/ui/widgets/storage_slice_row.dart';

import '../device_storage/fakes.dart';
import '../language_selection/fakes.dart';
import '../storage_access/fakes.dart';
import 'fakes.dart';

void main() {
  late FakeStorageInsightsRepo insightsRepo;
  late FakeStorageAccessRepo accessRepo;
  late FakeDeviceStorageRepo storageRepo;

  setUp(() {
    insightsRepo = FakeStorageInsightsRepo();
    accessRepo = FakeStorageAccessRepo();
    storageRepo = FakeDeviceStorageRepo();
  });

  /// Tall enough that the ring, every row and the bottom slot are laid out at
  /// once. The default test surface is 800×600 and cuts the list in half.
  const Size roomy = Size(440, 1400);

  /// The bloc is built inside `BlocProvider.create`, never in `setUp`: one from
  /// `setUp` lives in another async zone and silently never receives its
  /// events, and the test then just does nothing with no error pointing at it.
  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = roomy
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      RepositoryProvider<LanguageRepo>(
        create: (_) => LanguageRepoImpl(
          FakeLanguageStorage(),
          deviceLocales: () => const <Locale>[Locale('en')],
        ),
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<StorageInsightsBloc>(
            create: (_) => StorageInsightsBloc(
              getAvailability: GetInsightsAvailabilityUseCase(insightsRepo),
              getAccess: GetStorageAccessUseCase(accessRepo),
              requestAccess: RequestStorageAccessUseCase(accessRepo),
              addFolder: AddAccessFolderUseCase(accessRepo),
              openAccessSettings: OpenAccessSettingsUseCase(accessRepo),
              measureStorage: MeasureStorageUseCase(insightsRepo),
              getDeviceStorage: GetDeviceStorageUseCase(storageRepo),
            )..add(const StorageInsightsStarted()),
            child: const StorageInsightsView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void findsFiles() {
    insightsRepo.updates = <InsightsUpdate>[
      InsightsMeasured(<StorageSlice>[
        const StorageSlice(
          category: StorageSliceCategory.videos,
          bytes: 40 * AppByteUnits.gigabyte,
          fileCount: 120,
        ),
        const StorageSlice(
          category: StorageSliceCategory.photos,
          bytes: 12 * AppByteUnits.gigabyte,
          fileCount: 4000,
        ),
      ]),
    ];
  }

  testWidgets('before a measurement it explains what it is about to do',
      (tester) async {
    await pump(tester);

    expect(find.text('Measure'), findsOneWidget);
    expect(find.text('Nothing measured yet'), findsOneWidget);
  });

  testWidgets('the ring is the plain one until there are arcs to cut it into',
      (tester) async {
    // A breakdown ring with no segments is a grey circle, and it was drawn
    // around "85.7 GB / used of 105.6 GB" — the same figure the home, cleaner
    // and optimiser screens draw with the used arc filled in. Four screens, one
    // number, three of them blue.
    findsFiles();

    await pump(tester);

    expect(find.byType(StorageRing), findsOneWidget);
    expect(find.byType(StorageBreakdownRing), findsNothing);
    expect(find.text('used of 256 GB'), findsOneWidget);

    await tester.tap(find.text('Measure'));
    await tester.pumpAndSettle();

    // And once something has been counted the breakdown takes over, because
    // then there is something to break down.
    expect(find.byType(StorageBreakdownRing), findsOneWidget);
    expect(find.byType(StorageRing), findsNothing);
  });

  testWidgets('the sentence before a measurement sits in the space it has',
      (tester) async {
    // It used to be tucked under the ring with two thirds of the window blank
    // below it. `AppScreenLayout.fillsViewport` gives the column a real height
    // and the body centres in what is left.
    await pump(tester);

    final double ringBottom = tester.getRect(find.byType(StorageRing)).bottom;
    final Rect sentence = tester.getRect(find.text('Nothing measured yet'));
    final double buttonTop =
        tester.getRect(find.byType(AppPrimaryButton)).top;

    final double above = sentence.top - ringBottom;
    final double below = buttonTop - sentence.bottom;

    expect(above, greaterThan(0));
    expect(
      (above - below).abs(),
      lessThan(120),
      reason: 'centred in the room it has, not pinned to the ring: '
          'above $above, below $below',
    );
  });

  testWidgets('a finished count does not still say it is counting',
      (tester) async {
    // Reachable only where the platform will not say how big the volume is,
    // which leaves the count as the only figure there is. The caption under it
    // read "Adding it up…" whether or not anything still was.
    storageRepo.snapshot = null;
    findsFiles();

    await pump(tester);
    await tester.tap(find.text('Measure'));
    await tester.pumpAndSettle();

    expect(find.text('counted'), findsOneWidget);
    expect(find.text('Adding it up…'), findsNothing);
  });

  testWidgets('a measurement draws a ring and a row for every kind',
      (tester) async {
    findsFiles();

    await pump(tester);
    await tester.tap(find.text('Measure'));
    await tester.pumpAndSettle();

    expect(find.byType(StorageBreakdownRing), findsOneWidget);
    // Two measured, plus the two derived rows. The derived pair is what makes
    // the chart add up to the disk rather than to what happened to be counted.
    expect(find.byType(StorageSliceRow), findsNWidgets(4));
    expect(find.text('Videos'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('System and apps'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
  });

  testWidgets('every row is named and measured, never colour alone',
      (tester) async {
    // The palette's tritan separation sits in the band that is only legal with
    // a second channel, and this is the second channel. A row that lost its
    // label would make the chart unreadable for a reader who cannot tell two
    // of the hues apart.
    findsFiles();

    await pump(tester);
    await tester.tap(find.text('Measure'));
    await tester.pumpAndSettle();

    expect(find.text('40 GB'), findsOneWidget);
    expect(find.text('12 GB'), findsOneWidget);
  });

  testWidgets('and the chart says out loud what it could not look inside',
      (tester) async {
    findsFiles();

    await pump(tester);
    await tester.tap(find.text('Measure'));
    await tester.pumpAndSettle();

    expect(find.textContaining('where no app can read it'), findsOneWidget);
  });

  testWidgets('a measurement that found nothing says so', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Measure'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing found'), findsOneWidget);
    expect(find.text('Measure again'), findsOneWidget);
  });

  testWidgets('a platform with nothing to walk explains itself',
      (tester) async {
    insightsRepo.isSupported = false;

    await pump(tester);

    expect(find.text('Not on this platform'), findsOneWidget);
  });
}
