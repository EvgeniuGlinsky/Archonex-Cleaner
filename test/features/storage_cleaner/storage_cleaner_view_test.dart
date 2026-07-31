import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:archonex_cleaner/core/router/app_route.dart';
import 'package:archonex_cleaner/core/theme/app_theme.dart';
import 'package:archonex_cleaner/l10n/app_localizations.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/data/use_cases/watch_quarantine_use_case.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/domain/models/quarantine_batch.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/use_cases/add_scan_folder_use_case.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/use_cases/clean_junk_use_case.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/use_cases/get_cleaner_availability_use_case.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/use_cases/get_scannable_categories_use_case.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/use_cases/get_storage_access_use_case.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/use_cases/request_storage_access_use_case.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/use_cases/scan_for_junk_use_case.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/clean_failure.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/clean_report.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_category.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_item.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/scan_update.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/storage_access.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/ui/bloc/storage_cleaner_bloc.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/ui/storage_cleaner_view.dart';

import 'fakes.dart';

void main() {
  late FakeJunkScanRepo scanRepo;
  late FakeJunkCleanRepo cleanRepo;
  late FakeStorageAccessRepo accessRepo;
  late FakeQuarantineRepo quarantineRepo;

  setUp(() {
    scanRepo = FakeJunkScanRepo();
    cleanRepo = FakeJunkCleanRepo();
    accessRepo = FakeStorageAccessRepo();
    quarantineRepo = FakeQuarantineRepo();
  });

  /// The bloc is built inside `BlocProvider.create`, never in `setUp`: one from
  /// `setUp` lives in another async zone and silently never receives its
  /// events, and the test then just does nothing with no error pointing at it.
  Future<void> pump(WidgetTester tester) async {
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
              addScanFolder: AddScanFolderUseCase(accessRepo),
              getCategories: GetScannableCategoriesUseCase(scanRepo),
              scanForJunk: ScanForJunkUseCase(scanRepo),
              cleanJunk: CleanJunkUseCase(cleanRepo),
              watchQuarantine: WatchQuarantineUseCase(quarantineRepo),
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
        GoRoute(
          path: AppRoute.languageSelection.path,
          name: AppRoute.languageSelection.routeName,
          builder: (context, state) =>
              const Scaffold(body: Text('language screen')),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
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
