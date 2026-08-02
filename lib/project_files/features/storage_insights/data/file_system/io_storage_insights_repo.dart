import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:storage_cleaner/core/constants/app_insights_policy.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/data/file_system/insights_roots_resolver.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/data/rules/slice_ruleset.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/insights_failure.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/insights_scan_job.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/insights_update.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/storage_slice.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/storage_insights_repo.dart';

/// Walks the volume and adds up what is on it.
///
/// The cheapest walk in the app by a wide margin: a `stat` and a look at the
/// last dot in the name, never an open. That is what makes measuring a whole
/// phone reasonable when measuring the camera roll alone takes the optimiser a
/// couple of minutes.
///
/// It reads and never writes, so it needs none of the ladders and guards the
/// other two are built around. There is no `DeletionGuard` here and no
/// `ProtectedPaths`: the worst thing a bug in this file can do is draw a chart
/// with a slice in the wrong place.
class IoStorageInsightsRepo implements StorageInsightsRepo {
  IoStorageInsightsRepo({
    InsightsRootsResolver? resolver,
    TargetPlatform? platform,
  })  : _resolver = resolver ?? InsightsRootsResolver(platform: platform),
        _platform = platform ?? defaultTargetPlatform;

  final InsightsRootsResolver _resolver;
  final TargetPlatform _platform;

  /// iOS sees only its own container, which describes the app rather than the
  /// phone. Fuchsia has no runner.
  @override
  bool get isSupported =>
      _platform != TargetPlatform.iOS && _platform != TargetPlatform.fuchsia;

  @override
  Future<InsightsScanJob> measure(StorageAccess access) async {
    return _IoInsightsScanJob(roots: await _resolver.resolve(access));
  }
}

class _IoInsightsScanJob implements InsightsScanJob {
  _IoInsightsScanJob({required List<String> roots}) : _roots = roots {
    _controller = StreamController<InsightsUpdate>(onListen: _start);
  }

  final List<String> _roots;

  late final StreamController<InsightsUpdate> _controller;

  /// Totals since the last flush, not since the start. The bloc accumulates.
  final Map<StorageSliceCategory, StorageSlice> _batch =
      <StorageSliceCategory, StorageSlice>{};

  Timer? _flushTimer;
  int _inBatch = 0;
  int _measured = 0;
  bool _isCancelling = false;

  @override
  Stream<InsightsUpdate> get updates => _controller.stream;

  /// Cooperative, like every other cancel in this app: a flag the loop reads
  /// once per file rather than an interruption. There is nothing half-done to
  /// tidy up, because nothing was written.
  @override
  Future<void> cancel() async {
    _isCancelling = true;
  }

  Future<void> _start() async {
    try {
      for (final String root in _roots) {
        if (_isCancelling) {
          break;
        }

        _emit(InsightsLocationChanged(p.basename(root)));
        await _walk(Directory(root), 0);
      }
    } on Object {
      _flush();

      if (!_controller.isClosed) {
        _controller.addError(const InsightsScanFailure());
        await _controller.close();
      }

      return;
    }

    _flush();

    if (_controller.isClosed) {
      return;
    }

    if (_isCancelling) {
      // Ended with a failure rather than closed with a partial answer, which is
      // how every cancelled *scan* in this app ends. Half a disk measured is a
      // chart that adds up to nothing anybody can act on.
      _controller.addError(const InsightsScanCancelledFailure());
    }

    await _controller.close();
  }

  Future<void> _walk(Directory directory, int depth) async {
    if (_isCancelling ||
        depth > AppInsightsPolicy.maxScanDepth ||
        _measured >= AppInsightsPolicy.maxFiles) {
      return;
    }

    final List<FileSystemEntity> entries;

    try {
      entries = await directory.list(followLinks: false).toList();
    } on FileSystemException {
      // Unreadable, which on Android is most of `Android/data` and is the
      // normal case rather than an error. Its bytes end up in the `system`
      // slice, which is exactly what that slice is for.
      return;
    }

    for (final FileSystemEntity entry in entries) {
      if (_isCancelling || _measured >= AppInsightsPolicy.maxFiles) {
        if (_measured >= AppInsightsPolicy.maxFiles) {
          _emit(const InsightsTruncated());
        }

        return;
      }

      if (entry is Directory) {
        await _walk(entry, depth + 1);

        continue;
      }

      if (entry is! File) {
        // A symlink, or a socket, or a device node. Not a byte anybody put
        // there, and following one is how a walk leaves the volume.
        continue;
      }

      await _measure(entry);
    }
  }

  Future<void> _measure(File file) async {
    final int size;

    try {
      size = await file.length();
    } on FileSystemException {
      return;
    }

    if (size <= 0) {
      return;
    }

    final StorageSliceCategory category =
        SliceRuleset.categoryOf(p.basename(file.path));

    _batch[category] =
        (_batch[category] ?? StorageSlice(category: category, bytes: 0))
            .plus(bytes: size);

    _measured++;
    _inBatch++;

    if (_inBatch >= AppInsightsPolicy.measuredBatchSize) {
      _flush();

      return;
    }

    // The tail of a walk is a few hundred files that would otherwise sit unsent
    // while the chart shows a figure a second out of date.
    _flushTimer ??= Timer(
      AppInsightsPolicy.measuredFlushInterval,
      _flush,
    );
  }

  void _flush() {
    _flushTimer?.cancel();
    _flushTimer = null;

    if (_batch.isEmpty) {
      return;
    }

    _emit(InsightsMeasured(_batch.values.toList(growable: false)));
    _batch.clear();
    _inBatch = 0;
  }

  void _emit(InsightsUpdate update) {
    if (!_controller.isClosed) {
      _controller.add(update);
    }
  }
}
