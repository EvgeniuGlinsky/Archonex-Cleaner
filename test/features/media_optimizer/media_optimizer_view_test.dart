import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:storage_cleaner/core/constants/app_byte_units.dart';
import 'package:storage_cleaner/core/theme/app_theme.dart';
import 'package:storage_cleaner/core/widgets/app_primary_button.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/device_storage/data/use_cases/get_device_storage_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/get_encoder_support_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/get_optimizable_kinds_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/get_optimizer_availability_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/optimize_media_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/scan_for_media_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/encoder_support.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_candidate.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_kind.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_scan_update.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_report.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_verdict.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/ui/bloc/media_optimizer_bloc.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/ui/media_optimizer_view.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/add_access_folder_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/get_storage_access_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/open_access_settings_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/request_storage_access_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';

import '../device_storage/fakes.dart';
import '../storage_access/fakes.dart';
import 'fakes.dart';

void main() {
  late FakeMediaScanRepo scanRepo;
  late FakeMediaOptimizeRepo optimizeRepo;
  late FakeStorageAccessRepo accessRepo;
  late FakeDeviceStorageRepo storageRepo;
  late FakeOptimizeQualityRepo qualityRepo;

  setUp(() {
    scanRepo = FakeMediaScanRepo();
    optimizeRepo = FakeMediaOptimizeRepo();
    accessRepo = FakeStorageAccessRepo();
    storageRepo = FakeDeviceStorageRepo();
    qualityRepo = FakeOptimizeQualityRepo();
  });

  /// Tall enough that both tiles, the ring and the bottom slot are all laid
  /// out at once. The default test surface is 800×600, where a `ListView`
  /// never builds the second tile and the assertions fail for a reason that
  /// has nothing to do with the screen.
  const Size roomy = Size(440, 1200);

  /// The narrowest phone still worth supporting.
  const Size narrow = Size(360, 800);

  /// A small phone with its system bars taken off, for the one test about
  /// scrolling: the tiles are compact enough now that two of them and a ring
  /// fit on [narrow] with nothing left to scroll.
  const Size short = Size(360, 560);

  /// The bloc is built inside `BlocProvider.create`, never in `setUp`: one from
  /// `setUp` lives in another async zone and silently never receives its
  /// events, and the test then just does nothing with no error pointing at it.
  Future<void> pump(
    WidgetTester tester, {
    Size? surface,
    Locale locale = const Locale('en'),
  }) async {
    tester.view
      ..physicalSize = surface ?? roomy
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<MediaOptimizerBloc>(
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
                support: () => bloc.state.support,
              ),
              getDeviceStorage: GetDeviceStorageUseCase(storageRepo),
              quality: qualityRepo,
            );

            return bloc..add(const MediaOptimizerStarted());
          },
          child: const MediaOptimizerView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void findsVideos({
    int sizeInBytes = 900 * AppByteUnits.megabyte,
    int estimatedBytes = 400 * AppByteUnits.megabyte,
    OptimizeVerdict verdict = OptimizeVerdict.worthIt,
  }) {
    scanRepo.updates = <MediaScanUpdate>[
      MediaFound(<MediaCandidate>[
        fakeCandidate(
          path: '/dcim/VID_0001.mp4',
          kind: MediaKind.video,
          sizeInBytes: sizeInBytes,
          estimatedBytes: estimatedBytes,
          verdict: verdict,
        ),
      ]),
    ];
  }

  /// The one button in the bottom slot.
  ///
  /// Found through `AppPrimaryButton` rather than by type: the access notice
  /// puts a `FilledButton.tonal` in the body, and `find.byType(FilledButton)`
  /// then matches two and throws.
  FilledButton primaryButton(WidgetTester tester) => tester.widget<FilledButton>(
        find.descendant(
          of: find.byType(AppPrimaryButton),
          matching: find.byType(FilledButton),
        ),
      );

  Future<void> scan(WidgetTester tester) async {
    await tester.tap(find.text('Look for large files'));
    await tester.pumpAndSettle();
  }

  testWidgets('before a scan it explains what it is about to read',
      (tester) async {
    await pump(tester);

    expect(find.text('Look for large files'), findsOneWidget);
    // Both kinds are on the screen before anything is measured, so the user
    // knows what is covered rather than only what happened to turn up. They
    // are also why the idle empty state is not here: the list is not empty.
    expect(find.text('Videos'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Clips shot on this device, and anything downloaded.'),
        findsOneWidget);
  });

  testWidgets('a scan names the saving, not the size of the files',
      (tester) async {
    // The files are staying. Reporting "859 MB found" for a folder that will
    // still be there afterwards answers a question nobody asked.
    findsVideos();
    await pump(tester);
    await scan(tester);

    expect(find.text('Save 500 MB'), findsOneWidget);
    expect(find.textContaining('could be saved'), findsOneWidget);
  });

  testWidgets('a file nothing can be done about is shown with its reason',
      (tester) async {
    // "Your largest video is 4 GB and here is why nothing can be done" is the
    // answer somebody with a full disk actually needs.
    findsVideos(
      sizeInBytes: 4 * AppByteUnits.gigabyte,
      verdict: OptimizeVerdict.alreadyEfficient,
    );
    await pump(tester);
    await scan(tester);

    await tester.tap(find.text('Videos'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('already about as small as it goes'),
      findsOneWidget,
    );
    // And no button offering to do something about it.
    expect(find.textContaining('Save '), findsNothing);

    // Said as well as shown. This used to assert the opposite — that the
    // heading was absent — which was the bug written down as the expectation:
    // the screen drew four gigabytes of unactionable rows under no heading at
    // all, and left the user to work out why the button was off.
    expect(find.text('Everything is already efficient'), findsOneWidget);
  });

  testWidgets('a device with nothing worth doing says so plainly',
      (tester) async {
    await pump(tester);
    await scan(tester);

    expect(find.text('No large photos or videos'), findsOneWidget);
  });

  testWidgets('unticking everything disables the button and says why',
      (tester) async {
    findsVideos();
    await pump(tester);
    await scan(tester);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(find.text('Nothing selected'), findsOneWidget);
    expect(primaryButton(tester).onPressed, isNull);
  });

  testWidgets('the confirmation says the originals are replaced for good',
      (tester) async {
    // The cleaner can promise an undo because it moves files into a quarantine.
    // This one cannot, and the dialog is where that is said.
    findsVideos();
    await pump(tester);
    await scan(tester);

    await tester.tap(find.text('Save 500 MB'));
    await tester.pumpAndSettle();

    expect(find.text('Free about 500 MB?'), findsOneWidget);
    expect(find.textContaining('there is no way back'), findsOneWidget);
  });

  testWidgets('cancelling the dialog changes nothing', (tester) async {
    findsVideos();
    await pump(tester);
    await scan(tester);

    await tester.tap(find.text('Save 500 MB'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(optimizeRepo.lastCandidates, isNull);
  });

  testWidgets('confirming reports what the run really did', (tester) async {
    optimizeRepo.report = OptimizeReport(
      freedBytes: 500 * AppByteUnits.megabyte,
      optimizedCount: 1,
      skippedCount: 2,
      failedCount: 1,
    );

    findsVideos();
    await pump(tester);
    await scan(tester);

    await tester.tap(find.text('Save 500 MB'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Re-encode'));
    await tester.pumpAndSettle();

    // The measured figure, not the estimate it was sold on.
    expect(find.text('500 MB freed'), findsOneWidget);
    expect(find.text('1 file re-encoded'), findsOneWidget);
    // And the parts that are not good news, each on its own line.
    expect(
      find.textContaining('2 left as they were'),
      findsOneWidget,
    );
    expect(
      find.textContaining('1 could not be re-encoded'),
      findsOneWidget,
    );
  });

  testWidgets('a machine with no video encoder says so and offers no button',
      (tester) async {
    // Silently omitting these would report a device with nothing to optimise,
    // which is the same lie as a cleaner reporting an empty sandbox as clean.
    optimizeRepo.encoderSupport =
        const EncoderSupport(photos: true, videos: false);
    findsVideos();

    await pump(tester);
    await scan(tester);

    expect(find.text('Some of these cannot be re-encoded here'), findsOneWidget);
    expect(find.textContaining('FFmpeg'), findsOneWidget);
    expect(primaryButton(tester).onPressed, isNull);
  });

  testWidgets('a narrowed Android offers the permission, not a bare refusal',
      (tester) async {
    accessRepo.access = const StorageAccess(
      level: StorageAccessLevel.appOnly,
      canRequestMore: true,
      canAddFolder: true,
    );

    await pump(tester);

    expect(find.text('Grant access'), findsOneWidget);
    // Nothing to scan until it is widened: an app's own container holds no
    // photographs the user took.
    expect(primaryButton(tester).onPressed, isNull);
  });

  testWidgets('a permanent refusal on Android says so and offers settings',
      (tester) async {
    accessRepo.access = const StorageAccess(
      level: StorageAccessLevel.appOnly,
      canAddFolder: true,
      isPermanentlyDenied: true,
    );

    await pump(tester);

    expect(find.text('Access refused for good'), findsOneWidget);
    expect(find.text('Grant access'), findsNothing);

    await tester.tap(find.text('Open settings'));
    await tester.pump();

    expect(accessRepo.openSettingsCount, 1);
  });

  testWidgets('a platform with no reachable media explains itself',
      (tester) async {
    scanRepo.isSupported = false;
    optimizeRepo.isSupported = false;

    await pump(tester);

    expect(find.text('Not on this platform'), findsOneWidget);
  });

  testWidgets('a narrow phone in every locale keeps its titles readable',
      (tester) async {
    // The layout trap `JunkCategoryTile` documents: an unshrinkable figure on a
    // line with flexible text takes the text's width first, and nothing reports
    // an overflow when the text ends up with none.
    findsVideos();

    for (final (Locale locale, String title) in <(Locale, String)>[
      (const Locale('en'), 'Videos'),
      (const Locale('ru'), 'Видео'),
      (const Locale('zh'), '视频'),
    ]) {
      await pump(tester, surface: narrow, locale: locale);
      await tester.tap(find.byType(AppPrimaryButton));
      await tester.pumpAndSettle();

      // Two lines of `titleMedium`, which lays out at 24 under the test font.
      // A title drawn one letter per row would be several hundred.
      expect(
        tester.getSize(find.text(title)).height,
        lessThan(2 * 24.0 + 2),
        reason: locale.languageCode,
      );
      expect(tester.takeException(), isNull, reason: locale.languageCode);

      // `pumpWidget` reuses the element tree, so the bloc survives the turn of
      // the loop with its findings in it: the first pass taps a scan button and
      // the ones after it tap "Save 500 MB", which opens the confirmation. Left
      // open, that dialog covers the next locale's screen and swallows its tap,
      // and the iteration then asserts against a screen nothing was done to.
      if (find.byType(AlertDialog).evaluate().isNotEmpty) {
        tester.state<NavigatorState>(find.byType(Navigator).last).pop();
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets('the title scrolls with the list and the button does not',
      (tester) async {
    // The screen used to pin its title above a list of its own, which on a
    // phone left about two collapsed tiles of scrolling room and clipped the
    // rest flush against the header. The button is the deliberate exception.
    findsVideos();

    await pump(tester, surface: short);
    await scan(tester);

    const String title = 'Make files smaller';
    final double titleBefore = tester.getTopLeft(find.text(title)).dy;
    final double buttonBefore =
        tester.getTopLeft(find.byType(AppPrimaryButton)).dy;

    await tester.drag(find.byType(ListView), const Offset(0, -160));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text(title)).dy,
      lessThan(titleBefore),
      reason: 'the header should scroll away with the list',
    );
    expect(
      tester.getTopLeft(find.byType(AppPrimaryButton)).dy,
      buttonBefore,
      reason: 'the primary action should stay where it is',
    );
  });
}
