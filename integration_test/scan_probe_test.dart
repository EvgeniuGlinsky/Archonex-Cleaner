import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:storage_cleaner/core/app/storage_cleaner_app.dart';
import 'package:storage_cleaner/core/constants/app_durations.dart';
import 'package:storage_cleaner/core/utils/file_size_formatter.dart';
import 'package:storage_cleaner/project_files/features/device_storage/data/file_system/unsupported_device_storage_repo.dart';
import 'package:storage_cleaner/project_files/features/device_storage/data/platform/device_storage_platform.dart';
import 'package:storage_cleaner/project_files/features/device_storage/domain/device_storage_repo.dart';
import 'package:storage_cleaner/project_files/features/device_storage/domain/models/device_storage_snapshot.dart';
import 'package:storage_cleaner/project_files/features/home/domain/models/app_tool.dart';
import 'package:storage_cleaner/project_files/features/home/ui/widgets/app_tool_card.dart';
import 'package:storage_cleaner/project_files/features/language_selection/data/prefs_language_storage.dart';
import 'package:storage_cleaner/project_files/features/language_selection/domain/models/app_language.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';
import 'package:storage_cleaner/project_files/features/storage_access/ui/widgets/storage_access_notice.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/file_system/cleaner_roots_resolver.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/file_system/io_junk_scan_repo.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/rules/cleaner_roots.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/rules/junk_rule.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/rules/junk_ruleset.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/rules/protected_paths.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/junk_category.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/junk_item.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/scan_job.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/scan_update.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/ui/storage_cleaner_view.dart';

