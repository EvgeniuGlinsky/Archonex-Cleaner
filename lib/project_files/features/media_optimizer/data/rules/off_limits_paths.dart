import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:storage_cleaner/project_files/features/media_optimizer/data/rules/media_roots.dart';

/// The list of places no file is ever rewritten, whatever a rule says.
///
/// The optimiser's counterpart to `ProtectedPaths`, and the inverse of it in
/// the one way that matters: the cleaner protects the user's own folders and
/// this tool's entire subject *is* the user's own folders. So the two lists
/// have almost nothing in common, and writing one by editing the other would
/// produce something that protects nothing.
///
/// It is the second of two lists, exactly as over in the cleaner. `MediaRuleset`
/// is an allowlist — the walk starts only at folders the user fills themselves,
/// never at a disk root — and this refuses individual findings inside them
/// afterwards. A mistake in either is caught by the other, and
/// `off_limits_paths_test.dart` is the file to grow when anything here changes.
///
/// Pure: it takes a [p.Context] and a set of roots rather than reading
/// `Platform`, which is what lets the Windows answers be tested from Linux CI.
@immutable
class OffLimitsPaths {
  const OffLimitsPaths({
    required this.roots,
    required p.Context context,
    this.segments = const <String>[],
  }) : _context = context;

  /// Nothing at or below any of these is rewritten.
  final List<String> roots;

  /// Directory names that make everything below them off limits, wherever they
  /// appear.
  ///
  /// Paths cannot express these. A cloud folder can be anywhere the user
  /// mounted it, a `node_modules` is wherever somebody ran an install, and a
  /// Steam library is routinely on a second drive with no fixed letter. Matched
  /// as whole path *segments* and never as substrings, so a holiday video in
  /// `Dropbox Party 2019` is not mistaken for one inside `Dropbox`.
  final List<String> segments;

  final p.Context _context;

  /// The guard for the platform the app is running on.
  static OffLimitsPaths of(TargetPlatform platform, MediaRoots mediaRoots) {
    return switch (platform) {
      TargetPlatform.windows => OffLimitsPaths(
          context: p.Context(style: p.Style.windows),
          roots: _windows(mediaRoots),
          segments: _segments,
        ),
      TargetPlatform.linux => OffLimitsPaths(
          context: p.Context(style: p.Style.posix),
          roots: _linux(mediaRoots),
          segments: _segments,
        ),
      TargetPlatform.macOS => OffLimitsPaths(
          context: p.Context(style: p.Style.posix),
          roots: _macOS(mediaRoots),
          segments: _segments,
        ),
      TargetPlatform.android => OffLimitsPaths(
          context: p.Context(style: p.Style.posix),
          roots: _android(mediaRoots),
          segments: _segments,
        ),
      TargetPlatform.iOS || TargetPlatform.fuchsia => OffLimitsPaths(
          context: p.Context(style: p.Style.posix),
          roots: _everywhere(mediaRoots),
          segments: _segments,
        ),
    };
  }

  /// Whether [path] is somewhere this tool must not write.
  bool contains(String path) {
    final String normalized = _context.normalize(path);

    if (_hasOffLimitsSegment(normalized)) {
      return true;
    }

    for (final String candidate in roots) {
      final String normalizedCandidate = _context.normalize(candidate);

      if (_context.equals(normalized, normalizedCandidate) ||
          _context.isWithin(normalizedCandidate, normalized)) {
        return true;
      }
    }

    return false;
  }

  bool _hasOffLimitsSegment(String normalized) {
    for (final String part in _context.split(normalized)) {
      final String folded = part.toLowerCase();

      for (final String segment in segments) {
        if (folded == segment.toLowerCase()) {
          return true;
        }
      }
    }

    return false;
  }

