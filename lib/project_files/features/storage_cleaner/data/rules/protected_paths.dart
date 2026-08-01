import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:storage_cleaner/project_files/features/storage_cleaner/data/rules/cleaner_roots.dart';

/// The list of places nothing is ever deleted from, whatever a rule says.
///
/// This is the file to be paranoid in. Every other part of the app can be wrong
/// and cost the user a slow web page; a rule that walks into `System32` costs
/// them the machine. It is therefore checked against every finding, after the
/// rule has already decided the finding is junk — the two are deliberately not
/// the same list, so a mistake in one is caught by the other.
///
/// It is pure: it takes a [p.Context] and a set of roots rather than reading
/// `Platform`, which is what lets the Windows answers be tested from Linux CI.
/// `ProtectedPaths.of` is the only place the current platform is consulted.
@immutable
class ProtectedPaths {
  const ProtectedPaths({
    required this.roots,
    required p.Context context,
    this.exceptions = const <String>[],
  }) : _context = context;

  /// Nothing at or below any of these is deletable.
  final List<String> roots;

  /// Narrower paths that are deletable despite sitting inside a [roots] entry.
  ///
  /// One case today, and it is the reason this exists rather than the rules
  /// being written to dodge the guard: `DCIM/.thumbnails` is generated junk
  /// living inside the one directory on a phone that must never be touched. The
  /// alternative was leaving `DCIM` unprotected and trusting every future rule
  /// to be narrow, which is exactly the trust this file exists to withhold.
  ///
  /// An exception is checked before the roots, so it wins, and it is a
  /// *directory* rather than a pattern — nothing here can be widened by
  /// accident.
  final List<String> exceptions;

  final p.Context _context;

  /// The guard for the platform the app is running on.
  static ProtectedPaths of(TargetPlatform platform, CleanerRoots cleanerRoots) {
    return switch (platform) {
      TargetPlatform.windows => ProtectedPaths(
          context: p.Context(style: p.Style.windows),
          roots: _windows(cleanerRoots),
        ),
      TargetPlatform.linux => ProtectedPaths(
          context: p.Context(style: p.Style.posix),
          roots: _linux(cleanerRoots),
        ),
      TargetPlatform.macOS => ProtectedPaths(
          context: p.Context(style: p.Style.posix),
          roots: _macOS(cleanerRoots),
        ),
      TargetPlatform.android => ProtectedPaths(
          context: p.Context(style: p.Style.posix),
          roots: _android(cleanerRoots),
          exceptions: _androidExceptions(cleanerRoots),
        ),
      TargetPlatform.iOS || TargetPlatform.fuchsia => ProtectedPaths(
          context: p.Context(style: p.Style.posix),
          roots: _appOnly(cleanerRoots),
        ),
    };
  }

  /// Whether [path] is at or inside a protected root, and not inside an
  /// [exceptions] entry.
  ///
  /// Equality counts, not just containment: `C:\Windows` itself is as protected
  /// as everything under it.
  bool contains(String path) {
    final String normalized = _context.normalize(path);

    if (_isAtOrWithinAny(normalized, exceptions)) {
      return false;
    }

    return _isAtOrWithinAny(normalized, roots);
  }

  bool _isAtOrWithinAny(String normalized, List<String> candidates) {
    for (final String candidate in candidates) {
      final String normalizedCandidate = _context.normalize(candidate);

      if (_context.equals(normalized, normalizedCandidate) ||
          _context.isWithin(normalizedCandidate, normalized)) {
        return true;
      }
    }

    return false;
  }

  /// The app's own quarantine and support directory.
  ///
  /// On every platform, and first in every list: a cleaner that scans its own
  /// undo directory deletes the undo. The app cache is deliberately *not* here
  /// — emptying that is a category the user can tick.
  static List<String> _appOnly(CleanerRoots roots) =>
      <String>[roots.appSupport];

  static List<String> _windows(CleanerRoots roots) {
    final String? windows = roots.windowsDirectory;
    final String? home = roots.home;

    return <String>[
      ..._appOnly(roots),
      if (windows != null) ...<String>[
        // The whole of it. The rules that want `C:\Windows\Temp` name it
        // explicitly and are checked against this list, so the two have to be
        // reconciled deliberately rather than by a rule quietly widening.
        p.windows.join(windows, 'System32'),
        p.windows.join(windows, 'SysWOW64'),
        p.windows.join(windows, 'WinSxS'),
        p.windows.join(windows, 'assembly'),
        p.windows.join(windows, 'Boot'),
        p.windows.join(windows, 'Fonts'),
        p.windows.join(windows, 'System'),
      ],
      r'C:\Program Files',
      r'C:\Program Files (x86)',
      r'C:\ProgramData\Microsoft\Windows\Start Menu',
      r'C:\$Recovery',
      r'C:\System Volume Information',
      if (home != null) ...<String>[
        p.windows.join(home, 'Documents'),
        p.windows.join(home, 'Desktop'),
        p.windows.join(home, 'Pictures'),
        p.windows.join(home, 'Videos'),
        p.windows.join(home, 'Music'),
        // Not junk and not the user's either: a cloud folder is a live mirror,
        // and deleting from it deletes from the account.
        p.windows.join(home, 'OneDrive'),
        p.windows.join(home, 'Dropbox'),
      ],
    ];
  }

