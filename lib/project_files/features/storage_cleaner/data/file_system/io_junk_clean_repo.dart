import 'dart:async';
import 'dart:io';

import 'package:archonex_cleaner/project_files/features/quarantine/domain/models/quarantine_batch.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/domain/quarantine_repo.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/domain/quarantine_writer.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/junk_clean_repo.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/clean_job.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/clean_report.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/clean_update.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_item.dart';

/// The real deleter, on `dart:io`.
///
/// It decides nothing about *what* goes — the list it is handed is the list the
/// guard already approved during the scan — and only how: aside, or for good.
class IoJunkCleanRepo implements JunkCleanRepo {
  const IoJunkCleanRepo({required QuarantineRepo quarantine})
      : _quarantine = quarantine;

  final QuarantineRepo _quarantine;

  @override
  bool get isSupported => true;

  @override
  CleanJob clean({
    required List<JunkItem> items,
    bool quarantine = true,
  }) {
    return _IoCleanJob(
      items: items,
      openBatch: quarantine ? _quarantine.openBatch : null,
    );
  }
}

/// One deletion queue, strictly one file at a time.
///
/// Sequential on purpose. Deleting is bounded by the file system rather than by
/// the CPU, so parallel workers buy nothing, and they would turn cancellation
/// from "stop after this one" into "stop after however many are in flight" —
/// on the one operation in the app that cannot be undone by stopping.
class _IoCleanJob implements CleanJob {
  _IoCleanJob({
    required List<JunkItem> items,
    required Future<QuarantineWriter> Function()? openBatch,
  })  : _items = items,
        _openBatch = openBatch {
    _controller = StreamController<CleanUpdate>(onListen: _start);
  }

  final List<JunkItem> _items;
  final Future<QuarantineWriter> Function()? _openBatch;

  late final StreamController<CleanUpdate> _controller;

  bool _isCancelling = false;

  int _freedBytes = 0;
  int _quarantinedCount = 0;
  int _permanentCount = 0;
  int _skippedCount = 0;

  @override
  Stream<CleanUpdate> get updates => _controller.stream;

  @override
  Future<void> cancel() async {
    _isCancelling = true;
  }

  Future<void> _start() async {
    final QuarantineWriter? writer = await _open();

    int done = 0;

    for (final JunkItem item in _items) {
      if (_isCancelling || _controller.isClosed) {
        break;
      }

      await _remove(item, writer);
      done++;

      _emit(
        CleanProgress(
          doneCount: done,
          totalCount: _items.length,
          freedBytes: _freedBytes,
        ),
      );
    }

    final QuarantineBatch? batch = await writer?.commit();

    _emit(
      CleanFinished(
        CleanReport(
          freedBytes: _freedBytes,
          quarantinedCount: _quarantinedCount,
          permanentCount: _permanentCount,
          skippedCount: _skippedCount,
          batchId: batch?.id,
          wasCancelled: _isCancelling,
        ),
      ),
    );

    if (!_controller.isClosed) {
      await _controller.close();
    }
  }

  /// Opening the batch is allowed to fail: a quarantine directory that cannot
  /// be created costs the undo, not the cleanup, and the run continues with
  /// every file counted as permanent — which is what the report will say.
  Future<QuarantineWriter?> _open() async {
    final Future<QuarantineWriter> Function()? open = _openBatch;

    if (open == null) {
      return null;
    }

    try {
      return await open();
    } on FileSystemException {
      return null;
    }
  }

  Future<void> _remove(JunkItem item, QuarantineWriter? writer) async {
    if (writer != null && await writer.keep(item)) {
      _freedBytes += item.sizeInBytes;
      _quarantinedCount++;

      return;
    }

    if (await _delete(item)) {
      _freedBytes += item.sizeInBytes;
      _permanentCount++;

      return;
    }

    // Locked by a running process, almost always. Counted rather than reported
    // per file: a Windows cleanup routinely skips a handful, and one banner per
    // file would bury the result.
    _skippedCount++;
  }

  static Future<bool> _delete(JunkItem item) async {
    try {
      if (item.isDirectory) {
        final Directory directory = Directory(item.path);

        if (!await directory.exists()) {
          return false;
        }

        await directory.delete(recursive: true);

        return true;
      }

      final File file = File(item.path);

      if (!await file.exists()) {
        return false;
      }

      await file.delete();

      return true;
    } on FileSystemException {
      return false;
    }
  }

  void _emit(CleanUpdate update) {
    if (!_controller.isClosed) {
      _controller.add(update);
    }
  }
}
