import 'package:path/path.dart' as p;

import 'package:archonex_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/rules/cleaner_roots.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/rules/junk_rule.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_category.dart';

/// Where Android leaves things, and what is reachable at each access level.
///
/// The one table that takes the access as an argument, because Android is the
/// one platform where what may be read changes at runtime. Without all-files
/// access the list collapses to the app's own caches — three rows instead of
/// twelve — and that is the honest answer rather than a scan that finds nothing
/// and calls the device clean.
///
/// **No rule names another app's cache.** `/sdcard/Android/data/<pkg>/cache`
/// has been unreadable to normal apps since Android 11 and no permission opens
/// it, all-files access included. A cleaner that claims to empty it is either
/// lying or shipping a privileged build.
class AndroidJunkRules {
  const AndroidJunkRules._();

  static const Duration _logAge = Duration(days: 7);

  /// A `.trashed-` file is Android's own two-week grace period on a deleted
  /// photo. Touching one before it expires is deleting something the system
  /// promised to keep, so the rule waits out the promise and then some.
  static const Duration _trashedAge = Duration(days: 30);

  static List<JunkRule> of(CleanerRoots roots, StorageAccess access) {
    return <JunkRule>[
      ..._alwaysReachable(roots),
      if (access.level == StorageAccessLevel.full)
        ..._sharedStorage(roots)
      else
        ..._grantedFolders(access),
    ];
  }

  /// The app's own directories. Ours whatever the user has granted, and the
  /// only thing iOS has too.
  static List<JunkRule> _alwaysReachable(CleanerRoots roots) {
    return <JunkRule>[
      JunkRule(
        root: roots.appCache,
        category: JunkCategory.appCache,
        label: 'Archonex Cleaner',
      ),
      for (final String cache in roots.externalAppCaches)
        JunkRule(
          root: cache,
          category: JunkCategory.appCache,
          label: 'Archonex Cleaner',
        ),
    ];
  }

  /// Everything under `/storage/emulated/0`, which needs all-files access.
  static List<JunkRule> _sharedStorage(CleanerRoots roots) {
    final String? external = roots.externalStorage;

    if (external == null) {
      return const <JunkRule>[];
    }

    return <JunkRule>[
      // The gallery preview caches. Usually the single largest find on a phone,
      // and the reason `ProtectedPaths` carries an exception list at all.
      JunkRule(
        root: p.posix.join(external, 'DCIM', '.thumbnails'),
        category: JunkCategory.thumbnails,
        label: 'DCIM/.thumbnails',
      ),
      JunkRule(
        root: p.posix.join(external, 'Pictures', '.thumbnails'),
        category: JunkCategory.thumbnails,
        label: 'Pictures/.thumbnails',
      ),

      // Half-finished downloads and the temporary files apps drop in the one
      // directory every app can write to.
      JunkRule(
        root: p.posix.join(external, 'Download'),
        category: JunkCategory.systemTemp,
        label: 'Download',
        mode: JunkRuleMode.files,
        extensions: <String>{'tmp', 'temp', 'part', 'crdownload', 'partial'},
        maxDepth: 2,
      ),

      // What the file system recovered after an unclean unmount. Numbered
      // fragments with no names, which is why nobody ever opens the folder.
      JunkRule(
        root: p.posix.join(external, 'LOST.DIR'),
        category: JunkCategory.systemTemp,
        label: 'LOST.DIR',
      ),

      // Android's own soft delete, past the point the system would have
      // honoured it. See [_trashedAge].
      JunkRule(
        root: external,
        category: JunkCategory.trash,
        label: 'Trashed files',
        mode: JunkRuleMode.files,
        namePrefixes: <String>{'.trashed-'},
        minimumAge: _trashedAge,
        maxDepth: 3,
      ),

      JunkRule(
        root: external,
        category: JunkCategory.logs,
        label: 'Logs',
        mode: JunkRuleMode.files,
        extensions: <String>{'log', 'logcat', 'stacktrace'},
        minimumAge: _logAge,
        maxDepth: 3,
      ),

      JunkRule(
        root: p.posix.join(external, 'Download'),
        category: JunkCategory.installerLeftovers,
        label: 'Download',
        mode: JunkRuleMode.files,
        extensions: <String>{'apk', 'apks', 'xapk', 'obb'},
        minimumAge: Duration(days: 30),
        maxDepth: 1,
      ),

      JunkRule(
        root: external,
        category: JunkCategory.emptyFolders,
        label: 'Internal storage',
        mode: JunkRuleMode.emptyDirectories,
        // Shallow on purpose. A deep sweep for empty directories across shared
        // storage takes minutes on a phone and finds the same folders an
        // uninstaller left at the top.
        maxDepth: 2,
      ),
    ];
  }

  /// The fallback: only what the user handed over, one folder at a time.
  ///
  /// Nothing is assumed about what is in a picked folder, so the filters match
  /// the same temporary extensions the `Download` rule does rather than
  /// everything — a folder the user chose is not a folder they meant to empty.
  static List<JunkRule> _grantedFolders(StorageAccess access) {
    return <JunkRule>[
      for (final String folder in access.grantedRoots)
        JunkRule(
          root: folder,
          category: JunkCategory.systemTemp,
          label: p.posix.basename(folder),
          mode: JunkRuleMode.files,
          extensions: <String>{'tmp', 'temp', 'part', 'crdownload', 'partial'},
        ),
    ];
  }
}
