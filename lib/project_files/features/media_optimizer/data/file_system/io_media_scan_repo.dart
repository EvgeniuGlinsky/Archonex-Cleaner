import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:storage_cleaner/core/constants/app_optimizer_policy.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/file_system/file_byte_source.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/file_system/media_roots_resolver.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/probes/media_probe_reader.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/rules/media_roots.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/rules/media_rule.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/rules/media_ruleset.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/rules/off_limits_paths.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/rules/optimize_guard.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/rules/savings_estimator.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/media_scan_repo.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_candidate.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_container.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_kind.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_probe.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_scan_job.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_scan_update.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_failure.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';

/// The real walker, on `dart:io`.
///
/// It owns no rules of its own, exactly as `IoJunkScanRepo` owns none:
/// `MediaRuleset` says where to look, `OptimizeGuard` says what may be opened,
/// `MediaProbeReader` says what a file is, and `SavingsEstimator` says what to
/// do about it. This walks. Splitting it that way is what makes the four
/// interesting pieces pure classes with unit tests, and this one a loop with
/// nothing to decide.
class IoMediaScanRepo implements MediaScanRepo {
  IoMediaScanRepo({
    MediaRootsResolver? resolver,
    MediaProbeReader? probeReader,
    DateTime Function()? now,
    TargetPlatform? platform,
  })  : _resolver = resolver ?? const MediaRootsResolver(),
        _probeReader = probeReader ?? const MediaProbeReader(),
        _now = now ?? DateTime.now,
        _platformOverride = platform;

  final MediaRootsResolver _resolver;
  final MediaProbeReader _probeReader;
  final DateTime Function() _now;
  final TargetPlatform? _platformOverride;

  MediaRoots? _cachedRoots;

  TargetPlatform get _platform => _platformOverride ?? defaultTargetPlatform;

  /// Every platform with a file system except iOS.
  ///
  /// iOS has one and it holds nothing the user put there: the photo library is
  /// behind an API that hands out copies rather than paths, and no permission
  /// changes that. A scan there would walk an empty container and report the
  /// device optimised, which is worse than refusing.
  @override
  bool get isSupported =>
      _platform != TargetPlatform.iOS && _platform != TargetPlatform.fuchsia;

  @override
  Future<Set<MediaKind>> kindsFor(StorageAccess access) async {
    return MediaRuleset.kindsFor(
      platform: _platform,
      roots: await _roots(access),
      access: access,
    );
  }

  @override
  Future<MediaScanJob> scan({
    required Set<MediaKind> kinds,
    required StorageAccess access,
  }) async {
    final MediaRoots roots = await _roots(access);

    return _IoMediaScanJob(
      rules: MediaRuleset.of(platform: _platform, roots: roots, access: access),
      guard: OptimizeGuard(
        offLimitsPaths: OffLimitsPaths.of(_platform, roots),
        now: _now,
      ),
      probeReader: _probeReader,
      kinds: kinds,
      context: p.Context(
        style: _platform == TargetPlatform.windows ? p.Style.windows : p.Style.posix,
      ),
    );
  }

  /// The folders do not move while the process is alive, so they are resolved
  /// once — except the granted ones, which arrive in [access] and change.
  Future<MediaRoots> _roots(StorageAccess access) async {
    final MediaRoots? cached = _cachedRoots;

    if (cached != null && cached.grantedFolders == access.grantedRoots) {
      return cached;
    }

    final MediaRoots resolved = await _resolver.resolve(access);
    _cachedRoots = resolved;

    return resolved;
  }
}

/// One walk, exposed as a stream that can be stopped.
///
/// The same skeleton as `_IoScanJob` next door — `onListen`, a cooperative
/// cancel flag, a batched flush with a timer for the tail — because the reasons
/// are the same: work must not start for a screen the user may have left, and
/// one event per file is one rebuild per file.
///
/// What differs is the cost per finding. The cleaner's walk asks the file
/// system for a size; this one opens the file and reads its header, which is
/// slower by orders of magnitude, so the batch is smaller and the guard runs
/// *before* the open rather than after it.
class _IoMediaScanJob implements MediaScanJob {
  _IoMediaScanJob({
    required List<MediaRule> rules,
    required OptimizeGuard guard,
    required MediaProbeReader probeReader,
    required Set<MediaKind> kinds,
    required p.Context context,
  })  : _rules = rules,
        _guard = guard,
        _probeReader = probeReader,
        _kinds = kinds,
        _context = context {
    _controller = StreamController<MediaScanUpdate>(onListen: _start);
  }

  final List<MediaRule> _rules;
  final OptimizeGuard _guard;
  final MediaProbeReader _probeReader;
  final Set<MediaKind> _kinds;
  final p.Context _context;

  late final StreamController<MediaScanUpdate> _controller;

  final List<MediaCandidate> _buffer = <MediaCandidate>[];

  /// Paths already reported, so two roots that overlap despite
  /// `MediaRuleset`'s deduplication — a symlinked folder, a bind mount — report
  /// a file once.
  final Set<String> _seen = <String>{};

  Timer? _flushTimer;
  bool _isCancelling = false;

  @override
  Stream<MediaScanUpdate> get updates => _controller.stream;

  @override
  Future<void> cancel() async {
    _isCancelling = true;
  }

  bool get _isStopped => _isCancelling || _controller.isClosed;

