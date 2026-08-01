import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:storage_cleaner/project_files/features/media_optimizer/data/rules/media_roots.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/rules/off_limits_paths.dart';

/// The optimiser's paranoid file, checked from whichever platform CI runs on.
///
/// `protected_paths_test.dart` is the same test for the cleaner and the two are
/// deliberately not one file, because the two lists are deliberately not one
/// list. The cleaner refuses the user's own folders; this tool's entire subject
/// *is* the user's own folders, so almost nothing carries over and a mistake in
/// either would be invisible from inside the other.
void main() {
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

  const MediaRoots macRoots = MediaRoots(
    appSupport: '/Users/sam/Library/Application Support/com.archonex.cleaner',
    home: '/Users/sam',
    pictures: '/Users/sam/Pictures',
    videos: '/Users/sam/Movies',
    downloads: '/Users/sam/Downloads',
  );

  const MediaRoots androidRoots = MediaRoots(
    appSupport: '/data/user/0/com.archonex.cleaner/files',
    externalStorage: '/storage/emulated/0',
    camera: '/storage/emulated/0/DCIM',
    pictures: '/storage/emulated/0/Pictures',
    videos: '/storage/emulated/0/Movies',
    downloads: '/storage/emulated/0/Download',
    screenshots: '/storage/emulated/0/Pictures/Screenshots',
  );

  OffLimitsPaths guardFor(TargetPlatform platform, MediaRoots roots) =>
      OffLimitsPaths.of(platform, roots);

  group('what every platform refuses', () {
    test('this app\'s own support directory, so a quarantined photo is safe',
        () {
      // A file inside the cleaner's quarantine is one the user is part way
      // through deciding about. Rewriting it means a restore gives back
      // something other than what was taken.
      for (final (TargetPlatform platform, MediaRoots roots)
          in <(TargetPlatform, MediaRoots)>[
        (TargetPlatform.windows, windowsRoots),
        (TargetPlatform.linux, linuxRoots),
        (TargetPlatform.macOS, macRoots),
        (TargetPlatform.android, androidRoots),
      ]) {
        final OffLimitsPaths guard = guardFor(platform, roots);

        expect(guard.contains(roots.appSupport), isTrue, reason: '$platform');
        expect(
          guard.contains('${roots.appSupport}/quarantine/b1/holiday.jpg'
              .replaceAll('/', platform == TargetPlatform.windows ? r'\' : '/')),
          isTrue,
          reason: '$platform',
        );
      }
    });

    test('a cloud mirror, wherever the user mounted it', () {
      // The first reason this class exists. Rewriting a synced file re-uploads
      // every byte and replaces the master on every device on the account.
      final OffLimitsPaths windows = guardFor(TargetPlatform.windows, windowsRoots);
      final OffLimitsPaths linux = guardFor(TargetPlatform.linux, linuxRoots);
      final OffLimitsPaths mac = guardFor(TargetPlatform.macOS, macRoots);

      expect(windows.contains(r'C:\Users\sam\OneDrive\Pictures\a.jpg'), isTrue);
      expect(windows.contains(r'D:\Dropbox\Camera Uploads\a.jpg'), isTrue);
      expect(linux.contains('/home/sam/Nextcloud/Photos/a.jpg'), isTrue);
      expect(linux.contains('/mnt/big/Yandex.Disk/a.mp4'), isTrue);
      expect(
        mac.contains('/Users/sam/Library/Mobile Documents/com~apple~CloudDocs/a.jpg'),
        isTrue,
      );
    });

    test('a folder merely named like a cloud one is not refused', () {
      // Segments are matched whole. "Dropbox Party 2019" is somebody's holiday.
      final OffLimitsPaths guard = guardFor(TargetPlatform.windows, windowsRoots);

      expect(
        guard.contains(r'C:\Users\sam\Pictures\Dropbox Party 2019\a.jpg'),
        isFalse,
      );
      expect(guard.contains(r'C:\Users\sam\Pictures\MEGAcity\a.jpg'), isFalse);
    });

    test('game assets, which have checksums beside them', () {
      final OffLimitsPaths windows = guardFor(TargetPlatform.windows, windowsRoots);
      final OffLimitsPaths linux = guardFor(TargetPlatform.linux, linuxRoots);

      expect(
        windows.contains(r'D:\SteamLibrary\steamapps\common\Game\intro.mp4'),
        isTrue,
      );
      expect(windows.contains(r'C:\Program Files\Game\video\logo.mp4'), isTrue);
      expect(linux.contains('/home/sam/.steam/steam/game/intro.mp4'), isTrue);
    });

    test('a working tree, where a rewritten PNG is a diff somebody explains',
        () {
      final OffLimitsPaths guard = guardFor(TargetPlatform.linux, linuxRoots);

      expect(guard.contains('/home/sam/code/app/.git/x.png'), isTrue);
      expect(guard.contains('/home/sam/code/app/node_modules/a/logo.png'), isTrue);
    });

    test('the folders the tool actually exists for are not refused', () {
      // The guard must not be so broad that it refuses the subject.
      expect(
        guardFor(TargetPlatform.windows, windowsRoots)
            .contains(r'C:\Users\sam\Pictures\2019\holiday.jpg'),
        isFalse,
      );
      expect(
        guardFor(TargetPlatform.linux, linuxRoots)
            .contains('/home/sam/Videos/wedding.mp4'),
        isFalse,
      );
      expect(
        guardFor(TargetPlatform.macOS, macRoots)
            .contains('/Users/sam/Movies/wedding.mp4'),
        isFalse,
      );
      expect(
        guardFor(TargetPlatform.android, androidRoots)
            .contains('/storage/emulated/0/DCIM/Camera/VID_0001.mp4'),
        isFalse,
      );
    });
  });

  group('windows', () {
    final OffLimitsPaths guard = guardFor(TargetPlatform.windows, windowsRoots);

    test('system and program directories, at any depth', () {
      expect(guard.contains(r'C:\Windows\Web\Wallpaper\img0.jpg'), isTrue);
      expect(guard.contains(r'C:\Program Files (x86)\App\a.png'), isTrue);
      expect(guard.contains(r'C:\ProgramData\App\a.png'), isTrue);
      expect(guard.contains(r'C:\$Recycle.Bin\S-1-5\a.jpg'), isTrue);
    });

    test('AppData, where every image is something a program expects back', () {
      expect(
        guard.contains(r'C:\Users\sam\AppData\Local\Browser\Cache\f_00001.jpg'),
        isTrue,
      );
    });

    test('the comparison is case-insensitive, as the file system is', () {
      expect(guard.contains(r'c:\windows\web\a.jpg'), isTrue);
      expect(guard.contains(r'C:\Users\sam\ONEDRIVE\a.jpg'), isTrue);
    });

    test('a path walking back out through .. does not escape the guard', () {
      expect(
        guard.contains(r'C:\Users\sam\Pictures\..\AppData\Local\a.png'),
        isTrue,
      );
    });
  });

  group('linux', () {
    final OffLimitsPaths guard = guardFor(TargetPlatform.linux, linuxRoots);

    test('the system tree', () {
      for (final String path in <String>[
        '/usr/share/backgrounds/a.jpg',
        '/var/lib/app/a.png',
        '/opt/app/a.mp4',
        '/snap/app/a.png',
        '/etc/a.png',
      ]) {
        expect(guard.contains(path), isTrue, reason: path);
      }
    });

    test('the dotted directories under home', () {
      expect(guard.contains('/home/sam/.cache/thumbnails/a.png'), isTrue);
      expect(guard.contains('/home/sam/.local/share/app/a.png'), isTrue);
      expect(guard.contains('/home/sam/.config/app/a.png'), isTrue);
    });

    test('and is case-sensitive about paths, as the file system is', () {
      // Only the segment list folds case; the roots go through a posix context.
      expect(guard.contains('/home/sam/Pictures/a.jpg'), isFalse);
      expect(guard.contains('/USR/share/a.jpg'), isFalse);
    });
  });

  group('macos', () {
    final OffLimitsPaths guard = guardFor(TargetPlatform.macOS, macRoots);

    test('the Photos library, which is a database and not a folder', () {
      // A rewritten original inside one is a photo the app can no longer open.
      expect(
        guard.contains(
          '/Users/sam/Pictures/Photos Library.photoslibrary/originals/0/a.heic',
        ),
        isTrue,
      );
      // And the folder around it is still fair game.
      expect(guard.contains('/Users/sam/Pictures/Exports/a.jpg'), isFalse);
    });

    test('the system tree and the user library', () {
      expect(guard.contains('/System/Library/a.png'), isTrue);
      expect(guard.contains('/Applications/App.app/a.png'), isTrue);
      expect(guard.contains('/Users/sam/Library/Caches/a.jpg'), isTrue);
    });
  });

  group('android', () {
    final OffLimitsPaths guard = guardFor(TargetPlatform.android, androidRoots);

    test('the gallery thumbnail caches, which are the cleaner\'s job', () {
      expect(
        guard.contains('/storage/emulated/0/DCIM/.thumbnails/1.jpg'),
        isTrue,
      );
      expect(
        guard.contains('/storage/emulated/0/Pictures/.thumbnails/1.jpg'),
        isTrue,
      );
    });

    test('everything under Android/, which belongs to other apps', () {
      expect(
        guard.contains('/storage/emulated/0/Android/media/com.chat/received.jpg'),
        isTrue,
      );
      expect(
        guard.contains('/storage/emulated/0/Android/data/com.app/cache/a.jpg'),
        isTrue,
      );
    });

    test('the system partitions', () {
      for (final String path in <String>[
        '/system/media/a.png',
        '/vendor/a.png',
        '/data/user/0/com.other/files/a.jpg',
      ]) {
        expect(guard.contains(path), isTrue, reason: path);
      }
    });

    test('the camera roll itself is not refused', () {
      // The one place this differs hardest from `ProtectedPaths`, which refuses
      // DCIM outright. Deleting from it and re-encoding inside it are not the
      // same risk.
      expect(guard.contains('/storage/emulated/0/DCIM/Camera/IMG_1.jpg'), isFalse);
      expect(guard.contains('/storage/emulated/0/Pictures/Saved/a.jpg'), isFalse);
    });
  });

  group('ios and fuchsia', () {
    test('refuse the app support directory and nothing else is reachable', () {
      const MediaRoots roots = MediaRoots(appSupport: '/var/mobile/App/Library');
      final OffLimitsPaths guard = guardFor(TargetPlatform.iOS, roots);

      expect(guard.contains('/var/mobile/App/Library/quarantine/a.jpg'), isTrue);
    });
  });

  test('an unresolved root contributes nothing rather than matching everything',
      () {
    // Every MediaRoots field is nullable, and a null one must not become an
    // empty string that swallows the disk.
    const MediaRoots bare = MediaRoots(appSupport: '/app/support');
    final OffLimitsPaths guard = guardFor(TargetPlatform.linux, bare);

    expect(guard.contains('/home/sam/Pictures/a.jpg'), isFalse);
    expect(guard.contains('/app/support/a.jpg'), isTrue);
  });
}
