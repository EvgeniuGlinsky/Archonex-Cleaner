import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:archonex_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/rules/cleaner_roots.dart';

/// Turns "this machine" into the paths the rule tables are written against.
///
/// Every question that needs the file system or a plugin is asked here and
/// nowhere else, which is what keeps the four rule tables pure — and what lets
/// the Windows rules be tested from Linux CI by handing in a `CleanerRoots`
/// literal.
///
/// A missing environment variable is left `null` rather than guessed at. A rule
/// pointing at a guessed path is a rule pointing at somebody's data.
class CleanerRootsResolver {
  const CleanerRootsResolver({TargetPlatform? platform})
      : _platformOverride = platform;

  /// Only set by tests. The app always asks the framework.
  final TargetPlatform? _platformOverride;

  TargetPlatform get _platform => _platformOverride ?? defaultTargetPlatform;

  Future<CleanerRoots> resolve(StorageAccess access) async {
    final Directory cache = await getTemporaryDirectory();
    final Directory support = await getApplicationSupportDirectory();

    return CleanerRoots(
      appCache: cache.path,
      appSupport: support.path,
      externalAppCaches: await _externalAppCaches(),
      home: _home,
      systemTemp: _systemTemp,
      localAppData: _environment('LOCALAPPDATA'),
      roamingAppData: _environment('APPDATA'),
      windowsDirectory: _windowsDirectory,
      externalStorage: await _externalStorage(),
      grantedFolders: access.grantedRoots,
    );
  }

  /// Android's per-volume cache directories — internal storage and an SD card
  /// where one is fitted. Ours to empty on every one of them.
  Future<List<String>> _externalAppCaches() async {
    if (_platform != TargetPlatform.android) {
      return const <String>[];
    }

    final List<Directory>? caches = await getExternalCacheDirectories();

    return caches?.map((directory) => directory.path).toList(growable: false) ??
        const <String>[];
  }

  /// `/storage/emulated/0`, derived rather than hard-coded.
  ///
  /// `getExternalStorageDirectory()` answers
  /// `/storage/emulated/0/Android/data/<package>/files`, and the shared root is
  /// everything before `/Android/`. Deriving it survives a device that mounts
  /// its primary volume somewhere else, which a hard-coded path does not — and
  /// the hard-coded path is the fallback for the device that answers nothing.
  Future<String?> _externalStorage() async {
    if (_platform != TargetPlatform.android) {
      return null;
    }

    const String fallback = '/storage/emulated/0';
    final Directory? external = await getExternalStorageDirectory();

    if (external == null) {
      return fallback;
    }

    final int marker = external.path.indexOf('/Android/');

    return marker > 0 ? external.path.substring(0, marker) : fallback;
  }

  String? get _home {
    // Neither mobile platform has a home directory that means anything to an
    // app: what `HOME` answers there is the sandbox, which the app-cache rules
    // already cover by name.
    if (_platform == TargetPlatform.android || _platform == TargetPlatform.iOS) {
      return null;
    }

    return _environment('USERPROFILE') ?? _environment('HOME');
  }

  String? get _systemTemp {
    if (_platform == TargetPlatform.android || _platform == TargetPlatform.iOS) {
      return null;
    }

    // `Directory.systemTemp` reads the same variables and falls back to a
    // sensible default, which is the one guess worth making: every platform
    // guarantees the directory exists.
    return Directory.systemTemp.path;
  }

  String? get _windowsDirectory {
    if (_platform != TargetPlatform.windows) {
      return null;
    }

    final String? fromEnvironment =
        _environment('SystemRoot') ?? _environment('windir');

    if (fromEnvironment != null) {
      return fromEnvironment;
    }

    final String? systemDrive = _environment('SystemDrive');

    return systemDrive == null
        ? null
        : p.windows.join(systemDrive, r'\', 'Windows');
  }

  /// Reads an environment variable, treating blank as absent.
  ///
  /// A variable set to the empty string produces a rule rooted at the current
  /// directory, which is the worst possible place to start deleting from.
  String? _environment(String name) {
    final String? value = Platform.environment[name];

    return value == null || value.trim().isEmpty ? null : value;
  }
}
