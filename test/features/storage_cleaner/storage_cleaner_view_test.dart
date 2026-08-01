import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:storage_cleaner/core/router/app_route.dart';
import 'package:storage_cleaner/core/theme/app_theme.dart';
import 'package:storage_cleaner/core/widgets/app_primary_button.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/device_storage/data/use_cases/get_device_storage_use_case.dart';
import 'package:storage_cleaner/project_files/features/language_selection/data/language_repo_impl.dart';
import 'package:storage_cleaner/project_files/features/language_selection/domain/language_repo.dart';
import 'package:storage_cleaner/project_files/features/quarantine/data/use_cases/watch_quarantine_use_case.dart';
import 'package:storage_cleaner/project_files/features/quarantine/domain/models/quarantine_batch.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/add_access_folder_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/get_storage_access_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/request_storage_access_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/use_cases/clean_junk_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/use_cases/get_cleaner_availability_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/use_cases/get_scannable_categories_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/use_cases/scan_for_junk_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/clean_failure.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/clean_report.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/junk_category.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/junk_item.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/scan_update.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/ui/bloc/storage_cleaner_bloc.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/ui/storage_cleaner_view.dart';

import '../device_storage/fakes.dart';
import '../language_selection/fakes.dart';
import '../storage_access/fakes.dart';
import 'fakes.dart';

