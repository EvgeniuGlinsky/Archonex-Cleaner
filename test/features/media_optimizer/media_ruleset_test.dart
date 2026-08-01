import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:archonex_cleaner/project_files/features/media_optimizer/data/rules/media_roots.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/data/rules/media_rule.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/data/rules/media_ruleset.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/data/rules/off_limits_paths.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/media_kind.dart';
import 'package:archonex_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';

/// Properties that must hold for every platform's media rules, checked from
/// whichever platform CI runs on.
///
/// `junk_ruleset_test.dart` is the same idea next door. The most important
/// entry is the first: an allowlist that starts at a disk root is not an
/// allowlist.
void main() {
  const MediaRoots androidRoots = MediaRoots(
    appSupport: '/data/user/0/com.archonex.cleaner/files',
    externalStorage: '/storage/emulated/0',
    camera: '/storage/emulated/0/DCIM',
    pictures: '/storage/emulated/0/Pictures',
    videos: '/storage/emulated/0/Movies',
    downloads: '/storage/emulated/0/Download',
    screenshots: '/storage/emulated/0/Pictures/Screenshots',
  );

  const MediaRoots windowsRoots = MediaRoots(
    appSupport: r'C:\Users\sam\AppData\Roaming\com.archonex.cleaner',
    home: r'C:\Users\sam',
    pictures: r'C:\Users\sam\Pictures',
    videos: r'C:\Users\sam\Videos',
    downloads: r'C:\Users\sam\Downloads',
  );

  const MediaRoots linuxRoots = MediaRoots(
    appSupport: '/home/sam/.local/share/com.archonex.cleaner',
    home: '/home/sam',
    pictures: '/home/sam/Pictures',
    videos: '/home/sam/Videos',
    downloads: '/home/sam/Downloads',
  );

  final Map<TargetPlatform, MediaRoots> platforms =
      <TargetPlatform, MediaRoots>{
    TargetPlatform.android: androidRoots,
    TargetPlatform.windows: windowsRoots,
    TargetPlatform.linux: linuxRoots,
    TargetPlatform.macOS: linuxRoots,
  };

  List<MediaRule> rulesFor(
    TargetPlatform platform,
    MediaRoots roots, {
    StorageAccess access = const StorageAccess.open(),
  }) {
    return MediaRuleset.of(platform: platform, roots: roots, access: access);
  }

  test('no rule is rooted somewhere the guard refuses whole', () {
    // The two lists exist to catch each other. A root the guard would refuse
    // outright is a walk that finds thousands of files and offers none of them.
    platforms.forEach((platform, roots) {
      final OffLimitsPaths guard = OffLimitsPaths.of(platform, roots);

      for (final MediaRule rule in rulesFor(platform, roots)) {
        expect(
          guard.contains(rule.root),
          isFalse,
          reason: '$platform walks ${rule.root}, which the guard refuses',
        );
      }
    });
  });

  test('no rule starts at a disk root', () {
    // An allowlist that begins at `/` or `C:\` is not an allowlist. This is the
    // single most important property in the file.
    platforms.forEach((platform, roots) {
      for (final MediaRule rule in rulesFor(platform, roots)) {
        expect(
          <String>['/', r'C:\', r'C:', '', '.'],
          isNot(contains(rule.root)),
          reason: '$platform',
        );
        expect(rule.root.length, greaterThan(4), reason: '$platform');
      }
    });
  });

  test('every platform with media folders offers something', () {
    platforms.forEach((platform, roots) {
      expect(rulesFor(platform, roots), isNotEmpty, reason: '$platform');
    });
  });

  test('iOS reaches nothing, and says so by producing no rules', () {
    // The photo library is behind an API that hands out copies rather than
    // paths. There is no rule to write.
    expect(
      rulesFor(TargetPlatform.iOS, const MediaRoots(appSupport: '/app')),
      isEmpty,
    );
  });

  test('a folder inside another folder on the list is dropped', () {
    // Android's `Pictures/Screenshots` sits inside `Pictures`, and without this
    // every screenshot would be measured twice.
    final List<String> roots = rulesFor(TargetPlatform.android, androidRoots)
        .map((rule) => rule.root)
        .toList(growable: false);

    expect(roots, contains('/storage/emulated/0/Pictures'));
    expect(roots, isNot(contains('/storage/emulated/0/Pictures/Screenshots')));
  });

  test('the camera roll is walked first, because it is where the space went',
      () {
    expect(
      rulesFor(TargetPlatform.android, androidRoots).first.root,
      '/storage/emulated/0/DCIM',
    );
  });

  group('access', () {
    test('an app-only device produces no rules and no kinds', () {
      // iOS always, and Android with all-files access refused. Neither can see
      // a single file the user put there.
      for (final StorageAccess access in <StorageAccess>[
        const StorageAccess.sandboxed(),
        const StorageAccess.unavailable(),
      ]) {
        expect(
          rulesFor(TargetPlatform.android, androidRoots, access: access),
          isEmpty,
        );
        expect(
          MediaRuleset.kindsFor(
            platform: TargetPlatform.android,
            roots: androidRoots,
            access: access,
          ),
          isEmpty,
        );
      }
    });

    test('a picked folder is walked, and the platform folders are not', () {
      const MediaRoots picked = MediaRoots(
        appSupport: '/data/user/0/com.archonex.cleaner/files',
        externalStorage: '/storage/emulated/0',
        camera: '/storage/emulated/0/DCIM',
        grantedFolders: <String>['/storage/emulated/0/Trips'],
      );

      final List<String> roots = rulesFor(
        TargetPlatform.android,
        picked,
        access: const StorageAccess(
          level: StorageAccessLevel.scopedFolders,
          grantedRoots: <String>['/storage/emulated/0/Trips'],
          canAddFolder: true,
        ),
      ).map((rule) => rule.root).toList(growable: false);

      expect(roots, <String>['/storage/emulated/0/Trips']);
    });

    test('a picked folder is labelled by its own name', () {
      const MediaRoots picked = MediaRoots(
        appSupport: '/app',
        grantedFolders: <String>['/storage/emulated/0/Trips/Iceland'],
      );

      expect(
        rulesFor(
          TargetPlatform.android,
          picked,
          access: const StorageAccess(level: StorageAccessLevel.scopedFolders),
        ).single.label,
        'Iceland',
      );
    });

    test('a picked folder the platform already covers is dropped', () {
      const MediaRoots picked = MediaRoots(
        appSupport: '/app',
        camera: '/storage/emulated/0/DCIM',
        grantedFolders: <String>['/storage/emulated/0/DCIM/Camera'],
      );

      expect(rulesFor(TargetPlatform.android, picked), hasLength(1));
    });

    test('full access turns up both kinds', () {
      // Both or neither: every media folder holds either kind, and answering
      // per folder would be a promise the disk does not keep.
      expect(
        MediaRuleset.kindsFor(
          platform: TargetPlatform.windows,
          roots: windowsRoots,
          access: const StorageAccess.open(),
        ),
        MediaKind.values.toSet(),
      );
    });
  });

  group('what the walker will open', () {
    const MediaRule rule = MediaRule(root: '/x', label: 'x');

    test('the extensions media actually arrives with, whatever the case', () {
      for (final String name in <String>[
        'IMG_0001.JPG',
        'a.jpeg',
        'a.png',
        'a.HEIC',
        'VID_0001.mp4',
        'a.MOV',
        'a.mkv',
        'a.avi',
        'a.webm',
      ]) {
        expect(rule.matchesFile(name), isTrue, reason: name);
      }
    });

    test('and nothing else', () {
      for (final String name in <String>[
        'a.txt',
        'a.mp3',
        'a.zip',
        'noextension',
        '.jpg',
      ]) {
        expect(
          rule.matchesFile(name),
          name == '.jpg',
          reason: name,
        );
      }
    });

    test('a working file left by a crashed run is never a candidate', () {
      // It is half an encode. The next run sweeps it away rather than
      // measuring it, offering it, and re-encoding a fragment.
      expect(rule.matchesFile('.archonex-working-holiday.jpg'), isFalse);
      expect(rule.matchesFile('holiday.jpg.archonex-old'), isFalse);
    });
  });
}
