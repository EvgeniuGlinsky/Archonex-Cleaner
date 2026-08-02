import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

import 'package:storage_cleaner/core/constants/app_optimizer_policy.dart';
import 'package:storage_cleaner/core/utils/file_size_formatter.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/file_system/file_byte_source.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/file_system/media_roots_resolver.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/platform/media_optimizer_platform.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/probes/media_probe_reader.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/rules/media_roots.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/rules/media_rule.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/rules/media_ruleset.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/rules/off_limits_paths.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/rules/savings_estimator.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/media_optimize_repo.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/media_scan_repo.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/encoder_support.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_candidate.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_kind.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_probe.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_scan_job.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_scan_update.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_quality.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_report.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_update.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_verdict.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/platform/storage_access_platform.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';

/// Runs the optimiser against the real machine.
///
/// Two halves, and the split matters. The **survey** walks the user's own
/// media folders, reads the headers, prints what it found and what it thinks
/// could be saved, and **writes nothing at all**. The **round trip** builds its
/// own files in a temporary directory and actually re-encodes those, which is
/// the only way to find out whether `ffmpeg` and `MediaCodec` do what the Dart
/// side believes they do.
///
/// The unit tests answer whether the estimator is right about a `MediaProbe`.
/// They cannot answer the questions only a device can be asked, and every one
/// of these fails *quietly* under `flutter test`:
///
/// - whether the folders `MediaRootsResolver` names exist here, and whether
///   reading the header of every file in a real camera roll finishes in a
///   sensible time;
/// - whether the estimates are anywhere near what the encoder actually
///   produces — the figures in `AppOptimizerPolicy` are measured, and only a
///   real encode says whether they were measured well;
/// - whether there is an encoder at all, which on Windows and Linux depends on
///   what is installed rather than on anything in this repository;
/// - whether the Kotlin `MediaCodec` pipeline works, which no Dart test can
///   reach;
/// - whether the replace ladder behaves the same on a real file system as it
///   does on a temporary directory under `flutter test` — Windows refuses a
///   rename onto an existing file, and that is a platform behaviour rather than
///   a Dart one.
///
/// That is why this is separate from `test/` and out of CI.
///
/// ```bash
/// flutter test integration_test/optimize_probe_test.dart -d windows
/// flutter test integration_test/optimize_probe_test.dart -d <android-device-id>
/// ```
///
/// It asserts nothing about how much it found — a device full of HEVC
/// legitimately finds nothing worth doing — and everything about the invariants
/// that must hold whatever it found. Read the printed report; that is the point
/// of running it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('the survey', () {
    testWidgets('the media folders this platform names actually exist',
        (tester) async {
      final StorageAccess access = await createStorageAccessRepo().current();
      final MediaRoots roots =
          await const MediaRootsResolver().resolve(access);

      final List<MediaRule> rules = MediaRuleset.of(
        platform: defaultTargetPlatform,
        roots: roots,
        access: access,
      );

      debugPrint('── media roots on $defaultTargetPlatform ──');

      int present = 0;

      for (final MediaRule rule in rules) {
        final bool exists = Directory(rule.root).existsSync();

        if (exists) {
          present++;
        }

        debugPrint('${exists ? '✓' : '·'} ${rule.label}  ${rule.root}');
      }

      debugPrint('$present of ${rules.length} roots are really there');

      // No assertion on the count. A fresh Windows install has an empty
      // Pictures folder and a phone with no camera roll is a phone nobody has
      // taken a photograph on, and neither is a bug.
      expect(tester.takeException(), isNull);
    });

    testWidgets('a real walk finishes, and offers nothing off limits',
        (tester) async {
      final MediaScanRepo repo = createMediaScanRepo();

      if (!repo.isSupported) {
        debugPrint('No reachable user media on $defaultTargetPlatform.');

        return;
      }

      final StorageAccess access = await createStorageAccessRepo().current();

      if (!access.canScan) {
        debugPrint('Access is ${access.level}; nothing to walk.');

        return;
      }

      final Set<MediaKind> kinds = await repo.kindsFor(access);

      if (kinds.isEmpty) {
        debugPrint('No kinds reachable at ${access.level}.');

        return;
      }

      final MediaRoots roots =
          await const MediaRootsResolver().resolve(access);
      final OffLimitsPaths offLimits =
          OffLimitsPaths.of(defaultTargetPlatform, roots);

      final Stopwatch clock = Stopwatch()..start();
      final MediaScanJob job = await repo.scan(
        kinds: kinds,
        access: access,
        quality: OptimizeQuality.fallback,
      );

      final List<MediaCandidate> found = <MediaCandidate>[];

      await for (final MediaScanUpdate update in job.updates) {
        if (update is MediaFound) {
          found.addAll(update.candidates);
        }
      }

      clock.stop();

      _report(found, clock.elapsed);

      // The invariants, whatever it found.
      for (final MediaCandidate candidate in found) {
        expect(
          offLimits.contains(candidate.path),
          isFalse,
          reason: 'offered something off limits: ${candidate.path}',
        );
        expect(
          kinds.contains(candidate.kind),
          isTrue,
          reason: 'offered a kind nobody asked for: ${candidate.path}',
        );
        expect(
          candidate.sizeInBytes,
          greaterThanOrEqualTo(
            candidate.kind == MediaKind.photo
                ? AppOptimizerPolicy.minimumPhotoBytes
                : AppOptimizerPolicy.minimumVideoBytes,
          ),
          reason: 'offered something under the floor: ${candidate.path}',
        );
        // A plan that is worth doing must claim a real saving. A row promising
        // nothing is a row that should have been a refusal.
        if (candidate.isWorthIt) {
          expect(candidate.estimatedSaving, greaterThan(0));
          expect(candidate.plan.targetContainer, isNotNull);
        }
      }

      expect(
        found.map((candidate) => candidate.path).toSet().length,
        found.length,
        reason: 'the same file was offered twice',
      );
    });

    testWidgets('the machine says what it can encode', (tester) async {
      // A property of what is installed, not of the platform, which is the
      // whole reason `EncoderSupport` is asked rather than assumed.
      final EncoderSupport support = await createMediaOptimizeRepo().support();

      debugPrint('── encoders on $defaultTargetPlatform ──');
      debugPrint('photos: ${support.photos}');
      debugPrint('videos: ${support.videos}');

      if (!support.videos && defaultTargetPlatform == TargetPlatform.android) {
        debugPrint('No HEVC encoder on this device — the notice will show.');
      }
    });
  });

  group('the round trip', () {
    late Directory workspace;

    setUp(() async {
      workspace = await Directory.systemTemp.createTemp('storage_cleaner_probe_');
    });

    tearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    testWidgets('a real photograph is re-encoded, verified and swapped',
        (tester) async {
      final MediaOptimizeRepo repo = createMediaOptimizeRepo();
      final EncoderSupport support = await repo.support();

      if (!support.photos) {
        debugPrint('No photo encoder here. Nothing to prove.');

        return;
      }

      final File source = await _writeTestPhotograph(workspace);
      final MediaCandidate? candidate = await _describe(source);

      expect(candidate, isNotNull, reason: 'the test photograph did not probe');
      expect(candidate!.isWorthIt, isTrue, reason: candidate.plan.verdict.name);

      final DateTime before = source.lastModifiedSync();
      final int sizeBefore = candidate.sizeInBytes;

      // A bitmap becomes a JPEG, so the file the run leaves behind has a
      // different name — which is itself worth proving on a real file system.
      final File destination = File(_destinationOf(candidate));

      final OptimizeReport report = await _run(repo, <MediaCandidate>[candidate]);

      debugPrint('── photo round trip ──');
      debugPrint('before:    ${FileSizeFormatter.format(sizeBefore)}');
      debugPrint('estimated: ${FileSizeFormatter.format(candidate.plan.estimatedBytes!)}');
      debugPrint('after:     ${FileSizeFormatter.format(await destination.length())}');
      debugPrint('freed:     ${FileSizeFormatter.format(report.freedBytes)}');

      expect(report.optimizedCount, 1, reason: 'skipped or failed');
      expect(report.renamedCount, 1, reason: 'the extension should have changed');
      expect(report.freedBytes, greaterThan(0));
      expect(destination.existsSync(), isTrue);
      expect(source.existsSync(), isFalse, reason: 'the bitmap should be gone');
      expect(await destination.length(), lessThan(sizeBefore));

      // The two things a unit test cannot check on a real file system.
      expect(
        destination.lastModifiedSync().difference(before).abs(),
        lessThan(const Duration(seconds: 2)),
        reason: 'the modification time was not carried across',
      );
      expect(
        workspace.listSync().map((entity) => p.basename(entity.path)).toList(),
        <String>[p.basename(destination.path)],
        reason: 'a working file or a superseded original was left behind',
      );

      // And that the picture is still the picture.
      final MediaCandidate? after = await _describe(destination);

      expect(after?.probe.width, candidate.probe.width);
      expect(after?.probe.height, candidate.probe.height);
    });

    testWidgets('the estimate is in the same country as the result',
        (tester) async {
      // The figures in `AppOptimizerPolicy` are measured rather than derived,
      // and this is the only place that says whether they were measured well.
      // Wide bounds on purpose: the estimate is an estimate, and a synthetic
      // photograph is not a real one.
      final MediaOptimizeRepo repo = createMediaOptimizeRepo();

      if (!(await repo.support()).photos) {
        return;
      }

      final File source = await _writeTestPhotograph(workspace);
      final MediaCandidate candidate = (await _describe(source))!;
      final int estimated = candidate.plan.estimatedBytes!;

      await _run(repo, <MediaCandidate>[candidate]);

      final int actual = await File(_destinationOf(candidate)).length();
      final double ratio = actual / estimated;

      debugPrint('estimate was ${(ratio * 100).round()}% of the real output');

      expect(
        ratio,
        inInclusiveRange(0.2, 5.0),
        reason: 'the estimate is out by more than an order of magnitude',
      );
    });
  });
}

