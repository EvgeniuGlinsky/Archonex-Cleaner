import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:archonex_cleaner/project_files/features/quarantine/domain/models/quarantine_batch.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/domain/models/quarantine_entry.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/domain/quarantine_repo.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/domain/quarantine_writer.dart';
import 'package:archonex_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/junk_clean_repo.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/junk_scan_repo.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/clean_job.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/clean_report.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/clean_update.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_category.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_item.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/scan_job.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/scan_update.dart';

/// Hand-written fakes for the cleaner. There is no mocking package in this
/// project and none is to be added — see `CLAUDE.md`.
///
/// Every one of these fakes a `domain/` interface, never a `data/`
/// implementation, which is what lets the rules be driven without a file
/// system anywhere near them.

/// A finding, with everything but the interesting field defaulted.
JunkItem fakeItem({
  String path = '/tmp/a.tmp',
  String? name,
  int sizeInBytes = 1024,
  JunkCategory category = JunkCategory.systemTemp,
  DateTime? modifiedAt,
  bool isDirectory = false,
}) {
  return JunkItem(
    path: path,
    name: name ?? path.split('/').last,
    sizeInBytes: sizeInBytes,
    category: category,
    modifiedAt: modifiedAt ?? DateTime.utc(2026, 1, 1),
    isDirectory: isDirectory,
  );
}

class FakeJunkScanRepo implements JunkScanRepo {
  FakeJunkScanRepo({
    this.isSupported = true,
    this.categories = const <JunkCategory>{
      JunkCategory.systemTemp,
      JunkCategory.browserCache,
    },
    this.updates = const <ScanUpdate>[],
    this.failure,
    this.holdOpen = false,
  });

  @override
  bool isSupported;

  Set<JunkCategory> categories;

  /// Emitted in order, then the stream closes.
  List<ScanUpdate> updates;

  /// Ends the stream with this instead of closing it.
  Object? failure;

  /// Leaves the stream open after the updates, so a test can observe a scan
  /// that is still running — which is the only way to check that closing the
  /// bloc stops one.
  bool holdOpen;

  int scanCount = 0;
  Set<JunkCategory>? lastRequestedCategories;

  /// Completes when the job has been cancelled.
  bool wasCancelled = false;

  @override
  Future<Set<JunkCategory>> categoriesFor(StorageAccess access) async =>
      categories;

  @override
  Future<ScanJob> scan({
    required Set<JunkCategory> categories,
    required StorageAccess access,
  }) async {
    scanCount++;
    lastRequestedCategories = categories;

    return FakeScanJob(
      updates: updates,
      failure: failure,
      holdOpen: holdOpen,
      onCancel: () => wasCancelled = true,
    );
  }
}

class FakeScanJob implements ScanJob {
  FakeScanJob({
    required List<ScanUpdate> updates,
    Object? failure,
    bool holdOpen = false,
    void Function()? onCancel,
  })  : _updates = updates,
        _failure = failure,
        _holdOpen = holdOpen,
        _onCancel = onCancel {
    _controller = StreamController<ScanUpdate>(onListen: _start);
  }

  final List<ScanUpdate> _updates;
  final Object? _failure;
  final bool _holdOpen;
  final void Function()? _onCancel;

  late final StreamController<ScanUpdate> _controller;

  @override
  Stream<ScanUpdate> get updates => _controller.stream;

  @override
  Future<void> cancel() async {
    _onCancel?.call();

    if (!_controller.isClosed) {
      _controller.addError(const _Cancelled());
      await _controller.close();
    }
  }

  /// Nothing is emitted until something listens, exactly as the real job does.
  Future<void> _start() async {
    for (final ScanUpdate update in _updates) {
      if (_controller.isClosed) {
        return;
      }

      _controller.add(update);
    }

    if (_controller.isClosed) {
      return;
    }

    if (_failure != null) {
      _controller.addError(_failure);
    }

    if (_holdOpen) {
      return;
    }

    await _controller.close();
  }
}

/// Stands in for `ScanCancelledFailure` without the fake importing it — the
/// bloc maps anything that is not a `CleanFailure` to `ScanFailure`, and the
/// tests that care about cancellation set `failure` explicitly.
class _Cancelled implements Exception {
  const _Cancelled();
}

class FakeJunkCleanRepo implements JunkCleanRepo {
  FakeJunkCleanRepo({
    this.isSupported = true,
    this.report = const CleanReport(freedBytes: 2048, quarantinedCount: 2),
    this.failure,
  });

  @override
  bool isSupported;

  /// Reported by the `CleanFinished` the job ends with.
  CleanReport report;

  /// Ends the stream with this instead of finishing.
  Object? failure;

  List<JunkItem>? lastItems;
  bool? lastQuarantineFlag;
  bool wasCancelled = false;

