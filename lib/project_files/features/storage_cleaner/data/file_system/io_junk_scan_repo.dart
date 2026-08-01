import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:storage_cleaner/core/constants/app_clean_policy.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/file_system/cleaner_roots_resolver.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/rules/cleaner_roots.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/rules/deletion_guard.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/rules/junk_rule.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/rules/junk_ruleset.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/rules/protected_paths.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/junk_scan_repo.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/clean_failure.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/junk_category.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/junk_item.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/scan_job.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/scan_update.dart';

/// The real scanner, on `dart:io`.
///
/// It owns no rules of its own: `JunkRuleset` says where to look, `JunkRule`
/// says what counts, `DeletionGuard` says what may be offered, and this walks.
/// Splitting it that way is what makes the dangerous half — the guard — a pure
/// class with a unit test, and this half a loop with nothing to decide.
class IoJunkScanRepo implements JunkScanRepo {
  IoJunkScanRepo({
    CleanerRootsResolver? resolver,
    DateTime Function()? now,
    TargetPlatform? platform,
  })  : _resolver = resolver ?? const CleanerRootsResolver(),
        _now = now ?? DateTime.now,
        _platformOverride = platform;

  final CleanerRootsResolver _resolver;
  final DateTime Function() _now;
  final TargetPlatform? _platformOverride;

  CleanerRoots? _cachedRoots;

  TargetPlatform get _platform => _platformOverride ?? defaultTargetPlatform;

  @override
  bool get isSupported => true;

  @override
  Future<Set<JunkCategory>> categoriesFor(StorageAccess access) async {
    return JunkRuleset.categoriesFor(
      platform: _platform,
      roots: await _roots(access),
      access: access,
    );
  }

  @override
  Future<ScanJob> scan({
    required Set<JunkCategory> categories,
    required StorageAccess access,
  }) async {
    final CleanerRoots roots = await _roots(access);
    final p.Context context = _contextFor(_platform);

    return _IoScanJob(
      rules: JunkRuleset.of(
        platform: _platform,
        roots: roots,
        access: access,
        categories: categories,
      ),
      guard: DeletionGuard(
        protectedPaths: ProtectedPaths.of(_platform, roots),
        now: _now,
        context: context,
      ),
      context: context,
    );
  }

  /// The paths do not move while the process is alive, so they are read once —
  /// except the granted folders, which arrive in [access] and change.
  Future<CleanerRoots> _roots(StorageAccess access) async {
    final CleanerRoots? cached = _cachedRoots;

    if (cached != null && cached.grantedFolders == access.grantedRoots) {
      return cached;
    }

    final CleanerRoots resolved = await _resolver.resolve(access);
    _cachedRoots = resolved;

    return resolved;
  }

  static p.Context _contextFor(TargetPlatform platform) => p.Context(
        style: platform == TargetPlatform.windows
            ? p.Style.windows
            : p.Style.posix,
      );
}

/// One walk, exposed as a stream that can be stopped.
///
/// Findings are buffered and flushed in batches — one event per file is one
/// bloc rebuild per file, and a Windows `%TEMP%` has tens of thousands. The
/// timer exists for the other half of that: without it the tail of a slow
/// directory sits in the buffer and the screen looks stalled.
class _IoScanJob implements ScanJob {
  _IoScanJob({
    required List<JunkRule> rules,
    required DeletionGuard guard,
    required p.Context context,
  })  : _rules = rules,
        _guard = guard,
        _context = context {
    _controller = StreamController<ScanUpdate>(onListen: _start);
  }

  final List<JunkRule> _rules;
  final DeletionGuard _guard;
  final p.Context _context;

  late final StreamController<ScanUpdate> _controller;

  final List<JunkItem> _buffer = <JunkItem>[];

  /// Paths already reported, so two rules covering the same directory — the
  /// Linux `~/.cache` and `~/.cache/thumbnails` pair — report it once.
  final Set<String> _seen = <String>{};