/// Runs the app against the real machine, and **deletes nothing**.
///
/// The unit tests answer whether the rules are right about every platform. They
/// cannot answer the other half — the questions only a device can be asked, and
/// every one of them fails *quietly* in `test/`:
///
/// - whether the paths the rules name exist here, and whether the walk finishes
///   in a sensible time on a real disk with a real `%TEMP%` in it;
/// - whether `disk_space_2` has a side for this platform, which a `null`
///   snapshot cannot be told apart from by design;
/// - whether the system hands over a locale list at all — it is empty under
///   `flutter test`, so an app that read it wrongly would still open in English
///   on a Russian phone and pass everything;
/// - whether `shared_preferences` is registered, which a storage that swallows
///   its own failures makes look exactly like a first run, for ever.
///
/// That is why this is separate from `test/` and out of CI.
///
/// ```bash
/// flutter test integration_test/scan_probe_test.dart -d windows
/// flutter test integration_test/scan_probe_test.dart -d <android-device-id>
/// ```
///
/// It asserts nothing about how much it found — a tidy machine legitimately
/// finds nothing — and everything about the invariants that must hold whatever
/// it found. Read the printed report; that is the point of running it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the real app starts and reaches the cleaner', (tester) async {
    // The one thing no widget test can check: the wiring in `storage_cleaner_app.dart`
    // with the *real* repositories behind it. `IoQuarantineRepo` reaches
    // `path_provider`, which has no platform to answer it under `flutter test`,
    // so a broken app root would pass every test in `test/` and crash on launch.
    await tester.pumpWidget(const StorageCleanerApp());

    // The splash beat, plus the expiry sweep and the language read it runs
    // alongside.
    await tester.pump(AppDurations.splash + const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // By widget rather than by text, all the way down: the app now opens in
    // whatever language the machine is set to, so every string on screen depends
    // on the runner. That is the behaviour under test, not an obstacle to it.
    expect(find.byType(AppToolCard), findsNWidgets(AppTool.values.length));

    await tester.tap(find.byType(AppToolCard).first);
    await tester.pumpAndSettle();

    expect(find.byType(StorageCleanerView), findsOneWidget);

    // On a desktop the app can already see everything, so no access notice.
    expect(find.byType(StorageAccessNotice), findsNothing);
  });

  testWidgets('the app opens in the language the machine is set to',
      (tester) async {
    // The unit tests answer whether the *rule* is right, against a locale list
    // handed in by the test. They cannot answer whether the platform hands one
    // over at all: `PlatformDispatcher.instance.locales` is empty under
    // `flutter test`, so an app that read it wrongly would still pass every one
    // of them and open in English on a Russian phone.
    debugPrint('--- locales on $defaultTargetPlatform ---');
    debugPrint('system   ${PlatformDispatcher.instance.locales}');

    await tester.pumpWidget(const StorageCleanerApp());
    await tester.pump(AppDurations.splash + const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final Locale shown = Localizations.localeOf(
      tester.element(find.byType(AppToolCard).first),
    );

    debugPrint('app      $shown');

    // Over the *locales*, in the order the user ranked them — not over the
    // languages. A machine listing Russian first and English fourth reads
    // Russian, and iterating `AppLanguage.values` instead would find English
    // and call it right.
    final AppLanguage expected = PlatformDispatcher.instance.locales
            .map(
              (locale) => AppLanguage.values
                  .where((language) => language.code == locale.languageCode)
                  .firstOrNull,
            )
            .nonNulls
            .firstOrNull ??
        AppLanguage.english;

    expect(shown.languageCode, expected.code);
  });

  testWidgets('a language chosen by hand survives on this platform',
      (tester) async {
    // `PrefsLanguageStorage` swallows a store that will not answer, on purpose:
    // a broken preference store must cost the user their choice and not their
    // launch. The price is that a plugin which is not registered at all looks
    // exactly like a first run, for ever, and every unit test still passes.
    //
    // Its own `SharedPreferencesAsync` so the key can be removed afterwards —
    // the probe must not leave the real app pinned to a language.
    final SharedPreferencesAsync prefs = SharedPreferencesAsync();
    final PrefsLanguageStorage storage = PrefsLanguageStorage(prefs);
    final AppLanguage? before = await storage.read();

    addTearDown(() async {
      if (before == null) {
        await prefs.remove('language.code');

        return;
      }

      await storage.write(before);
    });

    await storage.write(AppLanguage.chinese);

    debugPrint('--- language store on $defaultTargetPlatform ---');
    debugPrint('before   $before');
    debugPrint('read     ${await storage.read()}');

    expect(
      await storage.read(),
      AppLanguage.chinese,
      reason: 'the preference store did not keep the choice — the app will '
          'open in the device language again on the next launch',
    );
  });

  testWidgets('the disk reader answers on this platform', (tester) async {
    // `disk_space_2` is a method channel with no macOS or web side, and
    // `PluginDeviceStorageRepo` turns a missing channel into `null` rather than
    // a crash — which means a plugin that silently stopped answering on Windows
    // or Android would look exactly like a tidy `null` in every unit test. Only
    // a device can tell the two apart.
    final DeviceStorageRepo repo = createDeviceStorageRepo();
    final DeviceStorageSnapshot? snapshot = await repo.read();

    debugPrint('--- disk on $defaultTargetPlatform ---');
    debugPrint('reader   ${repo.runtimeType}');

    if (snapshot == null) {
      debugPrint('no answer — the ring is not drawn on this platform');

      expect(
        repo,
        isA<UnsupportedDeviceStorageRepo>(),
        reason: 'the plugin platform answered nothing where it should answer',
      );

      return;
    }

    debugPrint('total    ${FileSizeFormatter.format(snapshot.totalBytes)}');
    debugPrint('free     ${FileSizeFormatter.format(snapshot.freeBytes)}');
    debugPrint('used     ${FileSizeFormatter.format(snapshot.usedBytes)}'
        ' (${(snapshot.usedFraction * 100).round()}%)');

    // Compare the printed figures against the operating system's own. The
    // assertions below only cover what cannot be true of any real volume.
    expect(snapshot.totalBytes, greaterThan(0));
    expect(snapshot.freeBytes, lessThanOrEqualTo(snapshot.totalBytes));
    expect(snapshot.usedFraction, inInclusiveRange(0, 1));
  });

  testWidgets('the real rules point at directories that exist', (tester) async {
    final CleanerRoots roots =
        await const CleanerRootsResolver().resolve(const StorageAccess.open());
    final List<JunkRule> rules = JunkRuleset.of(
      platform: defaultTargetPlatform,
      roots: roots,
      access: const StorageAccess.open(),
    );

    debugPrint('--- rules on $defaultTargetPlatform ---');
    for (final JunkRule rule in rules) {
      debugPrint('${rule.category.name.padRight(20)} ${rule.label} → ${rule.root}');
    }

    expect(
      rules,
      isNotEmpty,
      reason: 'no rule resolved — every root was null',
    );
  });

  testWidgets('a real scan finishes, and everything it found is deletable',
      (tester) async {
    final CleanerRoots roots =
        await const CleanerRootsResolver().resolve(const StorageAccess.open());
    final ProtectedPaths guard =
        ProtectedPaths.of(defaultTargetPlatform, roots);

    final IoJunkScanRepo repo = IoJunkScanRepo();
    final Set<JunkCategory> categories =
        await repo.categoriesFor(const StorageAccess.open());

    final Stopwatch stopwatch = Stopwatch()..start();
    final ScanJob job = await repo.scan(
      categories: categories,
      access: const StorageAccess.open(),
    );

    final Map<JunkCategory, int> bytes = <JunkCategory, int>{};
    final Map<JunkCategory, int> counts = <JunkCategory, int>{};
    final List<JunkItem> everything = <JunkItem>[];

    await for (final ScanUpdate update in job.updates) {
      if (update is JunkFound) {
        for (final JunkItem item in update.items) {
          everything.add(item);
          bytes[item.category] = (bytes[item.category] ?? 0) + item.sizeInBytes;
          counts[item.category] = (counts[item.category] ?? 0) + 1;
        }
      }
    }

    stopwatch.stop();

    debugPrint('--- scan finished in ${stopwatch.elapsed.inSeconds}s ---');
    for (final JunkCategory category in JunkCategory.values) {
      if (counts.containsKey(category)) {
        debugPrint(
          '${category.name.padRight(20)} '
          '${FileSizeFormatter.format(bytes[category]!).padLeft(10)} '
          'in ${counts[category]} items',
        );
      }
    }
    debugPrint(
      'total ${FileSizeFormatter.format(bytes.values.fold(0, (a, b) => a + b))} '
      'in ${everything.length} items',
    );

    // The invariants, which must hold whatever the machine happened to contain.
    for (final JunkItem item in everything) {
      expect(
        guard.contains(item.path),
        isFalse,
        reason: 'the walk offered a protected path: ${item.path}',
      );
      expect(
        categories,
        contains(item.category),
        reason: '${item.path} came back in a category nothing asked for',
      );
    }

    expect(
      everything.map((item) => item.path).toSet().length,
      everything.length,
      reason: 'the same path was reported twice',
    );
  });

  testWidgets('cancelling a real scan stops it', (tester) async {
    final IoJunkScanRepo repo = IoJunkScanRepo();
    final ScanJob job = await repo.scan(
      categories: await repo.categoriesFor(const StorageAccess.open()),
      access: const StorageAccess.open(),
    );

    Object? error;
    int batches = 0;

    await job.updates.listen(
      (update) {
        if (update is JunkFound && ++batches == 1) {
          job.cancel();
        }
      },
      onError: (Object failure) => error = failure,
      cancelOnError: false,
    ).asFuture<void>().catchError((Object failure) => error = failure);

    // A cancellation, and only a cancellation, ends a scan's stream with an
    // error — see `ScanJob`.
    debugPrint('cancelled after $batches batches, ended with $error');
  });
}
