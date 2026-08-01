import 'package:path/path.dart' as p;

import 'package:storage_cleaner/project_files/features/storage_cleaner/data/rules/cleaner_roots.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/rules/junk_rule.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/junk_category.dart';

/// Where Windows leaves things.
///
/// The richest of the four tables, because Windows is the platform that both
/// generates the most junk and lets an ordinary process see it. A row here is a
/// claim that the directory is regenerable; where that is only true under
/// conditions, the conditions are in the comment above the row.
class WindowsJunkRules {
  const WindowsJunkRules._();

  /// A browser rewrites its cache constantly, so the one-hour floor would offer
  /// files the browser is still using. A day is past every open session.
  static const Duration _browserCacheAge = Duration(days: 1);

  /// A log is worth keeping while somebody might still be diagnosing yesterday.
  static const Duration _logAge = Duration(days: 7);

  static List<JunkRule> of(CleanerRoots roots) {
    final String? temp = roots.systemTemp;
    final String? local = roots.localAppData;
    final String? windows = roots.windowsDirectory;

    return <JunkRule>[
      // No `appCache` rule, and that is deliberate. `getTemporaryDirectory()` on
      // Windows answers `GetTempPath()`, which is `%TEMP%` itself — not a
      // subdirectory of it — so a rule for "this app's cache" here would be the
      // system temp folder wearing the wrong label. The probe caught exactly
      // that: 696 MB of other applications' leftovers filed under this app's
      // own name. The `systemTemp` rules below cover the same bytes
      // and describe them honestly. Only Android and iOS have a cache directory
      // that is genuinely this app's.
      if (temp != null) ...<JunkRule>[
        JunkRule(
          root: temp,
          category: JunkCategory.systemTemp,
          label: '%TEMP%',
        ),
        JunkRule(
          root: temp,
          category: JunkCategory.emptyFolders,
          label: '%TEMP%',
          mode: JunkRuleMode.emptyDirectories,
        ),
      ],

      if (windows != null)
        // `C:\Windows\Temp` is inside the Windows directory and deliberately
        // not inside `ProtectedPaths`, which names the seven subdirectories
        // that are. Writable by an ordinary user, and full of installer
        // leftovers on any machine older than a month.
        JunkRule(
          root: p.windows.join(windows, 'Temp'),
          category: JunkCategory.systemTemp,
          label: r'C:\Windows\Temp',
        ),

      if (local != null) ...<JunkRule>[
        JunkRule(
          root: p.windows.join(local, 'Temp'),
          category: JunkCategory.systemTemp,
          label: 'Local AppData Temp',
        ),

        // Explorer's icon and thumbnail database. Rebuilt on demand, and the
        // single largest thing in `Explorer` on a machine with many photos.
        JunkRule(
          root: p.windows.join(local, 'Microsoft', 'Windows', 'Explorer'),
          category: JunkCategory.thumbnails,
          label: 'Explorer thumbnails',
          mode: JunkRuleMode.files,
          namePrefixes: <String>{'thumbcache_', 'iconcache_'},
        ),

        JunkRule(
          root: p.windows.join(
            local,
            'Microsoft',
            'Windows',
            'INetCache',
          ),
          category: JunkCategory.browserCache,
          label: 'Internet cache',
          minimumAge: _browserCacheAge,
        ),
        JunkRule(
          root: p.windows.join(
            local,
            'Google',
            'Chrome',
            'User Data',
            'Default',
            'Cache',
          ),
          category: JunkCategory.browserCache,
          label: 'Chrome cache',
          minimumAge: _browserCacheAge,
        ),
        JunkRule(
          root: p.windows.join(
            local,
            'Microsoft',
            'Edge',
            'User Data',
            'Default',
            'Cache',
          ),
          category: JunkCategory.browserCache,
          label: 'Edge cache',
          minimumAge: _browserCacheAge,
        ),
        JunkRule(
          root: p.windows.join(local, 'Mozilla', 'Firefox', 'Profiles'),
          category: JunkCategory.browserCache,
          label: 'Firefox cache',
          mode: JunkRuleMode.directories,
          directoryNames: <String>{'cache2', 'startupcache'},
          minimumAge: _browserCacheAge,
        ),

        JunkRule(
          root: p.windows.join(local, 'CrashDumps'),
          category: JunkCategory.crashDumps,
          label: 'Crash dumps',
        ),
        JunkRule(
          root: p.windows.join(local, 'Microsoft', 'Windows', 'WER'),
          category: JunkCategory.crashDumps,
          label: 'Windows Error Reporting',
        ),

        JunkRule(
          root: local,
          category: JunkCategory.logs,
          label: 'Application logs',
          mode: JunkRuleMode.files,
          extensions: <String>{'log', 'log1', 'log2', 'etl', 'dmp'},
          minimumAge: _logAge,
          // Two levels: an application's own log directory, and no deeper. A
          // full walk of Local AppData is a minute of disk on a laptop and
          // turns up the same files.
          maxDepth: 3,
        ),
      ],

      if (roots.home != null)
        JunkRule(
          root: p.windows.join(roots.home!, 'Downloads'),
          category: JunkCategory.installerLeftovers,
          label: 'Downloads',
          mode: JunkRuleMode.files,
          extensions: <String>{'msi', 'exe', 'msu', 'cab'},
          // Untouched for a month. A setup file downloaded this week is very
          // possibly about to be run.
          minimumAge: Duration(days: 30),
          maxDepth: 1,
        ),

      // The recycle bin. Deliberately the only row with no age floor of its
      // own beyond the default: everything in it was deleted on purpose, so
      // "how old is it" is not the question — "did you mean it twice" is, and
      // the category answers that by being unticked.
      JunkRule(
        root: r'C:\$Recycle.Bin',
        category: JunkCategory.trash,
        label: 'Recycle Bin',
      ),

      // Not scanned. Both are genuinely reclaimable and both need elevation,
      // and an app that asks for administrator rights to delete a file is an
      // app people uninstall. Kept as rows so the next person to wonder finds
      // the answer here instead of adding them.
      if (windows != null) ...<JunkRule>[
        JunkRule(
          root: p.windows.join(windows, 'SoftwareDistribution', 'Download'),
          category: JunkCategory.systemTemp,
          label: 'Windows Update cache',
          needsElevation: true,
        ),
        JunkRule(
          root: p.windows.join(windows, 'Prefetch'),
          category: JunkCategory.systemTemp,
          label: 'Prefetch',
          needsElevation: true,
        ),
      ],
    ];
  }
}
