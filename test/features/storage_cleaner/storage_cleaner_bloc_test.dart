import 'package:flutter_test/flutter_test.dart';

import 'package:archonex_cleaner/project_files/features/device_storage/data/use_cases/get_device_storage_use_case.dart';
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
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_group.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_item.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/scan_update.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/storage_access.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/ui/bloc/storage_cleaner_bloc.dart';

import '../device_storage/fakes.dart';
import 'fakes.dart';

/// There is no `bloc_test` here, so nothing else drains the event queue before
/// an assertion reads `bloc.state`.
Future<void> settle() => Future<void>.delayed(Duration.zero);

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

  StorageCleanerBloc build() {
    return StorageCleanerBloc(
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
      getDeviceStorage: GetDeviceStorageUseCase(storageRepo),
    );
  }

  Future<StorageCleanerBloc> started() async {
    final StorageCleanerBloc bloc = build();
    bloc.add(const StorageCleanerStarted());
    await settle();

    return bloc;
  }

  group('start', () {
    test('lists a group per category the platform can fill', () async {
      final StorageCleanerBloc bloc = await started();

      expect(
        bloc.state.groups.map((group) => group.category),
        <JunkCategory>[JunkCategory.systemTemp, JunkCategory.browserCache],
      );
      await bloc.close();
    });

    test('a category off by default arrives unticked', () async {
      final StorageCleanerBloc bloc = await started();

      final JunkGroup browser = bloc.state.groups.firstWhere(
        (group) => group.category == JunkCategory.browserCache,
      );

      expect(browser.isSelected, isFalse);
      expect(
        bloc.state.groups
            .firstWhere((g) => g.category == JunkCategory.systemTemp)
            .isSelected,
        isTrue,
      );
      await bloc.close();
    });

    test('an unsupported platform reports itself and offers no groups',
        () async {
      scanRepo.isSupported = false;

      final StorageCleanerBloc bloc = await started();

      expect(bloc.state.isSupported, isFalse);
      expect(bloc.state.canScan, isFalse);
      expect(bloc.state.groups, isEmpty);
      await bloc.close();
    });
  });

  group('scan', () {
    test('files findings into their categories and ends scanned', () async {
      scanRepo.updates = <ScanUpdate>[
        const ScanLocationChanged(label: '%TEMP%'),
        JunkFound(<JunkItem>[
          fakeItem(path: '/tmp/a.tmp', sizeInBytes: 100),
          fakeItem(
            path: '/tmp/cache',
            sizeInBytes: 900,
            category: JunkCategory.browserCache,
          ),
        ]),
      ];

      final StorageCleanerBloc bloc = await started();
      bloc.add(const ScanRequested());
      await settle();

      expect(bloc.state.status, StorageCleanerStatus.scanned);
      expect(bloc.state.foundCount, 2);
      expect(bloc.state.foundBytes, 1000);
      // Only the ticked category counts towards what a cleanup would take.
      expect(bloc.state.selectedBytes, 100);
      await bloc.close();
    });

    test('scans every category, ticked or not', () async {
      final StorageCleanerBloc bloc = await started();
      bloc.add(const CategoryToggled(JunkCategory.systemTemp));
      await settle();
      bloc.add(const ScanRequested());
      await settle();

      // Unticking says "do not delete this", not "do not look" — a user who
      // reads the figure and changes their mind must not have to scan again.
      expect(scanRepo.lastRequestedCategories, <JunkCategory>{
        JunkCategory.systemTemp,
        JunkCategory.browserCache,
      });
      await bloc.close();
    });

    test('a second scan starts from nothing rather than appending', () async {
      scanRepo.updates = <ScanUpdate>[
        JunkFound(<JunkItem>[fakeItem(path: '/tmp/a.tmp')]),
      ];

      final StorageCleanerBloc bloc = await started();
      bloc.add(const ScanRequested());
      await settle();
      bloc.add(const ScanRequested());
      await settle();

      expect(scanRepo.scanCount, 2);
      expect(bloc.state.foundCount, 1);
      await bloc.close();
    });

    test('a truncated walk is reported on the category it stopped in',
        () async {
      scanRepo.updates = <ScanUpdate>[
        JunkFound(<JunkItem>[fakeItem()]),
        const ScanTruncated(category: JunkCategory.systemTemp),
      ];

      final StorageCleanerBloc bloc = await started();
      bloc.add(const ScanRequested());
      await settle();

      expect(
        bloc.state.groups
            .firstWhere((g) => g.category == JunkCategory.systemTemp)
            .isTruncated,
        isTrue,
      );
      await bloc.close();
    });

    test('a failed scan goes back to idle and surfaces the failure', () async {
      scanRepo.failure = const ScanFailure();

      final StorageCleanerBloc bloc = await started();
      bloc.add(const ScanRequested());
      await settle();

      expect(bloc.state.status, StorageCleanerStatus.idle);
      expect(bloc.state.failure, isA<ScanFailure>());
      await bloc.close();
    });

    test('cancelling reaches the job', () async {
      scanRepo.holdOpen = true;

      final StorageCleanerBloc bloc = await started();
      bloc.add(const ScanRequested());
      await settle();
      expect(bloc.state.isScanning, isTrue);

      bloc.add(const ScanCancelled());
      await settle();

      expect(scanRepo.wasCancelled, isTrue);
      await bloc.close();
    });
  });

  group('selection', () {
    Future<StorageCleanerBloc> scanned() async {
      scanRepo.updates = <ScanUpdate>[
        JunkFound(<JunkItem>[
          fakeItem(path: '/tmp/a.tmp', sizeInBytes: 100),
          fakeItem(path: '/tmp/b.tmp', sizeInBytes: 200),
        ]),
      ];

      final StorageCleanerBloc bloc = await started();
      bloc.add(const ScanRequested());
      await settle();

      return bloc;
    }

    group('when the boxes may be touched', () {
      test('before a scan, which is what the rows are drawn for', () async {
        // It read `hasScanned && !isBusy` and shipped with every box on the
        // first screen greyed out, on a screen that lists all nine categories
        // precisely so one can be turned off in advance.
        final StorageCleanerBloc bloc = await started();

        expect(bloc.state.hasScanned, isFalse);
        expect(bloc.state.canEditSelection, isTrue);
        await bloc.close();
      });

      test('while a scan is still finding things', () async {
        // `JunkGroup` stores the user's decision as exclusions for exactly this
        // — a list that keeps growing under an unticked row.
        scanRepo.holdOpen = true;

        final StorageCleanerBloc bloc = await started();
        bloc.add(const ScanRequested());
        await settle();

        expect(bloc.state.isScanning, isTrue);
        expect(bloc.state.canEditSelection, isTrue);
        await bloc.close();
      });

      test('never during a cleanup', () async {
        // The file list was taken when the run started, so an unticked row
        // would be promising to spare a file already being deleted.
        const StorageCleanerState cleaning = StorageCleanerState(
          status: StorageCleanerStatus.cleaning,
        );

        expect(cleaning.canEditSelection, isFalse);
      });

      test('never on a platform with no file system', () {
        const StorageCleanerState unsupported =
            StorageCleanerState(isSupported: false);

        expect(unsupported.canEditSelection, isFalse);
      });
    });

    test('a category turned off before the scan is still off after it',
        () async {
      final StorageCleanerBloc bloc = await started();

      bloc.add(const CategoryToggled(JunkCategory.systemTemp));
      await settle();

      scanRepo.updates = <ScanUpdate>[
        JunkFound(<JunkItem>[fakeItem(path: '/tmp/a.tmp', sizeInBytes: 100)]),
      ];
      bloc.add(const ScanRequested());
      await settle();

      // `_onScanRequested` empties `items` without touching `isSelected`, which
      // is what makes the choice worth offering before the walk.
      expect(bloc.state.foundBytes, 100);
      expect(bloc.state.selectedCount, 0);
      await bloc.close();
    });

    test('unticking one row leaves the rest selected', () async {
      final StorageCleanerBloc bloc = await scanned();

      bloc.add(
        const ItemToggled(
          category: JunkCategory.systemTemp,
          path: '/tmp/a.tmp',
        ),
      );
      await settle();

      expect(bloc.state.selectedCount, 1);
      expect(bloc.state.selectedBytes, 200);
      await bloc.close();
    });

    test('a partly-unticked category reports itself as such', () async {
      final StorageCleanerBloc bloc = await scanned();

      bloc.add(
        const ItemToggled(
          category: JunkCategory.systemTemp,
          path: '/tmp/a.tmp',
        ),
      );
      await settle();

      expect(
        bloc.state.groups
            .firstWhere((g) => g.category == JunkCategory.systemTemp)
            .isPartiallySelected,
        isTrue,
      );
      await bloc.close();
    });

    test('turning a category off and on again clears the exclusions', () async {
      final StorageCleanerBloc bloc = await scanned();

      bloc.add(
        const ItemToggled(
          category: JunkCategory.systemTemp,
          path: '/tmp/a.tmp',
        ),
      );
      await settle();
      bloc.add(const CategoryToggled(JunkCategory.systemTemp));
      await settle();
      bloc.add(const CategoryToggled(JunkCategory.systemTemp));
      await settle();

      // A remembered exclusion the row no longer shows is a file the user
      // thinks they are deleting and is not.
      expect(bloc.state.selectedCount, 2);
      await bloc.close();
    });

    test('nothing selected means the clean button is off', () async {
      final StorageCleanerBloc bloc = await scanned();

      bloc.add(const CategoryToggled(JunkCategory.systemTemp));
      await settle();

      expect(bloc.state.selectedCount, 0);
      expect(bloc.state.canClean, isFalse);
      await bloc.close();
    });
  });

  group('clean', () {
    Future<StorageCleanerBloc> scanned() async {
      scanRepo.updates = <ScanUpdate>[
        JunkFound(<JunkItem>[
          fakeItem(path: '/tmp/a.tmp', sizeInBytes: 100),
          fakeItem(path: '/tmp/b.tmp', sizeInBytes: 200),
        ]),
      ];

      final StorageCleanerBloc bloc = await started();
      bloc.add(const ScanRequested());
      await settle();

      return bloc;
    }

    test('hands the deleter exactly what is selected', () async {
      final StorageCleanerBloc bloc = await scanned();

      bloc.add(
        const ItemToggled(
          category: JunkCategory.systemTemp,
          path: '/tmp/a.tmp',
        ),
      );
      await settle();
      bloc.add(const CleanRequested());
      await settle();

      expect(
        cleanRepo.lastItems?.map((item) => item.path),
        <String>['/tmp/b.tmp'],
      );
      await bloc.close();
    });

    test('finishes with the report and drops what went', () async {
      cleanRepo.report = const CleanReport(
        freedBytes: 300,
        quarantinedCount: 2,
        batchId: 'batch',
      );

      final StorageCleanerBloc bloc = await scanned();
      bloc.add(const CleanRequested());
      await settle();

      expect(bloc.state.status, StorageCleanerStatus.cleaned);
      expect(bloc.state.report?.freedBytes, 300);
      expect(bloc.state.foundCount, 0);
      await bloc.close();
    });

    test('a row the user unticked survives the cleanup', () async {
      final StorageCleanerBloc bloc = await scanned();

      bloc.add(
        const ItemToggled(
          category: JunkCategory.systemTemp,
          path: '/tmp/a.tmp',
        ),
      );
      await settle();
      bloc.add(const CleanRequested());
      await settle();

      // Still on disk, still junk, and back to selected so the next run takes
      // it if the user changes their mind.
      expect(
        bloc.state.groups
            .firstWhere((g) => g.category == JunkCategory.systemTemp)
            .items
            .map((item) => item.path),
        <String>['/tmp/a.tmp'],
      );
      expect(bloc.state.selectedCount, 1);
      await bloc.close();
    });

    test('a cancelled run still reports what it managed', () async {
      cleanRepo.report = const CleanReport(
        freedBytes: 100,
        quarantinedCount: 1,
        batchId: 'batch',
        wasCancelled: true,
      );

      final StorageCleanerBloc bloc = await scanned();
      bloc.add(const CleanRequested());
      await settle();

      expect(bloc.state.report?.wasCancelled, isTrue);
      expect(bloc.state.report?.freedBytes, 100);
      await bloc.close();
    });

    test('cancelling reaches the job', () async {
      final StorageCleanerBloc bloc = await scanned();
      bloc.add(const CleanRequested());
      bloc.add(const CleanCancelled());
      await settle();

      expect(cleanRepo.wasCancelled, isTrue);
      await bloc.close();
    });

    test('dismissing the result keeps the remaining findings', () async {
      cleanRepo.report = const CleanReport(skippedCount: 2);

      final StorageCleanerBloc bloc = await scanned();
      bloc.add(const CleanRequested());
      await settle();
      bloc.add(const ResultDismissed());
      await settle();

      // Nothing was deleted, so nothing left the list.
      expect(bloc.state.report, isNull);
      expect(bloc.state.status, StorageCleanerStatus.scanned);
      expect(bloc.state.foundCount, 2);
      await bloc.close();
    });
  });

  group('access', () {
    test('granting wider access widens the category list', () async {
      accessRepo.access = const StorageAccess(
        level: StorageAccessLevel.appOnly,
        canRequestMore: true,
        canAddFolder: true,
      );
      scanRepo.categories = <JunkCategory>{JunkCategory.appCache};

      final StorageCleanerBloc bloc = await started();
      expect(bloc.state.groups.length, 1);

      accessRepo.granted = const StorageAccess(level: StorageAccessLevel.full);
      scanRepo.categories = <JunkCategory>{
        JunkCategory.appCache,
        JunkCategory.thumbnails,
      };

      bloc.add(const AccessRequested());
      await settle();

      expect(bloc.state.access.isComplete, isTrue);
      expect(bloc.state.groups.length, 2);
      await bloc.close();
    });

    test('a refusal with no way back surfaces the failure', () async {
      accessRepo.access = const StorageAccess(
        level: StorageAccessLevel.appOnly,
        canRequestMore: true,
      );
      accessRepo.granted = const StorageAccess(
        level: StorageAccessLevel.appOnly,
      );

      final StorageCleanerBloc bloc = await started();
      bloc.add(const AccessRequested());
      await settle();

      expect(bloc.state.failure, isA<StorageAccessDeniedFailure>());
      await bloc.close();
    });

    test('a picked folder becomes a scannable root', () async {
      accessRepo.access = const StorageAccess(
        level: StorageAccessLevel.appOnly,
        canAddFolder: true,
      );
      accessRepo.picked = const StorageAccess(
        level: StorageAccessLevel.scopedFolders,
        grantedRoots: <String>['/sdcard/Books'],
        canAddFolder: true,
      );

      final StorageCleanerBloc bloc = await started();
      bloc.add(const ScanFolderRequested());
      await settle();

      expect(bloc.state.access.grantedRoots, <String>['/sdcard/Books']);
      await bloc.close();
    });

    test('widening access drops findings from the previous access', () async {
      scanRepo.updates = <ScanUpdate>[
        JunkFound(<JunkItem>[fakeItem()]),
      ];
      accessRepo.access = const StorageAccess(
        level: StorageAccessLevel.appOnly,
        canRequestMore: true,
      );
      accessRepo.granted = const StorageAccess(level: StorageAccessLevel.full);

      final StorageCleanerBloc bloc = await started();
      bloc.add(const ScanRequested());
      await settle();
      expect(bloc.state.foundCount, 1);

      bloc.add(const AccessRequested());
      await settle();

      // A list mixing two scans is a list nobody can reason about.
      expect(bloc.state.foundCount, 0);
      expect(bloc.state.status, StorageCleanerStatus.idle);
      await bloc.close();
    });
  });

  group('quarantine banner', () {
    test('counts every restorable file across batches', () async {
      final StorageCleanerBloc bloc = await started();
      expect(bloc.state.hasQuarantine, isFalse);

      quarantineRepo.publish(<QuarantineBatch>[
        fakeBatch(id: 'a', fileCount: 2),
        fakeBatch(id: 'b', fileCount: 3),
      ]);
      await settle();

      expect(bloc.state.quarantinedFileCount, 5);
      expect(bloc.state.hasQuarantine, isTrue);
      await bloc.close();
    });
  });

  test('closing the bloc stops a scan that is still running', () async {
    scanRepo.holdOpen = true;

    final StorageCleanerBloc bloc = await started();
    bloc.add(const ScanRequested());
    await settle();
    expect(bloc.state.isScanning, isTrue);

    await bloc.close();

    // A walk of a Windows %TEMP% outlives the screen by minutes otherwise.
    expect(scanRepo.wasCancelled, isTrue);
  });
}
