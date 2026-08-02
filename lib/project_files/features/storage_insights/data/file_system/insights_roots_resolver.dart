import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:storage_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';

/// Where to start counting.
///
/// A resolver of its own, thirty lines long, rather than a reach into
/// `CleanerRootsResolver`. That one answers a dozen questions this feature does
/// not ask — where the browser caches are, what `%LOCALAPPDATA%` is — and
/// importing it here would point an arrow sideways between two features for the
/// sake of one field. The one thing they agree on, deriving Android's shared
/// root from the app's own directory, is short enough to say twice.
class InsightsRootsResolver {
  const InsightsRootsResolver({TargetPlatform? platform})
      : _platformOverride = platform;

  final TargetPlatform? _platformOverride;

  TargetPlatform get _platform => _platformOverride ?? defaultTargetPlatform;

  /// The folders to walk, deduplicated by the caller's own ordering.
  ///
  /// One on a phone with all-files access — the shared volume, which is
  /// everything an app is allowed to see. Without that access it is whatever
  /// the user handed over through the picker, and the chart says as much rather
  /// than pretending to describe the disk.
  Future<List<String>> resolve(StorageAccess access) async {
    final List<String> granted = access.grantedRoots;

    if (!access.canScan) {
      return const <String>[];
    }

    final String? volume = switch (_platform) {
      TargetPlatform.android => await _androidVolume(),
      TargetPlatform.windows ||
      TargetPlatform.linux ||
      TargetPlatform.macOS =>
        _home,
      // iOS sees its own container and nothing else, and a chart of that would
      // describe the app rather than the phone. Fuchsia has no runner.
      TargetPlatform.iOS || TargetPlatform.fuchsia => null,
    };

    if (access.level != StorageAccessLevel.full || volume == null) {
      return List<String>.unmodifiable(granted);
    }

    return List<String>.unmodifiable(<String>[volume]);
  }

  /// `/storage/emulated/0`, derived rather than hard-coded.
  ///
  /// `getExternalStorageDirectory()` answers
  /// `/storage/emulated/0/Android/data/<package>/files`, and the shared root is
  /// everything before `/Android/`. The literal is the fallback for a device
  /// that answers nothing — the same arrangement `CleanerRootsResolver` makes,
  /// and the one thing worth repeating between them.
  Future<String?> _androidVolume() async {
    const String fallback = '/storage/emulated/0';
    final Directory? external = await getExternalStorageDirectory();

    if (external == null) {
      return fallback;
    }

    final int marker = external.path.indexOf('/Android/');

    return marker > 0 ? external.path.substring(0, marker) : fallback;
  }

  String? get _home =>
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
}
