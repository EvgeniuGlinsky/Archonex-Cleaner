import 'package:flutter/foundation.dart';

import 'package:archonex_cleaner/project_files/features/media_optimizer/data/rules/media_roots.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/data/rules/media_rule.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/media_kind.dart';
import 'package:archonex_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';

/// The only place a platform is asked which media folders it has.
///
/// The walker never asks, exactly as it never asks which junk rules apply —
/// `JunkRuleset` is the same shape and the same reason. What is different is
/// how little there is: media lives in five or six well-known folders on every
/// platform, so there is one table and a switch, rather than a file per
/// platform. A per-platform file here would be five files of two rows.
class MediaRuleset {
  const MediaRuleset._();

  /// The folders to walk on [platform], given what [access] allows.
  ///
  /// A rule whose root is `null` is dropped rather than guessed at, which is
  /// why every `MediaRoots` field is nullable. Duplicate roots are dropped too:
  /// on Android `Pictures/Screenshots` sits inside `Pictures`, and the walker
  /// would otherwise measure every screenshot twice.
  static List<MediaRule> of({
    required TargetPlatform platform,
    required MediaRoots roots,
    required StorageAccess access,
  }) {
    final List<MediaRule> rules = switch (access.level) {
      // Nothing to walk, and nothing the user put there.
      StorageAccessLevel.none || StorageAccessLevel.appOnly => <MediaRule>[],
      // Only what was handed over. The platform's own folders are not readable.
      StorageAccessLevel.scopedFolders => _granted(roots),
      StorageAccessLevel.full => <MediaRule>[
          ..._forPlatform(platform, roots),
          ..._granted(roots),
        ],
    };

    return _deduplicated(rules);
  }

  /// Which kinds the rules for this platform could turn up.
  ///
  /// Both, or neither. Every media folder holds either kind — people put videos
  /// in `Pictures` and photographs in `Downloads` — so answering this per folder
  /// would be a promise the disk does not keep. It is still asked, because a
  /// platform with no reachable folders must produce no groups rather than two
  /// empty ones.
  static Set<MediaKind> kindsFor({
    required TargetPlatform platform,
    required MediaRoots roots,
    required StorageAccess access,
  }) {
    if (of(platform: platform, roots: roots, access: access).isEmpty) {
      return const <MediaKind>{};
    }

    return MediaKind.values.toSet();
  }

  static List<MediaRule> _forPlatform(TargetPlatform platform, MediaRoots roots) {
    return switch (platform) {
      TargetPlatform.android => _android(roots),
      TargetPlatform.windows ||
      TargetPlatform.linux ||
      TargetPlatform.macOS =>
        _desktop(roots),
      // iOS and Fuchsia reach no user media at all — the repository reports
      // `isSupported` false long before this is asked.
      TargetPlatform.iOS || TargetPlatform.fuchsia => const <MediaRule>[],
    };
  }

  /// The camera roll first, because it is where the space went.
  static List<MediaRule> _android(MediaRoots roots) {
    return <MediaRule>[
      if (roots.camera != null) MediaRule(root: roots.camera!, label: 'DCIM'),
      if (roots.videos != null) MediaRule(root: roots.videos!, label: 'Movies'),
      if (roots.pictures != null)
        MediaRule(root: roots.pictures!, label: 'Pictures'),
      if (roots.downloads != null)
        MediaRule(root: roots.downloads!, label: 'Download'),
    ];
  }

  static List<MediaRule> _desktop(MediaRoots roots) {
    return <MediaRule>[
      if (roots.videos != null) MediaRule(root: roots.videos!, label: 'Videos'),
      if (roots.pictures != null)
        MediaRule(root: roots.pictures!, label: 'Pictures'),
      if (roots.downloads != null)
        MediaRule(root: roots.downloads!, label: 'Downloads'),
    ];
  }

  /// Folders handed over through the picker.
  ///
  /// Labelled by their own last segment rather than by index, so the progress
  /// line names the folder the user chose instead of "granted folder 2".
  static List<MediaRule> _granted(MediaRoots roots) {
    return <MediaRule>[
      for (final String folder in roots.grantedFolders)
        MediaRule(root: folder, label: _lastSegment(folder)),
    ];
  }

  static String _lastSegment(String path) {
    final List<String> parts = path
        .split(RegExp(r'[/\\]'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    return parts.isEmpty ? path : parts.last;
  }

  /// Drops a root that is at or inside another root already on the list.
  ///
  /// Android's `Pictures/Screenshots` inside `Pictures` is the case that forces
  /// this, and a folder the user picked that happens to be their own `DCIM` is
  /// the other. Comparing normalised strings rather than paths is enough here
  /// because every root came from the same resolver and is already absolute.
  static List<MediaRule> _deduplicated(List<MediaRule> rules) {
    final List<MediaRule> kept = <MediaRule>[];

    for (final MediaRule rule in rules) {
      final String candidate = _normalise(rule.root);

      final bool covered = kept.any((existing) {
        final String root = _normalise(existing.root);

        return candidate == root || candidate.startsWith('$root/');
      });

      if (!covered) {
        kept.add(rule);
      }
    }

    return List<MediaRule>.unmodifiable(kept);
  }

  /// Separators unified and the trailing one dropped, case folded.
  ///
  /// Case folded on every platform rather than only on Windows: two roots
  /// differing in case is a duplicate walk on Windows and merely two walks that
  /// find the same files on Linux, and the cost of being wrong is the same
  /// either way — measuring a folder twice.
  static String _normalise(String path) {
    final String unified = path.replaceAll(r'\', '/').toLowerCase();

    return unified.endsWith('/') && unified.length > 1
        ? unified.substring(0, unified.length - 1)
        : unified;
  }
}
