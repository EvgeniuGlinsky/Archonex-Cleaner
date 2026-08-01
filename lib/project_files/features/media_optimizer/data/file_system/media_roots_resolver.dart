import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:archonex_cleaner/project_files/features/media_optimizer/data/rules/media_roots.dart';
import 'package:archonex_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';

/// Works out where this machine keeps the user's photographs and videos.
///
/// The one impure file in the feature's data layer, and the counterpart to
/// `CleanerRootsResolver`. Everything that reads `Platform.environment`, calls
/// `path_provider` or knows what a home directory looks like is here, so that
/// `MediaRuleset` and `OffLimitsPaths` can be pure tables tested from whichever
/// platform CI runs on.
///
/// A folder that is not there is answered as `null` rather than as a path that
/// happens not to exist, and the rule for it is dropped. The difference matters
/// on Linux, where the media folders are whatever `xdg-user-dirs` says and a
/// machine that has never run a desktop session has none of them.
class MediaRootsResolver {
  const MediaRootsResolver({TargetPlatform? platform}) : _platformOverride = platform;

  final TargetPlatform? _platformOverride;

  TargetPlatform get _platform => _platformOverride ?? defaultTargetPlatform;

  Future<MediaRoots> resolve(StorageAccess access) async {
    final Directory support = await getApplicationSupportDirectory();
    final List<String> granted = List<String>.unmodifiable(access.grantedRoots);

    return switch (_platform) {
      TargetPlatform.android => _android(support.path, granted),
      TargetPlatform.windows => _windows(support.path, granted),
      TargetPlatform.macOS => _macOS(support.path, granted),
      TargetPlatform.linux => _linux(support.path, granted),
      // Nothing the user put there is reachable, so there is nothing to
      // resolve. `UnsupportedMediaScanRepo` answers long before this is called.
      TargetPlatform.iOS || TargetPlatform.fuchsia => MediaRoots(
          appSupport: support.path,
          grantedFolders: granted,
        ),
    };
  }

  /// Shared storage, whose layout has been the same since Android 4.
  ///
  /// `/storage/emulated/0` is hardcoded rather than asked for, because the API
  /// that answers it — `getExternalStorageDirectory` — is deprecated, returns
  /// the app's own scoped directory on modern Android, and would point every
  /// rule at a folder holding nothing the user put there.
  static MediaRoots _android(String support, List<String> granted) {
    const String external = '/storage/emulated/0';

    return MediaRoots(
      appSupport: support,
      externalStorage: external,
      camera: p.posix.join(external, 'DCIM'),
      pictures: p.posix.join(external, 'Pictures'),
      videos: p.posix.join(external, 'Movies'),
      downloads: p.posix.join(external, 'Download'),
      screenshots: p.posix.join(external, 'Pictures', 'Screenshots'),
      grantedFolders: granted,
    );
  }

  static MediaRoots _windows(String support, List<String> granted) {
    final String? home = Platform.environment['USERPROFILE'];

    return MediaRoots(
      appSupport: support,
      home: home,
      pictures: _existing(home, 'Pictures'),
      videos: _existing(home, 'Videos'),
      downloads: _existing(home, 'Downloads'),
      grantedFolders: granted,
    );
  }

  /// macOS calls the videos folder `Movies`, and has since before it was
  /// macOS.
  static MediaRoots _macOS(String support, List<String> granted) {
    final String? home = Platform.environment['HOME'];

    return MediaRoots(
      appSupport: support,
      home: home,
      pictures: _existing(home, 'Pictures'),
      videos: _existing(home, 'Movies'),
      downloads: _existing(home, 'Downloads'),
      grantedFolders: granted,
    );
  }

  /// The folders here are conventions rather than guarantees — they come from
  /// `xdg-user-dirs` and can be renamed, translated or absent — so each is
  /// checked before it is offered.
  static MediaRoots _linux(String support, List<String> granted) {
    final String? home = Platform.environment['HOME'];

    return MediaRoots(
      appSupport: support,
      home: home,
      pictures: _existing(home, 'Pictures'),
      videos: _existing(home, 'Videos'),
      downloads: _existing(home, 'Downloads'),
      grantedFolders: granted,
    );
  }

  /// The joined path if the directory is really there, and `null` otherwise.
  ///
  /// Checked synchronously, which is the one place in the app that is
  /// acceptable: this runs once per scan, off the build, and the alternative is
  /// four awaited existence checks to save nothing measurable.
  static String? _existing(String? home, String folder) {
    if (home == null || home.isEmpty) {
      return null;
    }

    final String path = p.join(home, folder);

    return Directory(path).existsSync() ? path : null;
  }
}