  Future<void> _start() async {
    _flushTimer = Timer.periodic(
      AppOptimizerPolicy.foundFlushInterval,
      (_) => _flush(),
    );

    try {
      for (final MediaRule rule in _rules) {
        if (_isStopped) {
          break;
        }

        _emit(MediaLocationChanged(label: rule.label));
        await _walk(rule);
      }
    } on Object {
      // A walk that broke in a way no single path explains. Nothing was
      // rewritten — a scan only reads — so this ends the run and says so.
      await _finishWith(const MediaScanFailure());

      return;
    }

    if (_isCancelling) {
      await _finishWith(const MediaScanCancelledFailure());

      return;
    }

    _flush();
    await _close();
  }

  Future<void> _walk(MediaRule rule) async {
    final Directory root = Directory(rule.root);

    if (!await root.exists()) {
      return;
    }

    int found = 0;
    final Set<MediaKind> truncated = <MediaKind>{};

    Future<bool> take(MediaCandidate candidate) async {
      if (!_seen.add(candidate.path)) {
        return true;
      }

      _buffer.add(candidate);

      if (_buffer.length >= AppOptimizerPolicy.foundBatchSize) {
        _flush();
      }

      found++;

      if (found >= AppOptimizerPolicy.maxItemsPerRoot) {
        // Reported per kind rather than per root, because the groups on the
        // screen are per kind and that is where the notice has to land.
        for (final MediaKind kind in _kinds) {
          if (truncated.add(kind)) {
            _emit(MediaScanTruncated(kind: kind));
          }
        }

        return false;
      }

      return true;
    }

    await _descend(rule, root, take, depth: 0);
  }

  Future<bool> _descend(
    MediaRule rule,
    Directory directory,
    Future<bool> Function(MediaCandidate) take, {
    required int depth,
  }) async {
    if (depth > rule.maxDepth) {
      return true;
    }

    await for (final FileSystemEntity entity in _list(directory)) {
      if (_isStopped) {
        return false;
      }

      if (entity is Directory) {
        if (!await _descend(rule, entity, take, depth: depth + 1)) {
          return false;
        }

        continue;
      }

      if (entity is! File) {
        continue;
      }

      if (!rule.matchesFile(_context.basename(entity.path))) {
        continue;
      }

      final MediaCandidate? candidate = await _describe(entity);

      if (candidate != null && !await take(candidate)) {
        return false;
      }
    }

    return true;
  }

  /// Measures a file, opens it, and judges it.
  ///
  /// `null` where the guard refused, where the file is not what its name said,
  /// or where the OS would not answer — a file that vanished between being
  /// listed and being opened is ordinary in a folder somebody is using.
  ///
  /// The order is the point. The guard runs on the `stat` alone, before the
  /// open, because a probe costs a file handle and a read and there is no
  /// reason to spend one on a thumbnail or on something inside a cloud mirror.
  Future<MediaCandidate?> _describe(File file) async {
    final MediaKind? guessed = _kindFromName(file.path);

    if (guessed == null || !_kinds.contains(guessed)) {
      return null;
    }

    final FileStat stat;
    final bool isLink;

    try {
      stat = await file.stat();
      isLink = await FileSystemEntity.isLink(file.path);
    } on FileSystemException {
      return null;
    }

    final bool allowed = _guard.allows(
      path: file.path,
      kind: guessed,
      sizeInBytes: stat.size,
      modifiedAt: stat.modified,
      isLink: isLink,
    );

    if (!allowed) {
      return null;
    }

    final FileByteSource? source = await FileByteSource.open(file.path);

    if (source == null) {
      return null;
    }

    try {
      final MediaProbe? probe = await _probeReader.read(source);

      // Not media at all, whatever the extension claimed. Dropped silently
      // rather than listed as unreadable: a `.png` holding a text file is not
      // something the user needs told about.
      if (probe == null) {
        return null;
      }

      // The header disagreed with the name about what kind this is — a `.mp4`
      // that is really a photograph, or the reverse. The header wins, and the
      // guard's size floor has to be re-checked against the kind it really is.
      if (!_kinds.contains(probe.kind) ||
          stat.size < OptimizeGuard.minimumBytesFor(probe.kind)) {
        return null;
      }

      return MediaCandidate(
        path: file.path,
        name: _context.basename(file.path),
        sizeInBytes: stat.size,
        modifiedAt: stat.modified,
        probe: probe,
        plan: SavingsEstimator.plan(probe: probe, sizeInBytes: stat.size),
      );
    } finally {
      // A camera roll is thousands of files, and a handle left behind per file
      // exhausts the process's limit long before the walk ends.
      await source.close();
    }
  }

  /// What the extension suggests, used only to decide whether to open the file.
  ///
  /// The answer is not trusted past that point — `MediaProbeReader` dispatches
  /// on the magic bytes, and `_describe` re-checks the kind afterwards.
  MediaKind? _kindFromName(String path) {
    final String name = _context.basename(path);
    final int dot = name.lastIndexOf('.');

    if (dot < 0) {
      return null;
    }

    return MediaContainer.fromExtension(name.substring(dot))?.kind;
  }

  /// Lists a directory, swallowing a refusal.
  ///
  /// A folder the OS will not open is expected on every platform and is not a
  /// failure of the run — the rule simply finds nothing there.
  Stream<FileSystemEntity> _list(Directory directory) {
    return directory.list(followLinks: false).handleError(
          (Object _) {},
          test: (Object? error) => error is FileSystemException,
        );
  }

  void _emit(MediaScanUpdate update) {
    if (!_controller.isClosed) {
      _controller.add(update);
    }
  }

  void _flush() {
    if (_buffer.isEmpty || _controller.isClosed) {
      return;
    }

    _emit(MediaFound(List<MediaCandidate>.unmodifiable(_buffer)));
    _buffer.clear();
  }

  /// Ends the run with [failure], handing over nothing: a walk that did not
  /// finish has not measured anything the user can act on.
  Future<void> _finishWith(OptimizeFailure failure) async {
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