  /// Directory names that are off limits wherever they turn up, on every
  /// platform.
  ///
  /// **Cloud mirrors** are the first reason this class exists. A file in a
  /// synced folder is not a local file: rewriting it re-uploads every byte,
  /// which on a metered connection is a bill, and on a service with version
  /// history replaces a master with a lossy copy on every device the account
  /// touches. Deleting from a mirror deletes from the account, and the cleaner
  /// refuses them for that reason; rewriting one is worse, because it happens
  /// silently and looks like it worked.
  ///
  /// **Game and application data** is the second. A game's `intro.mp4` is an
  /// asset with a checksum beside it, not the user's video, and re-encoding it
  /// breaks the install in a way that looks like a corrupt download. The same
  /// goes for the sample media inside anything under a package directory.
  ///
  /// **Working trees** are the third, and the cheapest to be wrong about: a PNG
  /// inside a repository is a tracked file, and rewriting it makes a diff
  /// somebody has to explain.
  static const List<String> _segments = <String>[
    'OneDrive',
    'Dropbox',
    'Google Drive',
    'GoogleDrive',
    'Creative Cloud Files',
    'Mobile Documents',
    'iCloud Drive',
    'Yandex.Disk',
    'YandexDisk',
    'MEGA',
    'pCloudDrive',
    'Nextcloud',
    'ownCloud',
    'Sync',
    'SteamLibrary',
    'steamapps',
    'node_modules',
    '.git',
    '.svn',
    // Every app's private area on Android, and the place a package manager
    // unpacks to on the desktops.
    'Android',
  ];

  /// This app's own support directory, on every platform and first in every
  /// list.
  ///
  /// A photo inside the cleaner's quarantine is a file the user is part way
  /// through deciding about. Rewriting it would mean a restore gives back
  /// something other than what was taken, which is the one promise the
  /// quarantine makes.
  static List<String> _everywhere(MediaRoots roots) =>
      <String>[roots.appSupport];

  static List<String> _windows(MediaRoots roots) {
    final String? home = roots.home;

    return <String>[
      ..._everywhere(roots),
      r'C:\Windows',
      r'C:\Program Files',
      r'C:\Program Files (x86)',
      r'C:\ProgramData',
      r'C:\$Recycle.Bin',
      r'C:\System Volume Information',
      if (home != null) ...<String>[
        // Application state, not the user's pictures. Browser caches and
        // thumbnail databases are full of images, and every one of them is
        // something a program wrote and expects back byte for byte.
        p.windows.join(home, 'AppData'),
      ],
    ];
  }

  static List<String> _linux(MediaRoots roots) {
    final String? home = roots.home;

    return <String>[
      ..._everywhere(roots),
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
      '/var',
      '/opt',
      '/snap',
      if (home != null) ...<String>[
        p.posix.join(home, '.cache'),
        p.posix.join(home, '.config'),
        p.posix.join(home, '.local'),
        p.posix.join(home, '.steam'),
        p.posix.join(home, '.var'),
      ],
    ];
  }

  static List<String> _macOS(MediaRoots roots) {
    final String? home = roots.home;

    return <String>[
      ..._everywhere(roots),
      '/System',
      '/Library',
      '/Applications',
      '/bin',
      '/sbin',
      '/usr',
      '/etc',
      '/var',
      '/private',
      if (home != null) ...<String>[
        // Where the Photos app keeps its library. It is a package with its own
        // database of file identities, and a rewritten original inside one is a
        // photo the app can no longer open.
        p.posix.join(home, 'Pictures', 'Photos Library.photoslibrary'),
        p.posix.join(home, 'Pictures', 'Photo Booth Library'),
        p.posix.join(home, 'Library'),
        p.posix.join(home, 'Applications'),
      ],
    ];
  }

  static List<String> _android(MediaRoots roots) {
    final String? external = roots.externalStorage;

    return <String>[
      ..._everywhere(roots),
      '/system',
      '/vendor',
      '/proc',
      '/sys',
      '/dev',
      '/data',
      if (external != null) ...<String>[
        // Generated previews. Tiny, numerous, and rebuilt on demand — the
        // cleaner deletes these, which is the right tool for them.
        p.posix.join(external, 'DCIM', '.thumbnails'),
        p.posix.join(external, 'Pictures', '.thumbnails'),
        // What messaging apps received rather than what the camera took. Left
        // alone because they are already compressed to within an inch of their
        // lives by the service that delivered them, and because a chat client
        // that re-reads its own media directory finds files it did not write.
        p.posix.join(external, 'Android', 'media'),
      ],
    ];
  }
}
