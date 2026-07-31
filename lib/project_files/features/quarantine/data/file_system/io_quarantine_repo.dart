import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:archonex_cleaner/core/constants/app_quarantine_policy.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/data/file_system/quarantine_manifest.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/domain/models/restore_failure.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_item.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/domain/models/quarantine_batch.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/domain/models/quarantine_entry.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/domain/quarantine_repo.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/domain/quarantine_writer.dart';

/// The undo, on `dart:io`.
///
/// Files are **moved**, never copied. That is the whole design: a copy frees no
/// space, and freeing space is what the user pressed the button for. Where a
/// move is impossible — another volume, a file above
/// `AppQuarantinePolicy.maxEntryBytes` — the writer declines and the caller
/// deletes outright, which the report counts separately so nobody is told they
/// can undo something they cannot.
///
/// The clock is injectable for the same reason `UsageQuotaRepoImpl`'s is in the
/// Converter: a seven-day retention is otherwise untestable without waiting a
/// week.
class IoQuarantineRepo implements QuarantineRepo {
  IoQuarantineRepo({
    DateTime Function()? now,
    Directory? directory,
  })  : _now = now ?? DateTime.now,
        _directoryOverride = directory;

  final DateTime Function() _now;

  /// Set by tests to a temporary directory. The app resolves it from
  /// `path_provider`.
  final Directory? _directoryOverride;

  final ValueNotifier<List<QuarantineBatch>> _batches =
      ValueNotifier<List<QuarantineBatch>>(const <QuarantineBatch>[]);

  Directory? _resolved;

  @override
  ValueListenable<List<QuarantineBatch>> get batchesListenable => _batches;

  @override
  Future<void> load() async {
    final Directory directory = await _directory();
    final File manifest = _manifestFile(directory);

    if (!await manifest.exists()) {
      _publish(const <QuarantineBatch>[]);

      return;
    }

    try {
      _publish(QuarantineManifest.decode(await manifest.readAsString()));
    } on FileSystemException {
      // A manifest that cannot be read leaves the files on disk and the app
      // with no idea what they were. Reporting nothing is the honest state; the
      // directory is reclaimed by the next expiry sweep it survives into.
      _publish(const <QuarantineBatch>[]);
    }
  }

  @override
  Future<QuarantineWriter> openBatch() async {
    final Directory directory = await _directory();

    return _IoQuarantineWriter(
      id: _newBatchId(),
      root: directory,
      budgetBytes: await _freeBudget(),
      createdAt: _now(),
      onCommit: _add,
    );
  }

  @override
  Future<void> restore(String batchId) async {
    final QuarantineBatch? batch = _find(batchId);

    if (batch == null) {
      return;
    }

    final Directory root = await _directory();
    final Directory batchDirectory = Directory(p.join(root.path, batch.id));

    // Every destination is checked before anything moves. Half a restore is the
    // one outcome worse than none: the user is left not knowing which files
    // came back.
    for (final QuarantineEntry entry in batch.entries) {
      if (await _exists(entry.originalPath)) {
        throw RestoreTargetOccupiedFailure(path: entry.originalPath);
      }
    }

    int restored = 0;
    int lost = 0;

    for (final QuarantineEntry entry in batch.entries) {
      final String stored = p.join(batchDirectory.path, entry.storedName);

      if (await _move(stored, entry.originalPath, entry.wasDirectory)) {
        restored++;
      } else {
        lost++;
      }
    }

    await _deleteDirectory(batchDirectory);
    await _forget(batch.id);

    if (lost > 0) {
      throw PartialRestoreFailure(restoredCount: restored, lostCount: lost);
    }
  }

  @override
  Future<void> purge(String batchId) async {
    final Directory root = await _directory();

    await _deleteDirectory(Directory(p.join(root.path, batchId)));
    await _forget(batchId);
  }

  @override
  Future<void> purgeAll() async {
    for (final QuarantineBatch batch in _batches.value) {
      await purge(batch.id);
    }
  }

  @override
  Future<void> purgeExpired() async {
    final DateTime now = _now();

    for (final QuarantineBatch batch in _batches.value) {
      if (batch.isExpiredAt(now)) {
        await purge(batch.id);
      }
    }
  }

  /// Room left under `AppQuarantinePolicy.maxTotalBytes`.
  ///
  /// Never negative: a quarantine already over budget — which only a changed
  /// constant can produce — offers a new batch nothing rather than a negative
  /// allowance the writer would read as unlimited.
  Future<int> _freeBudget() async {
    final int used = _batches.value.fold(
      0,
      (sum, batch) => sum + batch.totalBytes,
    );

    return (AppQuarantinePolicy.maxTotalBytes - used).clamp(
      0,
      AppQuarantinePolicy.maxTotalBytes,
    );
  }

  /// Sortable and collision-free without a random source: microseconds, base 36.
  String _newBatchId() => _now().microsecondsSinceEpoch.toRadixString(36);

  QuarantineBatch? _find(String batchId) {
    for (final QuarantineBatch batch in _batches.value) {
      if (batch.id == batchId) {
        return batch;
      }
    }

    return null;
  }

  Future<void> _add(QuarantineBatch batch) async {
    _publish(<QuarantineBatch>[batch, ..._batches.value]);
    await _write();
  }