  Timer? _flushTimer;
  bool _isCancelling = false;

  @override
  Stream<ScanUpdate> get updates => _controller.stream;

  @override
  Future<void> cancel() async {
    _isCancelling = true;
  }

  Future<void> _start() async {
    _flushTimer = Timer.periodic(
      AppCleanPolicy.foundFlushInterval,
      (_) => _flush(),
    );

    try {
      for (final JunkRule rule in _rules) {
        if (_isStopped) {
          break;
        }

        _emit(ScanLocationChanged(label: rule.label));
        await _walkRule(rule);
      }
    } on Object {
      // A walk that broke in a way no single path explains. Nothing has been
      // deleted — a scan deletes nothing — so this ends the run and says so.
      await _finishWith(const ScanFailure());

      return;
    }

    if (_isCancelling) {
      await _finishWith(const ScanCancelledFailure());

      return;
    }

    _flush();
    await _close();
  }

  bool get _isStopped => _isCancelling || _controller.isClosed;

  Future<void> _walkRule(JunkRule rule) async {
    final Directory root = Directory(rule.root);

    if (!await root.exists()) {
      return;
    }

    int found = 0;

    Future<bool> take(JunkItem item) async {
      if (!_seen.add(item.path)) {
        return true;
      }

      _buffer.add(item);

      if (_buffer.length >= AppCleanPolicy.foundBatchSize) {
        _flush();
      }

      found++;

      if (found >= AppCleanPolicy.maxItemsPerRule) {
        _emit(ScanTruncated(category: rule.category));

        return false;
      }

      return true;
    }

    switch (rule.mode) {
      case JunkRuleMode.contents:
        await _walkContents(rule, root, take);
      case JunkRuleMode.files:
        await _walkFiles(rule, root, take, depth: 0);
      case JunkRuleMode.directories:
        await _walkDirectories(rule, root, take, depth: 0);
      case JunkRuleMode.emptyDirectories:
        await _walkEmptyDirectories(rule, root, take, depth: 0);
    }
  }

  /// Every entry directly inside the root, a subdirectory counted whole.
  Future<void> _walkContents(
    JunkRule rule,
    Directory root,
    Future<bool> Function(JunkItem) take,
  ) async {
    await for (final FileSystemEntity entity in _list(root)) {
      if (_isStopped) {
        return;
      }

      final JunkItem? item = await _describe(entity, rule);

      if (item != null && !await take(item)) {
        return;
      }
    }
  }

  /// Matching files at any depth, up to the rule's ceiling.
  Future<void> _walkFiles(
    JunkRule rule,
    Directory directory,
    Future<bool> Function(JunkItem) take, {
    required int depth,
  }) async {
    if (depth > rule.maxDepth) {
      return;
    }

    await for (final FileSystemEntity entity in _list(directory)) {
      if (_isStopped) {
        return;
      }

      if (entity is Directory) {
        await _walkFiles(rule, entity, take, depth: depth + 1);

        continue;
      }

      if (entity is! File || !rule.matchesFile(_context.basename(entity.path))) {
        continue;
      }

      final JunkItem? item = await _describe(entity, rule);

      if (item != null && !await take(item)) {
        return;
      }
    }
  }

  /// Directories the rule names, taken whole.
  Future<void> _walkDirectories(
    JunkRule rule,
    Directory directory,
    Future<bool> Function(JunkItem) take, {
    required int depth,
  }) async {
    if (depth > rule.maxDepth) {
      return;
    }

    await for (final FileSystemEntity entity in _list(directory)) {
      if (_isStopped) {
        return;
      }

      if (entity is! Directory) {
        continue;
      }

      if (rule.matchesDirectory(_context.basename(entity.path))) {
        final JunkItem? item = await _describe(entity, rule);

        // Matched directories are not descended into: the whole thing goes, so
        // what is inside it is not a separate decision.
        if (item != null && !await take(item)) {
          return;
        }

        continue;
      }

      await _walkDirectories(rule, entity, take, depth: depth + 1);
    }
  }