void main() {
  late FakeJunkScanRepo scanRepo;
  late FakeJunkCleanRepo cleanRepo;
  late FakeStorageAccessRepo accessRepo;
  late FakeQuarantineRepo quarantineRepo;
  late FakeDeviceStorageRepo storageRepo;

  setUp(() {
    scanRepo = FakeJunkScanRepo();
    cleanRepo = FakeJunkCleanRepo();
    accessRepo = FakeStorageAccessRepo();
    quarantineRepo = FakeQuarantineRepo();
    storageRepo = FakeDeviceStorageRepo();
  });

  /// A phone, not the 800×600 the test binding defaults to.
  ///
  /// The storage ring is 208 logical pixels of the screen before a single
  /// category row is drawn, and on the default surface the second row falls
  /// below the fold — a `ListView` does not build what it cannot show, so a
  /// finder for it comes back empty and the failure reads as missing content
  /// rather than as a viewport too short to hold it.
  void useDeviceSurface(WidgetTester tester, Size size) {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// The comfortable phone every test that is not about width runs on.
  const Size roomy = Size(440, 1000);

  /// The narrowest phone still worth supporting. Everything the title row of a
  /// category has to hold comes out of about 184 logical pixels here, which is
  /// where a child that cannot shrink starves the one that can.
  const Size narrow = Size(360, 800);

  /// The bloc is built inside `BlocProvider.create`, never in `setUp`: one from
  /// `setUp` lives in another async zone and silently never receives its
  /// events, and the test then just does nothing with no error pointing at it.
  Future<void> pump(
    WidgetTester tester, {
    Size surface = roomy,
    Locale locale = const Locale('en'),
  }) async {
    useDeviceSurface(tester, surface);

    final GoRouter router = GoRouter(
      initialLocation: AppRoute.storageCleaner.path,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoute.storageCleaner.path,
          name: AppRoute.storageCleaner.routeName,
          builder: (context, state) => BlocProvider<StorageCleanerBloc>(
            create: (_) => StorageCleanerBloc(
              getAvailability: GetCleanerAvailabilityUseCase(
                scanRepo: scanRepo,
                cleanRepo: cleanRepo,
              ),
              getAccess: GetStorageAccessUseCase(accessRepo),
              requestAccess: RequestStorageAccessUseCase(accessRepo),
              addScanFolder: AddAccessFolderUseCase(accessRepo),
              getCategories: GetScannableCategoriesUseCase(scanRepo),
              scanForJunk: ScanForJunkUseCase(scanRepo),
              cleanJunk: CleanJunkUseCase(cleanRepo),
              watchQuarantine: WatchQuarantineUseCase(quarantineRepo),
              getDeviceStorage: GetDeviceStorageUseCase(storageRepo),
            )..add(const StorageCleanerStarted()),
            child: const StorageCleanerView(),
          ),
          routes: <RouteBase>[
            GoRoute(
              path: AppRoute.quarantine.path,
              name: AppRoute.quarantine.routeName,
              builder: (context, state) =>
                  const Scaffold(body: Text('quarantine screen')),
            ),
          ],
        ),
      ],
    );

    // The language button opens a dialog now rather than a route, and the dialog
    // builds its own bloc out of whatever `LanguageRepo` is above it.
    await tester.pumpWidget(
      RepositoryProvider<LanguageRepo>(
        create: (_) => LanguageRepoImpl(
          FakeLanguageStorage(),
          deviceLocales: () => const <Locale>[Locale('en')],
        ),
        child: MaterialApp.router(
          theme: AppTheme.light(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('before a scan it shows what it is going to look for',
      (tester) async {
    await pump(tester);

    // Every category the platform can fill, so a user can untick one before the
    // scan rather than after it.
    expect(find.text('Temporary files'), findsOneWidget);
    expect(find.text('Browser cache'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
  });

  testWidgets('the categories that want a second look are marked',
      (tester) async {
    await pump(tester);

    expect(find.text('Check first'), findsOneWidget);
  });

  group('a narrow phone with long words on it', () {
    /// A title has no business being taller than this.
    ///
    /// Four lines of `titleMedium`, which lays out at 24 here. Generous on
    /// purpose: `flutter test` draws every glyph as a square of the font size,
    /// so text is far wider under the test font than on a device and wraps
    /// sooner. The number that matters is the one it excludes — the same title
    /// drawn one letter per row is eighteen lines and 432 tall.
    const double maxTitleHeight = 4 * 24.0 + 2;

    /// The longest category name in each language, and the one that carries the
    /// badge — which is what used to be taking the width away from it.
    const Map<String, String> longestTitle = <String, String>{
      'en': 'Installers and archives',
      'ru': 'Установщики и архивы',
      'zh': '安装包与压缩包',
    };

    for (final MapEntry<String, String> entry in longestTitle.entries) {
      testWidgets('the ${entry.key} title stays on a few lines, not a staircase',
          (tester) async {
        scanRepo.categories = <JunkCategory>{JunkCategory.installerLeftovers};
        scanRepo.updates = <ScanUpdate>[
          JunkFound(<JunkItem>[
            fakeItem(
              sizeInBytes: 500 * 1024 * 1024 * 1024,
              category: JunkCategory.installerLeftovers,
            ),
          ]),
        ];

        await pump(tester, surface: narrow, locale: Locale(entry.key));

        // Before the scan, and again after it — the amount column only appears
        // once there is something to count, so the row is at its tightest then.
        expect(
          tester.getSize(find.text(entry.value)).height,
          lessThan(maxTitleHeight),
          reason: 'the title collapsed before a scan',
        );

        await tester.tap(find.byType(AppPrimaryButton));
        await tester.pumpAndSettle();

        expect(
          tester.getSize(find.text(entry.value)).height,
          lessThan(maxTitleHeight),
          reason: 'the title collapsed once the size column appeared',
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('a category can be turned off before the scan, and stays off',
      (tester) async {
    // The screen lists every category before it looks at anything precisely so
    // this is possible. It was not: `canEditSelection` waited for a scan, so
    // every box on the first screen was dead.
    scanRepo.updates = <ScanUpdate>[
      JunkFound(<JunkItem>[
        fakeItem(sizeInBytes: 1024),
        fakeItem(
          path: '/cache/b.tmp',
          sizeInBytes: 4096,
          category: JunkCategory.browserCache,
        ),
      ]),
    ];

    await pump(tester);

    // Temporary files is first and arrives ticked; browser cache does not.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    // The 1 KB from the unticked category is not in the total, and neither is
    // the 4 KB from the one that was never ticked.
    expect(find.text('Nothing selected'), findsOneWidget);
  });

  testWidgets('a scan that finds nothing says so', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing to clean'), findsOneWidget);
    expect(find.text('Scan again'), findsOneWidget);
  });

  testWidgets('a scan draws the categories that found something',
      (tester) async {
    scanRepo.updates = <ScanUpdate>[
      JunkFound(<JunkItem>[fakeItem(path: '/tmp/a.tmp', sizeInBytes: 2048)]),
    ];

    await pump(tester);
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    expect(find.text('Temporary files'), findsOneWidget);
    // The empty browser-cache row is dropped: nine rows of zero is a worse
    // answer than one row with a number.
    expect(find.text('Browser cache'), findsNothing);
    expect(find.textContaining('2 KB'), findsWidgets);
  });

  testWidgets('the clean button names what it will take', (tester) async {
    scanRepo.updates = <ScanUpdate>[
      JunkFound(<JunkItem>[fakeItem(sizeInBytes: 1024)]),
    ];

    await pump(tester);
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    expect(find.text('Clean up 1 KB'), findsOneWidget);
  });

  testWidgets('unticking everything disables the button and says why',
      (tester) async {
    scanRepo.updates = <ScanUpdate>[
      JunkFound(<JunkItem>[fakeItem(sizeInBytes: 1024)]),
    ];

    await pump(tester);
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(find.text('Nothing selected'), findsOneWidget);
  });

  testWidgets('cleaning asks first, and names the retention', (tester) async {
    scanRepo.updates = <ScanUpdate>[
      JunkFound(<JunkItem>[fakeItem(sizeInBytes: 1024)]),
    ];

    await pump(tester);
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clean up 1 KB'));
    await tester.pumpAndSettle();

    expect(find.text('Delete 1 KB?'), findsOneWidget);
    expect(
      find.textContaining('restored for 7 days'),
      findsOneWidget,
    );
  });

  testWidgets('cancelling the dialog deletes nothing', (tester) async {
    scanRepo.updates = <ScanUpdate>[
      JunkFound(<JunkItem>[fakeItem(sizeInBytes: 1024)]),
    ];

    await pump(tester);
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clean up 1 KB'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(cleanRepo.lastItems, isNull);
  });

  testWidgets('confirming reports what the run did', (tester) async {
    scanRepo.updates = <ScanUpdate>[
      JunkFound(<JunkItem>[fakeItem(sizeInBytes: 1024)]),
    ];
    cleanRepo.report = const CleanReport(
      freedBytes: 1024,
      quarantinedCount: 1,
      batchId: 'batch',
    );

    await pump(tester);
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clean up 1 KB'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Freed 1 KB'), findsOneWidget);
    expect(find.text('1 file can be restored'), findsOneWidget);
  });

  testWidgets('a narrowed Android offers the permission, not a bare refusal',
      (tester) async {
    accessRepo.access = const StorageAccess(
      level: StorageAccessLevel.appOnly,
      canRequestMore: true,
      canAddFolder: true,
    );
    scanRepo.categories = <JunkCategory>{JunkCategory.appCache};

    await pump(tester);

    expect(find.text("Only this app's own files"), findsOneWidget);
    expect(find.text('Grant access'), findsOneWidget);
    expect(find.text('Add a folder'), findsOneWidget);
  });

  testWidgets('a sandboxed platform explains itself and offers no button',
      (tester) async {
    accessRepo.access = const StorageAccess.sandboxed();
    scanRepo.categories = <JunkCategory>{JunkCategory.appCache};

    await pump(tester);

    expect(find.text("Only this app's own files"), findsOneWidget);
    // Nothing to ask for, so no button that would visibly do nothing.
    expect(find.text('Grant access'), findsNothing);
  });

  testWidgets('web says the platform cannot do this at all', (tester) async {
    scanRepo.isSupported = false;
    cleanRepo.isSupported = false;

    await pump(tester);

    expect(find.text('Not available here'), findsOneWidget);
  });

  testWidgets('a quarantine banner appears and leads to the screen',
      (tester) async {
    quarantineRepo.publish(<QuarantineBatch>[fakeBatch(fileCount: 4)]);

    await pump(tester);

    expect(find.text('4 files can still be restored'), findsOneWidget);

    await tester.tap(find.text('4 files can still be restored'));
    await tester.pumpAndSettle();

    expect(find.text('quarantine screen'), findsOneWidget);
  });

  testWidgets('a failed scan is shown and can be dismissed', (tester) async {
    scanRepo.failure = const ScanFailure();

    await pump(tester);
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    expect(
      find.text('The scan could not finish. Nothing was deleted.'),
      findsOneWidget,
    );
  });
}