  @override
  CleanJob clean({required List<JunkItem> items, bool quarantine = true}) {
    lastItems = items;
    lastQuarantineFlag = quarantine;

    return FakeCleanJob(
      items: items,
      report: report,
      failure: failure,
      onCancel: () => wasCancelled = true,
    );
  }
}

class FakeCleanJob implements CleanJob {
  FakeCleanJob({
    required List<JunkItem> items,
    required CleanReport report,
    Object? failure,
    void Function()? onCancel,
  })  : _items = items,
        _report = report,
        _failure = failure,
        _onCancel = onCancel {
    _controller = StreamController<CleanUpdate>(onListen: _start);
  }

  final List<JunkItem> _items;
  final CleanReport _report;
  final Object? _failure;
  final void Function()? _onCancel;

  late final StreamController<CleanUpdate> _controller;

  @override
  Stream<CleanUpdate> get updates => _controller.stream;

  @override
  Future<void> cancel() async {
    _onCancel?.call();
  }

  Future<void> _start() async {
    if (_failure != null) {
      _controller.addError(_failure);
      await _controller.close();

      return;
    }

    for (int index = 0; index < _items.length; index++) {
      _controller.add(
        CleanProgress(
          doneCount: index + 1,
          totalCount: _items.length,
          freedBytes: _items[index].sizeInBytes * (index + 1),
        ),
      );
    }

    _controller.add(CleanFinished(_report));
    await _controller.close();
  }
}

class FakeQuarantineRepo implements QuarantineRepo {
  FakeQuarantineRepo({List<QuarantineBatch> batches = const <QuarantineBatch>[]})
      : _batches = ValueNotifier<List<QuarantineBatch>>(batches);

  final ValueNotifier<List<QuarantineBatch>> _batches;

  /// Thrown by the next `restore()`. Cleared once thrown.
  Object? restoreFailure;

  int loadCount = 0;
  int purgeExpiredCount = 0;
  final List<String> restored = <String>[];
  final List<String> purged = <String>[];
  bool purgedAll = false;

  @override
  ValueListenable<List<QuarantineBatch>> get batchesListenable => _batches;

  void publish(List<QuarantineBatch> batches) => _batches.value = batches;

  @override
  Future<void> load() async => loadCount++;

  @override
  Future<QuarantineWriter> openBatch() async => FakeQuarantineWriter();

  @override
  Future<void> restore(String batchId) async {
    final Object? failure = restoreFailure;
    restoreFailure = null;

    if (failure != null) {
      throw failure;
    }

    restored.add(batchId);
    publish(
      _batches.value.where((batch) => batch.id != batchId).toList(
            growable: false,
          ),
    );
  }

  @override
  Future<void> purge(String batchId) async {
    purged.add(batchId);
    publish(
      _batches.value.where((batch) => batch.id != batchId).toList(
            growable: false,
          ),
    );
  }

  @override
  Future<void> purgeAll() async {
    purgedAll = true;
    publish(const <QuarantineBatch>[]);
  }

  @override
  Future<void> purgeExpired() async => purgeExpiredCount++;
}

/// Keeps everything offered to it, so a test can tell "the deleter offered it"
/// apart from "the quarantine took it".
class FakeQuarantineWriter implements QuarantineWriter {
  final List<JunkItem> kept = <JunkItem>[];

  /// Set false to make every offer fall through to a permanent delete.
  bool accepts = true;

  @override
  Future<bool> keep(JunkItem item) async {
    if (!accepts) {
      return false;
    }

    kept.add(item);

    return true;
  }

  @override
  Future<QuarantineBatch?> commit() async {
    if (kept.isEmpty) {
      return null;
    }

    return QuarantineBatch(
      id: 'batch',
      createdAt: DateTime.utc(2026, 7, 31),
      entries: kept
          .map(
            (item) => QuarantineEntry(
              originalPath: item.path,
              storedName: item.name,
              sizeInBytes: item.sizeInBytes,
              category: item.category,
              wasDirectory: item.isDirectory,
            ),
          )
          .toList(growable: false),
    );
  }
}

QuarantineBatch fakeBatch({
  String id = 'batch',
  DateTime? createdAt,
  int fileCount = 3,
  int sizeEach = 1024,
}) {
  return QuarantineBatch(
    id: id,
    createdAt: createdAt ?? DateTime.utc(2026, 7, 31),
    entries: List<QuarantineEntry>.generate(
      fileCount,
      (index) => QuarantineEntry(
        originalPath: '/tmp/file-$index.tmp',
        storedName: '${index}_file-$index.tmp',
        sizeInBytes: sizeEach,
        category: JunkCategory.systemTemp,
      ),
    ),
  );
}