/// A picture that compresses the way a photograph does.
///
/// Generated rather than checked in, for the reason the unit fixtures are: a
/// binary nobody can review proves nothing. Getting the *texture* right matters
/// more than it looks, and both easy answers are wrong. A gradient compresses
/// to almost nothing and would fall under the size floor before it was ever
/// offered; pure noise is incompressible, and the first version of this probe
/// used it and reported the estimator as ten times out when the estimator was
/// right — a real 4 MP photograph lands near the figure in
/// `AppOptimizerPolicy`, and 4 MP of static does not.
///
/// So: smooth shapes with a little grain on them, which is what a camera
/// actually produces.
Future<File> _writeTestPhotograph(Directory workspace) async {
  const int width = 2400;
  const int height = 1800;

  final Uint8List pixels = Uint8List(width * height * 3);
  int seed = 20260801;

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      // A deterministic generator rather than `Random`, so the file is
      // identical between runs and a surprising result is worth investigating
      // rather than worth re-running.
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;

      final int grain = ((seed >> 16) & 0x1F) - 16;
      final int index = (y * width + x) * 3;

      pixels[index] = _clampByte(
        128 + (100 * math.sin(x / 37) * math.cos(y / 53)).round() + grain,
      );
      pixels[index + 1] = _clampByte(
        128 + (90 * math.sin((x + y) / 61)).round() + grain,
      );
      pixels[index + 2] = _clampByte(
        128 + (110 * math.cos(x / 89) * math.sin(y / 43)).round() + grain,
      );
    }
  }

  // Written as a BMP, which needs no encoder to produce: a header and the
  // pixels. The estimator always finds a bitmap worth converting, which is
  // exactly what this file is for.
  final File file = File(p.join(workspace.path, 'probe-photo.bmp'));
  await file.writeAsBytes(_bmp(width, height, pixels), flush: true);

  // Older than the age floor, or the guard would refuse it — and the guard is
  // right to: a file this new could still be being written.
  await file.setLastModified(
    DateTime.now().subtract(AppOptimizerPolicy.minimumAge * 2),
  );

  return file;
}

