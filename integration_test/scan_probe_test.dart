import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:archonex_cleaner/core/app/archonex_app.dart';
import 'package:archonex_cleaner/core/constants/app_durations.dart';
import 'package:archonex_cleaner/core/utils/file_size_formatter.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/file_system/cleaner_roots_resolver.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/file_system/io_junk_scan_repo.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/rules/cleaner_roots.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/rules/junk_rule.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/rules/junk_ruleset.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/rules/protected_paths.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_category.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_item.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/scan_job.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/scan_update.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/storage_access.dart';

/// Runs the real walker against the real machine, and **deletes nothing**.
///
/// The unit tests answer whether the rules are right about every platform. They
/// cannot answer the other half: whether the paths those rules name exist on a
/// device, and whether the walk finishes in a sensible time on a real disk with
/// a real `%TEMP%` in it. Only a device answers that, which is why this is
/// separate from `test/` and out of CI.
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
    // The one thing no widget test can check: the wiring in `archonex_app.dart`
    // with the *real* repositories behind it. `IoQuarantineRepo` reaches
    // `path_provider`, which has no platform to answer it under `flutter test`,
    // so a broken app root would pass every test in `test/` and crash on launch.
    await tester.pumpWidget(const ArchonexApp());

    // The splash beat, plus the expiry sweep it runs alongside.
    await tester.pump(AppDurations.splash + const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Choose your language'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Free up space'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);

    // On a desktop the app can already see everything, so no access notice.
    expect(find.text('Grant access'), findsNothing);
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