  Future<void> _forget(String batchId) async {
    _publish(
      _batches.value
          .where((batch) => batch.id != batchId)
          .toList(growable: false),
    );
    await _write();
  }

  /// Newest first, which is the order the screen shows and the order
  /// [purgeAll] walks.
  void _publish(List<QuarantineBatch> batches) {
    final List<QuarantineBatch> sorted = <QuarantineBatch>[...batches]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    _batches.value = List<QuarantineBatch>.unmodifiable(sorted);
  }

  Future<void> _write() async {
    final Directory directory = await _directory();

    try {
      await _manifestFile(directory)
          .writeAsString(QuarantineManifest.encode(_batches.value));
    } on FileSystemException {
      // The files are already moved. A manifest that will not write costs the
      // user the undo, not the cleanup, and there is nothing to tell them that
      // they could act on.
    }
  }

  Future<Directory> _directory() async {
    final Directory? cached = _resolved;

    if (cached != null) {
      return cached;
    }

    final Directory root = _directoryOverride ??
        Directory(
          p.join(
            (await getApplicationSupportDirectory()).path,
            AppQuarantinePolicy.directoryName,
          ),
        );

    if (!await root.exists()) {
      await root.create(recursive: true);
    }

    _resolved = root;

    return root;
  }

  static File _manifestFile(Directory root) =>
      File(p.join(root.path, AppQuarantinePolicy.manifestName));

  static Future<bool> _exists(String path) async =>
      await File(path).exists() || await Directory(path).exists();

  /// Moves [from] to [to], creating the parent. `false` when the source is gone.
  static Future<bool> _move(String from, String to, bool isDirectory) async {
    try {
      final Directory parent = Directory(p.dirname(to));

      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }

      if (isDirectory) {
        if (!await Directory(from).exists()) {
          return false;
        }

        await Directory(from).rename(to);

        return true;
      }

      if (!await File(from).exists()) {
        return false;
      }

      await File(from).rename(to);

      return true;
    } on FileSystemException {
      return false;
    }
  }

  static Future<void> _deleteDirectory(Directory directory) async {
    try {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } on FileSystemException {
      // Best effort. A leftover batch directory with no manifest row costs
      // disk, not correctness, and the next purge picks it up.
    }
  }
}

/// One open batch. Lives for the length of a cleanup and is then committed.
class _IoQuarantineWriter implements QuarantineWriter {
  _IoQuarantineWriter({
    required String id,
    required Directory root,
    required int budgetBytes,
    required DateTime createdAt,
    required Future<void> Function(QuarantineBatch) onCommit,
  })  : _id = id,
        _root = root,
        _remainingBudget = budgetBytes,
        _createdAt = createdAt,
        _onCommit = onCommit;

  final String _id;
  final Directory _root;
  final DateTime _createdAt;
  final Future<void> Function(QuarantineBatch) _onCommit;

  int _remainingBudget;

  final List<QuarantineEntry> _entries = <QuarantineEntry>[];

  Directory? _batchDirectory;

  @override
  Future<bool> keep(JunkItem item) async {
    if (item.sizeInBytes > AppQuarantinePolicy.maxEntryBytes ||
        item.sizeInBytes > _remainingBudget) {
      return false;
    }

    final Directory directory = await _ensureDirectory();

    // Prefixed with the position, because a batch is one flat directory and two
    // caches on two drives both hold a `cache.db`. The real name is recovered
    // from the original path at restore time, never from this one.
    final String storedName = '${_entries.length}_${item.name}';
    final String destination = p.join(directory.path, storedName);

    if (!await _rename(item.path, destination, item.isDirectory)) {
      return false;
    }

    _entries.add(
      QuarantineEntry(
        originalPath: item.path,
        storedName: storedName,
        sizeInBytes: item.sizeInBytes,
        category: item.category,
        wasDirectory: item.isDirectory,
      ),
    );
    _remainingBudget -= item.sizeInBytes;

    return true;
  }

  @override
  Future<QuarantineBatch?> commit() async {
    if (_entries.isEmpty) {
      // Nothing was kept, so nothing is left on disk either — the directory is
      // only created by the first successful move.
      return null;
    }

    final QuarantineBatch batch = QuarantineBatch(
      id: _id,
      createdAt: _createdAt,
      entries: List<QuarantineEntry>.unmodifiable(_entries),
    );

    await _onCommit(batch);

    return batch;
  }

  Future<Directory> _ensureDirectory() async {
    final Directory? cached = _batchDirectory;

    if (cached != null) {
      return cached;
    }

    final Directory directory = Directory(p.join(_root.path, _id));

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    _batchDirectory = directory;

    return directory;
  }

  /// A rename and never a copy.
  ///
  /// `rename` across volumes throws on every platform, and that refusal is the
  /// answer rather than a problem to work around: copying four gigabytes to a
  /// quarantine on another disk frees nothing on the disk the user was trying
  /// to clear.
  static Future<bool> _rename(
    String from,
    String to,
    bool isDirectory,
  ) async {
    try {
      if (isDirectory) {
        await Directory(from).rename(to);
      } else {
        await File(from).rename(to);
      }

      return true;
    } on FileSystemException {
      return false;
    }
  }
}