int _clampByte(int value) => value < 0 ? 0 : (value > 255 ? 255 : value);

List<int> _bmp(int width, int height, Uint8List pixels) {
  const int headerBytes = 54;
  final int fileBytes = headerBytes + pixels.length;

  List<int> u32(int value) => <int>[
        value & 0xFF,
        (value >> 8) & 0xFF,
        (value >> 16) & 0xFF,
        (value >> 24) & 0xFF,
      ];

  return <int>[
    0x42, 0x4D, // "BM"
    ...u32(fileBytes),
    ...u32(0),
    ...u32(headerBytes),
    ...u32(40), // DIB header size
    ...u32(width),
    ...u32(height),
    0x01, 0x00, // planes
    0x18, 0x00, // bits per pixel
    ...u32(0), // no compression
    ...u32(pixels.length),
    ...u32(2835), ...u32(2835), // pixels per metre
    ...u32(0), ...u32(0),
    ...pixels,
  ];
}

/// Reads and judges one file, the way the walker does.
Future<MediaCandidate?> _describe(File file) async {
  final FileByteSource? source = await FileByteSource.open(file.path);

  if (source == null) {
    return null;
  }

  try {
    final MediaProbe? probe = await const MediaProbeReader().read(source);

    if (probe == null) {
      return null;
    }

    final int size = await file.length();

    return MediaCandidate(
      path: file.path,
      name: p.basename(file.path),
      sizeInBytes: size,
      modifiedAt: file.lastModifiedSync(),
      probe: probe,
      plan: SavingsEstimator.plan(probe: probe, sizeInBytes: size),
    );
  } finally {
    await source.close();
  }
}