  static List<String> _linux(CleanerRoots roots) {
    final String? home = roots.home;

    return <String>[
      ..._appOnly(roots),
      '/bin',
      '/boot',
      '/dev',
      '/etc',
      '/lib',
      '/lib64',
      '/proc',
      '/root',
      '/sbin',
      '/sys',
      '/usr',
      // `/var/tmp` is the one temporary directory deliberately left alone: it
      // is defined as surviving a reboot, which is what things put there are
      // relying on.
      '/var',
      '/opt',
      '/snap',
      if (home != null) ...<String>[
        p.posix.join(home, 'Documents'),
        p.posix.join(home, 'Desktop'),
        p.posix.join(home, 'Pictures'),
        p.posix.join(home, 'Videos'),
        p.posix.join(home, 'Music'),
        // Configuration, not cache. `~/.cache` is the sibling that is fair game
        // and it is a different directory.
        p.posix.join(home, '.config'),
        p.posix.join(home, '.ssh'),
        p.posix.join(home, '.gnupg'),
        p.posix.join(home, '.local', 'share', 'keyrings'),
      ],
    ];
  }

  static List<String> _macOS(CleanerRoots roots) {
    final String? home = roots.home;

    return <String>[
      ..._appOnly(roots),
      '/System',
      '/Library',
      '/Applications',
      '/bin',
      '/sbin',
      '/usr',
      '/etc',
      '/var',
      '/private/var',
      if (home != null) ...<String>[
        p.posix.join(home, 'Documents'),
        p.posix.join(home, 'Desktop'),
        p.posix.join(home, 'Pictures'),
        p.posix.join(home, 'Movies'),
        p.posix.join(home, 'Music'),
        p.posix.join(home, 'Library', 'Keychains'),
        p.posix.join(home, 'Library', 'Application Support'),
        p.posix.join(home, 'Library', 'Preferences'),
        // The local mirror of an iCloud Drive. Same reason as OneDrive.
        p.posix.join(home, 'Library', 'Mobile Documents'),
      ],
    ];
  }

  static List<String> _android(CleanerRoots roots) {
    final String? external = roots.externalStorage;

    return <String>[
      ..._appOnly(roots),
      '/system',
      '/vendor',
      '/data',
      '/proc',
      '/sys',
      '/dev',
      if (external != null) ...<String>[
        // The camera roll and everything alongside it. The generated
        // `.thumbnails` directories inside two of them are the one thing here
        // that is junk, and they are named in [_androidExceptions].
        p.posix.join(external, 'DCIM'),
        p.posix.join(external, 'Pictures'),
        p.posix.join(external, 'Movies'),
        p.posix.join(external, 'Music'),
        p.posix.join(external, 'Documents'),
        // Unreadable to a normal app anyway, with or without all-files access.
        // Listed so a future rule cannot be written against it by mistake.
        p.posix.join(external, 'Android', 'data'),
        p.posix.join(external, 'Android', 'obb'),
      ],
    ];
  }

  /// The two narrow things inside Android's protected trees that are junk.
  ///
  /// The gallery thumbnail caches, which the gallery rebuilds on demand, are
  /// routinely the largest single thing a phone is carrying — a few thousand
  /// photos produce hundreds of megabytes of previews — and they are the only
  /// reason `DCIM` is not simply left unprotected.
  ///
  /// The app's own cache is the other, and it is here because `/data` is
  /// protected whole: on Android the cache directory is
  /// `/data/user/0/<package>/cache`, so without this the one thing that is
  /// unambiguously ours to empty would be the one thing the guard refused.
  /// The support directory next to it — which holds the quarantine — stays
  /// protected, and the two do not overlap.
  static List<String> _androidExceptions(CleanerRoots roots) {
    final String? external = roots.externalStorage;

    return <String>[
      roots.appCache,
      ...roots.externalAppCaches,
      if (external != null) ...<String>[
        p.posix.join(external, 'DCIM', '.thumbnails'),
        p.posix.join(external, 'Pictures', '.thumbnails'),
      ],
    ];
  }
}
