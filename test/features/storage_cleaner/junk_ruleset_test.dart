import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:storage_cleaner/core/constants/app_clean_policy.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/rules/cleaner_roots.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/rules/junk_rule.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/rules/junk_ruleset.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/rules/protected_paths.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/junk_category.dart';

void main() {
  const CleanerRoots windowsRoots = CleanerRoots(
    appCache: r'C:\Users\tester\AppData\Local\Temp\storage_cleaner',
    appSupport: r'C:\Users\tester\AppData\Roaming\io.github.evgeniuglinsky.storagecleaner',
    home: r'C:\Users\tester',
    systemTemp: r'C:\Users\tester\AppData\Local\Temp',
    localAppData: r'C:\Users\tester\AppData\Local',
    windowsDirectory: r'C:\Windows',
  );

  const CleanerRoots posixRoots = CleanerRoots(
    appCache: '/home/tester/.cache/storage_cleaner',
    appSupport: '/home/tester/.local/share/storage_cleaner',
    home: '/home/tester',
    systemTemp: '/tmp',
  );

  const CleanerRoots androidRoots = CleanerRoots(
    appCache: '/data/user/0/io.github.evgeniuglinsky.storagecleaner/cache',
    appSupport: '/data/user/0/io.github.evgeniuglinsky.storagecleaner/files',
    externalAppCaches: <String>['/storage/emulated/0/Android/data/x/cache'],
    externalStorage: '/storage/emulated/0',
  );

  List<JunkRule> rulesFor(
    TargetPlatform platform,
    CleanerRoots roots, {
    StorageAccess access = const StorageAccess.open(),
  }) =>
      JunkRuleset.of(platform: platform, roots: roots, access: access);

  group('every platform', () {
    final Map<TargetPlatform, CleanerRoots> cases =
        <TargetPlatform, CleanerRoots>{
      TargetPlatform.windows: windowsRoots,
      TargetPlatform.linux: posixRoots,
      TargetPlatform.macOS: posixRoots,
      TargetPlatform.iOS: androidRoots,
      TargetPlatform.android: androidRoots,
    };

    cases.forEach((platform, roots) {
      test('$platform offers something to clean', () {
        expect(rulesFor(platform, roots), isNotEmpty);
      });

      test('$platform claims an app cache only where one really exists', () {
        // `getTemporaryDirectory()` is app-specific on Android and iOS, and the
        // shared system temp on all three desktops. A desktop `appCache` row
        // would be `%TEMP%` filed under this app's name — which the Windows
        // probe caught, at 696 MB of other applications' leftovers.
        final bool claimsAppCache = rulesFor(platform, roots)
            .any((rule) => rule.category == JunkCategory.appCache);

        expect(
          claimsAppCache,
          platform == TargetPlatform.android || platform == TargetPlatform.iOS,
          reason: '$platform got the app-cache question wrong',
        );
      });

      test('$platform never scans a root the guard would refuse whole', () {
        final ProtectedPaths guard = ProtectedPaths.of(platform, roots);

        for (final JunkRule rule in rulesFor(platform, roots)) {
          expect(
            guard.contains(rule.root),
            isFalse,
            reason: '${rule.label} is rooted at a protected path: ${rule.root}',
          );
        }
      });

      test('$platform has no unfiltered deep-walking rule', () {
        // An unfiltered `files` rule takes every file under its root at any
        // depth, and no root in any table is disposable that far down. See
        // `JunkRule.matchesFile`.
        for (final JunkRule rule in rulesFor(platform, roots)) {
          if (rule.mode != JunkRuleMode.files) {
            continue;
          }

          expect(
            rule.extensions.isNotEmpty || rule.namePrefixes.isNotEmpty,
            isTrue,
            reason: '${rule.label} walks deep and matches everything',
          );
        }
      });

      test('$platform never asks for a shorter age floor than the policy', () {
        for (final JunkRule rule in rulesFor(platform, roots)) {
          expect(
            rule.minimumAge >= AppCleanPolicy.minimumAge,
            isTrue,
            reason: '${rule.label} would offer a file still in use',
          );
        }
      });

      test('$platform runs nothing that needs elevation', () {
        expect(
          rulesFor(platform, roots).where((rule) => rule.needsElevation),
          isEmpty,
        );
      });
    });
  });

  group('Windows', () {
    test('empties the two Temp directories without deleting them', () {
      final Iterable<String> roots = rulesFor(TargetPlatform.windows, windowsRoots)
          .where((rule) => rule.category == JunkCategory.systemTemp)
          .map((rule) => rule.root);

      expect(roots, contains(r'C:\Windows\Temp'));
      expect(roots, contains(windowsRoots.systemTemp));
    });

    test('the Windows Update and Prefetch rows exist but never run', () {
      // They are in the table so the next person to wonder finds the reason
      // rather than adding them — and out of every scan, because an app that
      // asks for administrator rights to delete a file gets uninstalled.
      final List<JunkRule> declared = JunkRuleset.declaredFor(
        platform: TargetPlatform.windows,
        roots: windowsRoots,
        access: const StorageAccess.open(),
      );

      expect(
        declared.where((rule) => rule.needsElevation).map((rule) => rule.label),
        containsAll(<String>['Windows Update cache', 'Prefetch']),
      );
      expect(
        rulesFor(TargetPlatform.windows, windowsRoots).map((rule) => rule.label),
        isNot(contains('Prefetch')),
      );
    });
  });

  group('Android', () {
    test('all-files access unlocks shared storage', () {
      final Set<JunkCategory> full = JunkRuleset.categoriesFor(
        platform: TargetPlatform.android,
        roots: androidRoots,
        access: const StorageAccess(level: StorageAccessLevel.full),
      );

      expect(full, contains(JunkCategory.thumbnails));
      expect(full, contains(JunkCategory.installerLeftovers));
    });

    test('without it, only the app-owned caches are reachable', () {
      final Set<JunkCategory> narrowed = JunkRuleset.categoriesFor(
        platform: TargetPlatform.android,
        roots: androidRoots,
        access: const StorageAccess(
          level: StorageAccessLevel.appOnly,
          canRequestMore: true,
          canAddFolder: true,
        ),
      );

      expect(narrowed, <JunkCategory>{JunkCategory.appCache});
    });

    test('a picked folder is scanned, and only for temporary extensions', () {
      final List<JunkRule> rules = rulesFor(
        TargetPlatform.android,
        androidRoots,
        access: const StorageAccess(
          level: StorageAccessLevel.scopedFolders,
          grantedRoots: <String>['/storage/emulated/0/Books'],
          canAddFolder: true,
        ),
      );

      final JunkRule picked =
          rules.firstWhere((rule) => rule.root == '/storage/emulated/0/Books');

      expect(picked.mode, JunkRuleMode.files);
      expect(picked.extensions, contains('tmp'));
    });

    test("names no other app's cache, because none is readable", () {
      for (final JunkRule rule in rulesFor(
        TargetPlatform.android,
        androidRoots,
        access: const StorageAccess(level: StorageAccessLevel.full),
      )) {
        final bool isOurs = rule.root.startsWith(androidRoots.appCache) ||
            androidRoots.externalAppCaches.contains(rule.root);

        expect(
          rule.root.contains('/Android/data/') && !isOurs,
          isFalse,
          reason: '${rule.label} points at another app: ${rule.root}',
        );
      }
    });
  });

  group('iOS', () {
    test('sees the sandbox and nothing else', () {
      expect(
        JunkRuleset.categoriesFor(
          platform: TargetPlatform.iOS,
          roots: androidRoots,
          access: const StorageAccess.sandboxed(),
        ),
        <JunkCategory>{JunkCategory.appCache, JunkCategory.emptyFolders},
      );
    });
  });

  group('categoriesFor', () {
    test('returns categories in the enum declaration order', () {
      final List<JunkCategory> ordered = JunkRuleset.categoriesFor(
        platform: TargetPlatform.windows,
        roots: windowsRoots,
        access: const StorageAccess.open(),
      ).toList();

      final List<JunkCategory> expected = JunkCategory.values
          .where(ordered.contains)
          .toList(growable: false);

      expect(ordered, expected);
    });
  });
}