/// Where the run will leave the file: the same path, unless the container
/// changed. The same arithmetic `IoMediaOptimizeRepo` does, restated because
/// the probe has to know where to look afterwards.
String _destinationOf(MediaCandidate candidate) {
  if (!candidate.changesExtension) {
    return candidate.path;
  }

  return p.join(
    p.dirname(candidate.path),
    '${p.basenameWithoutExtension(candidate.path)}'
    '${candidate.plan.targetContainer!.canonicalExtension}',
  );
}

Future<OptimizeReport> _run(
  MediaOptimizeRepo repo,
  List<MediaCandidate> candidates,
) async {
  final List<OptimizeUpdate> updates =
      await repo.optimize(candidates: candidates).updates.toList();

  return updates.whereType<OptimizeFinished>().single.report;
}

void _report(List<MediaCandidate> found, Duration elapsed) {
  final List<MediaCandidate> worthwhile =
      found.where((candidate) => candidate.isWorthIt).toList()
        ..sort((a, b) => b.estimatedSaving.compareTo(a.estimatedSaving));

  final int totalBytes =
      found.fold(0, (sum, candidate) => sum + candidate.sizeInBytes);
  final int savingBytes =
      worthwhile.fold(0, (sum, candidate) => sum + candidate.estimatedSaving);

  debugPrint('── walked in ${elapsed.inMilliseconds} ms ──');
  debugPrint('${found.length} files, ${FileSizeFormatter.format(totalBytes)}');
  debugPrint(
    '${worthwhile.length} worth re-encoding, '
    'about ${FileSizeFormatter.format(savingBytes)}',
  );

  final Map<OptimizeVerdict, int> byVerdict = <OptimizeVerdict, int>{};

  for (final MediaCandidate candidate in found) {
    byVerdict.update(
      candidate.plan.verdict,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }

  byVerdict.forEach((verdict, count) => debugPrint('  ${verdict.name}: $count'));

  debugPrint('── the ten biggest wins ──');

  for (final MediaCandidate candidate in worthwhile.take(10)) {
    debugPrint(
      '  ${FileSizeFormatter.format(candidate.sizeInBytes)}'
      ' → ${FileSizeFormatter.format(candidate.plan.estimatedBytes!)}'
      '  ${candidate.probe.width}×${candidate.probe.height}'
      ' ${candidate.probe.codec?.name ?? candidate.probe.container.name}'
      '  ${candidate.name}',
    );
  }
}
