import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:storage_cleaner/project_files/features/storage_cleaner/data/rules/cleaner_roots.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/rules/protected_paths.dart';

/// The most important test in the project.
///
/// Everything else here can be wrong and cost the user a slow web page for a
/// day. This one being wrong costs them their machine, so it checks every
/// platform's list from whichever platform CI happens to run on — which is what
/// `ProtectedPaths` taking a `p.Context` is for.
void main() {
  const CleanerRoots windowsRoots = CleanerRoots(
    appCache: r'C:\Users\tester\AppData\Local\Temp\storage_cleaner',
    appSupport: r'C:\Users\tester\AppData\Roaming\com.archonex.storagecleaner',
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
    appCache: '/data/user/0/com.archonex.storagecleaner/cache',
    appSupport: '/data/user/0/com.archonex.storagecleaner/files',
    externalStorage: '/storage/emulated/0',
  );

  group('Windows', () {
    final ProtectedPaths paths =
        ProtectedPaths.of(TargetPlatform.windows, windowsRoots);

    test('refuses the system directories, at any depth', () {
      expect(paths.contains(r'C:\Windows\System32'), isTrue);
      expect(paths.contains(r'C:\Windows\System32\drivers\etc\hosts'), isTrue);
      expect(paths.contains(r'C:\Windows\WinSxS\something'), isTrue);
      expect(paths.contains(r'C:\Program Files\App\app.exe'), isTrue);
    });

    test('refuses the folders the user keeps things in', () {
      expect(paths.contains(r'C:\Users\tester\Documents\tax.pdf'), isTrue);
      expect(paths.contains(r'C:\Users\tester\Pictures'), isTrue);
      expect(paths.contains(r'C:\Users\tester\OneDrive\work'), isTrue);
    });

    test('allows the temp directories the rules are written against', () {
      expect(
        paths.contains(r'C:\Users\tester\AppData\Local\Temp\setup.tmp'),
        isFalse,
      );
      // Inside `C:\Windows`, and deliberately not inside the seven
      // subdirectories that are protected.
      expect(paths.contains(r'C:\Windows\Temp\leftover.log'), isFalse);
    });

    test('is case insensitive, because Windows is', () {
      expect(paths.contains(r'c:\windows\system32\kernel32.dll'), isTrue);
      expect(paths.contains(r'C:\PROGRAM FILES\App'), isTrue);
    });

    test('normalises a path that walks back up into a protected root', () {
      expect(
        paths.contains(r'C:\Users\tester\AppData\Local\Temp\..\..\..\Documents'),
        isTrue,
      );
    });

    test("refuses the app's own quarantine", () {
      expect(paths.contains(windowsRoots.appSupport), isTrue);
      expect(
        paths.contains('${windowsRoots.appSupport}\\quarantine\\batch'),
        isTrue,
      );
    });

    test("allows the app's own cache, which is a category the user can tick",
        () {
      expect(paths.contains('${windowsRoots.appCache}\\scratch'), isFalse);
    });
  });

  group('Linux', () {
    final ProtectedPaths paths =
        ProtectedPaths.of(TargetPlatform.linux, posixRoots);

    test('refuses the system tree', () {
      for (final String path in <String>[
        '/etc/passwd',
        '/usr/bin/bash',
        '/boot/vmlinuz',
        '/var/tmp/keepme',
        '/root/.bashrc',
      ]) {
        expect(paths.contains(path), isTrue, reason: path);
      }
    });

    test('refuses configuration and keys but allows the cache beside them', () {
      expect(paths.contains('/home/tester/.config/app/settings'), isTrue);
      expect(paths.contains('/home/tester/.ssh/id_ed25519'), isTrue);
      expect(paths.contains('/home/tester/.cache/app/blob'), isFalse);
    });

    test('allows /tmp', () {
      expect(paths.contains('/tmp/build-1234'), isFalse);
    });

    test('is case sensitive, because Linux is', () {
      expect(paths.contains('/USR/bin'), isFalse);
    });
  });

  group('macOS', () {
    final ProtectedPaths paths =
        ProtectedPaths.of(TargetPlatform.macOS, posixRoots);

    test('refuses Application Support and allows Caches beside it', () {
      expect(
        paths.contains('/home/tester/Library/Application Support/app'),
        isTrue,
      );
      expect(paths.contains('/home/tester/Library/Caches/app'), isFalse);
    });

    test('refuses the iCloud mirror', () {
      expect(
        paths.contains('/home/tester/Library/Mobile Documents/doc.pages'),
        isTrue,
      );
    });
  });

  group('Android', () {
    final ProtectedPaths paths =
        ProtectedPaths.of(TargetPlatform.android, androidRoots);

    test('refuses the camera roll and the other media folders', () {
      expect(paths.contains('/storage/emulated/0/DCIM/Camera/IMG.jpg'), isTrue);
      expect(paths.contains('/storage/emulated/0/Pictures/shot.png'), isTrue);
      expect(paths.contains('/storage/emulated/0/Documents/cv.pdf'), isTrue);
    });

    test("refuses other apps' sandboxes, which are unreadable anyway", () {
      expect(
        paths.contains('/storage/emulated/0/Android/data/com.other/cache'),
        isTrue,
      );
      expect(paths.contains('/system/build.prop'), isTrue);
    });

    test('allows the thumbnail caches inside the protected media folders', () {
      // The one exception in the whole file, and the reason exceptions exist.
      expect(
        paths.contains('/storage/emulated/0/DCIM/.thumbnails/1234.jpg'),
        isFalse,
      );
      expect(
        paths.contains('/storage/emulated/0/Pictures/.thumbnails/5678.jpg'),
        isFalse,
      );
    });

    test('the exception is exactly that directory and nothing beside it', () {
      expect(
        paths.contains('/storage/emulated/0/DCIM/.thumbnails-backup/x.jpg'),
        isTrue,
      );
      expect(paths.contains('/storage/emulated/0/DCIM/thumbnails/x.jpg'), isTrue);
    });

    test('allows Download, which is where the rules look', () {
      expect(
        paths.contains('/storage/emulated/0/Download/setup.apk'),
        isFalse,
      );
    });

    test("allows the app's own cache, which /data would otherwise swallow", () {
      expect(paths.contains('${androidRoots.appCache}/blob'), isFalse);
    });

    test("still protects the app's own quarantine beside it", () {
      expect(paths.contains('${androidRoots.appSupport}/quarantine'), isTrue);
    });
  });

  group('iOS', () {
    final ProtectedPaths paths =
        ProtectedPaths.of(TargetPlatform.iOS, androidRoots);

    test("protects only the app's own support directory", () {
      expect(paths.contains(androidRoots.appSupport), isTrue);
      expect(paths.contains(androidRoots.appCache), isFalse);
    });
  });

  test('a root that could not be resolved contributes nothing', () {
    const CleanerRoots empty = CleanerRoots(
      appCache: '/cache',
      appSupport: '/support',
    );
    final ProtectedPaths paths =
        ProtectedPaths.of(TargetPlatform.windows, empty);

    // No home and no Windows directory, so those entries are simply absent
    // rather than rooted at something guessed.
    expect(paths.contains(r'C:\Users\tester\Documents'), isFalse);
    expect(paths.contains('/support/quarantine'), isTrue);
  });
}