  Future<void> _walkEmptyDirectories(
    JunkRule rule,
    Directory directory,
    Future<bool> Function(JunkItem) take, {
    required int depth,
  }) async {
    if (depth > rule.maxDepth) {
      return;
    }

    await for (final FileSystemEntity entity in _list(directory)) {
      if (_isStopped) {
        return;
      }

      if (entity is! Directory) {
        continue;
      }

      if (await _isEmpty(entity)) {
        final JunkItem? item = await _describe(entity, rule);

        if (item != null && !await take(item)) {
          return;
        }

        continue;
      }

      await _walkEmptyDirectories(rule, entity, take, depth: depth + 1);
    }
  }

  /// Measures an entity and runs it past the guard.
  ///
  /// `null` means the guard refused it, or the OS did — a file that vanished
  /// between being listed and being measured is the normal case in a temporary
  /// directory, not an error.
  Future<JunkItem?> _describe(FileSystemEntity entity, JunkRule rule) async {
    try {
      final FileStat stat = await entity.stat();
      final bool isLink = await FileSystemEntity.isLink(entity.path);

      final bool allowed = _guard.allows(
        path: entity.path,
        ruleRoot: rule.root,
        modifiedAt: stat.modified,
        minimumAge: rule.minimumAge,
        isLink: isLink,
      );

      if (!allowed) {
        return null;
      }

      final bool isDirectory = entity is Directory;

      return JunkItem(
        path: entity.path,
        name: _context.basename(entity.path),
        sizeInBytes:
            isDirectory ? await _sizeOf(entity) : stat.size,
        category: rule.category,
        modifiedAt: stat.modified,
        isDirectory: isDirectory,
      );
    } on FileSystemException {
      return null;
    }
  }

  /// Recursive byte total. Unreadable branches count as zero rather than
  /// stopping the sum: a directory the app cannot fully measure is still one it
  /// can partly delete, and an underestimate is the safe direction to be wrong
  /// in — the freed figure the user is shown comes from the deletion, not here.
  Future<int> _sizeOf(Directory directory) async {
    int total = 0;

    try {
      await for (final FileSystemEntity entity
          in directory.list(recursive: true, followLinks: false)) {
        if (_isStopped) {
          return total;
        }

        if (entity is File) {
          try {
            total += await entity.length();
          } on FileSystemException {
            continue;
          }
        }
      }
    } on FileSystemException {
      return total;
    }

    return total;
  }

  Future<bool> _isEmpty(Directory directory) async {
    try {
      return await directory.list(followLinks: false).isEmpty;
    } on FileSystemException {
      return false;
    }
  }

  /// Lists a directory, swallowing a refusal.
  ///
  /// A protected system directory that the OS will not open is the expected
  /// case on every platform, and it is not a failure of the run — the rule
  /// simply finds nothing there.
  Stream<FileSystemEntity> _list(Directory directory) {
    return directory.list(followLinks: false).handleError(
          (Object _) {},
          test: (Object? error) => error is FileSystemException,
        );
  }

  void _emit(ScanUpdate update) {
    if (!_controller.isClosed) {
      _controller.add(update);
    }
  }

  void _flush() {
    if (_buffer.isEmpty || _controller.isClosed) {
      return;
    }

    _emit(JunkFound(List<JunkItem>.unmodifiable(_buffer)));
    _buffer.clear();
  }

  /// Ends the run with [failure]. Nothing found is handed over: a scan that did
  /// not finish has not measured anything the user can act on.
  Future<void> _finishWith(CleanFailure failure) async {
    _buffer.clear();

    if (_controller.isClosed) {
      return;
    }

    _controller.addError(failure);
    await _close();
  }

  Future<void> _close() async {
    _flushTimer?.cancel();
    _flushTimer = null;

    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}
