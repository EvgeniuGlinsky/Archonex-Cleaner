import 'package:path/path.dart' as p;

import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/rules/cleaner_roots.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/rules/junk_rule.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_category.dart';

/// Where the two Apple platforms leave things, and why they get different
/// answers from one file.
///
/// They share a directory layout and nothing else that matters here. macOS, in
/// the unsandboxed build this project ships, sees the user's whole home; iOS
/// sees its own container and will never see anything else, because no
/// permission exists that would let it. The two lists are therefore the same
/// shape and radically different lengths, which is the honest outcome rather
/// than a shortcoming of this table.
class AppleJunkRules {
  const AppleJunkRules._();

  static const Duration _browserCacheAge = Duration(days: 1);
  static const Duration _logAge = Duration(days: 7);

  /// iOS: the sandbox, and that is the entire list.
  ///
  /// Two rows, both inside the app's own container. Everything a phone cleaner
  /// advertises on iOS is either this or a lie; there is no API that reaches
  /// another app's data, and there is no permission to ask for.
  static List<JunkRule> iOS(CleanerRoots roots) {
    return <JunkRule>[
      JunkRule(
        root: roots.appCache,
        category: JunkCategory.appCache,
        label: 'Archonex Cleaner',
      ),
      JunkRule(
        root: roots.appCache,
        category: JunkCategory.emptyFolders,
        label: 'Archonex Cleaner',
        mode: JunkRuleMode.emptyDirectories,
      ),
    ];
  }

  /// macOS, unsandboxed — see `Release.entitlements`.
  static List<JunkRule> macOS(CleanerRoots roots) {
    final String? home = roots.home;
    final String? temp = roots.systemTemp;

    return <JunkRule>[
      // No `appCache` rule — see `WindowsJunkRules.of`. Unsandboxed,
      // `NSTemporaryDirectory()` is a per-session directory under
      // `/var/folders` shared by every process in the session, so it is
      // `$TMPDIR` and belongs under `systemTemp`. A sandboxed build would be the
      // opposite, and would use `AppleJunkRules.iOS`.
      if (temp != null)
        // `$TMPDIR`, which on macOS is a per-session directory under
        // `/var/folders`. Inside the protected `/var`, and named explicitly
        // here for the same reason `C:\Windows\Temp` is on Windows: the guard
        // covers the tree, the rule covers the one directory in it that is
        // meant to be emptied.
        JunkRule(
          root: temp,
          category: JunkCategory.systemTemp,
          label: r'$TMPDIR',
        ),

      if (home != null) ...<JunkRule>[
        // `~/Library/Caches` is Apple's own answer to "where do I put things I
        // can rebuild". `~/Library/Application Support` next door is protected,
        // and the difference between the two is the whole point.
        JunkRule(
          root: p.posix.join(home, 'Library', 'Caches'),
          category: JunkCategory.systemTemp,
          label: '~/Library/Caches',
        ),
        JunkRule(
          root: p.posix.join(home, 'Library', 'Caches', 'Google', 'Chrome'),
          category: JunkCategory.browserCache,
          label: 'Chrome cache',
          minimumAge: _browserCacheAge,
        ),
        JunkRule(
          root: p.posix.join(home, 'Library', 'Caches', 'Firefox'),
          category: JunkCategory.browserCache,
          label: 'Firefox cache',
          minimumAge: _browserCacheAge,
        ),
        JunkRule(
          root: p.posix.join(home, 'Library', 'Logs'),
          category: JunkCategory.logs,
          label: '~/Library/Logs',
          mode: JunkRuleMode.files,
          extensions: <String>{'log', 'crash'},
          minimumAge: _logAge,
        ),
        JunkRule(
          root: p.posix.join(
            home,
            'Library',
            'Logs',
            'DiagnosticReports',
          ),
          category: JunkCategory.crashDumps,
          label: 'Diagnostic reports',
        ),
        JunkRule(
          root: p.posix.join(home, '.Trash'),
          category: JunkCategory.trash,
          label: 'Trash',
        ),
        JunkRule(
          root: p.posix.join(home, 'Downloads'),
          category: JunkCategory.installerLeftovers,
          label: '~/Downloads',
          mode: JunkRuleMode.files,
          extensions: <String>{'dmg', 'pkg'},
          minimumAge: Duration(days: 30),
          maxDepth: 1,
        ),
      ],
    ];
  }
}
