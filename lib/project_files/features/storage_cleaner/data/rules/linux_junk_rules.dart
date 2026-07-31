import 'package:path/path.dart' as p;

import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/rules/cleaner_roots.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/rules/junk_rule.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_category.dart';

/// Where Linux leaves things.
///
/// Shorter than the Windows table and not because Linux is tidier: almost
/// everything reclaimable on a Linux box belongs to the package manager, and
/// `apt clean` needs root. What is left is the XDG cache directory, which is
/// specified as disposable — that specification is the whole basis for this
/// table.
///
/// `/var/tmp` is deliberately absent. It is defined as surviving a reboot,
/// which is precisely what the things in it are counting on, and it is inside
/// the protected `/var` for the same reason.
class LinuxJunkRules {
  const LinuxJunkRules._();

  static const Duration _browserCacheAge = Duration(days: 1);
  static const Duration _logAge = Duration(days: 7);

  static List<JunkRule> of(CleanerRoots roots) {
    final String? home = roots.home;
    final String? temp = roots.systemTemp;

    return <JunkRule>[
      // No `appCache` rule — see `WindowsJunkRules.of`. `getTemporaryDirectory()`
      // is `/tmp` here, shared with every other process, so the `systemTemp`
      // rules below are the honest description of the same bytes.
      if (temp != null) ...<JunkRule>[
        JunkRule(
          root: temp,
          category: JunkCategory.systemTemp,
          label: '/tmp',
        ),
        JunkRule(
          root: temp,
          category: JunkCategory.emptyFolders,
          label: '/tmp',
          mode: JunkRuleMode.emptyDirectories,
        ),
      ],

      if (home != null) ...<JunkRule>[
        // `~/.cache` is XDG's directory for data that can be regenerated. The
        // browser subdirectories are named separately below so they land in the
        // category the user can untick, and the walk here skips nothing: a
        // finding matched by two rules is kept once, by the first.
        JunkRule(
          root: p.posix.join(home, '.cache'),
          category: JunkCategory.systemTemp,
          label: '~/.cache',
        ),
        JunkRule(
          root: p.posix.join(home, '.cache', 'thumbnails'),
          category: JunkCategory.thumbnails,
          label: '~/.cache/thumbnails',
        ),
        JunkRule(
          root: p.posix.join(home, '.thumbnails'),
          category: JunkCategory.thumbnails,
          label: '~/.thumbnails',
        ),

        JunkRule(
          root: p.posix.join(home, '.cache', 'google-chrome'),
          category: JunkCategory.browserCache,
          label: 'Chrome cache',
          minimumAge: _browserCacheAge,
        ),
        JunkRule(
          root: p.posix.join(home, '.cache', 'chromium'),
          category: JunkCategory.browserCache,
          label: 'Chromium cache',
          minimumAge: _browserCacheAge,
        ),
        JunkRule(
          root: p.posix.join(home, '.cache', 'mozilla'),
          category: JunkCategory.browserCache,
          label: 'Firefox cache',
          minimumAge: _browserCacheAge,
        ),

        JunkRule(
          root: p.posix.join(home, '.local', 'share', 'Trash'),
          category: JunkCategory.trash,
          label: 'Trash',
        ),

        JunkRule(
          root: p.posix.join(home, '.local', 'share', 'xorg'),
          category: JunkCategory.logs,
          label: 'Xorg logs',
          mode: JunkRuleMode.files,
          extensions: <String>{'log', 'old'},
          minimumAge: _logAge,
        ),

        JunkRule(
          root: p.posix.join(home, '.cache', 'coredumpctl'),
          category: JunkCategory.crashDumps,
          label: 'Core dumps',
        ),

        JunkRule(
          root: p.posix.join(home, 'Downloads'),
          category: JunkCategory.installerLeftovers,
          label: '~/Downloads',
          mode: JunkRuleMode.files,
          extensions: <String>{'deb', 'rpm', 'appimage', 'snap', 'flatpakref'},
          minimumAge: Duration(days: 30),
          maxDepth: 1,
        ),
      ],
    ];
  }
}
