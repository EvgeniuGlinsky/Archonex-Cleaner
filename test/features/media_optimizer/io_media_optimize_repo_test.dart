import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:storage_cleaner/core/constants/app_optimizer_policy.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/file_system/io_media_optimize_repo.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/encoder_support.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_candidate.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_container.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_probe.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimization_plan.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_job.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_quality.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_report.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_update.dart';

import 'fakes.dart';
import 'fixtures.dart';

/// The replace ladder, against a real temporary directory.
///
/// The one data-layer class in this feature with a test of its own, and it
/// earns it the way `IoQuarantineRepo` does: moving a file between two paths
/// *is* the whole behaviour, and a fake file system would be testing the fake.
/// This is also the only place in the app where being wrong loses somebody's
/// photograph, so every failure branch is driven, not just the happy one.
///
/// The encoder is faked, because the real ones cannot run under `flutter test`
/// and because what is being checked has nothing to do with encoding: given a
/// file that came out well, badly, or not at all, does the original survive?
void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('storage_cleaner_optimize_');
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      await workspace.delete(recursive: true);
    }
  });

  /// Writes a real JPEG of [width] × [height], padded to [sizeInBytes].
  ///
  /// A real header, because the ladder re-reads it to verify the replacement
  /// and a file of random bytes would be rejected for the wrong reason.
  Future<File> writeJpeg(
    String name, {
    int width = 4000,
    int height = 3000,
    required int sizeInBytes,
  }) async {
    final Uint8List header = jpegBytes(width: width, height: height);
    final Uint8List bytes = Uint8List(sizeInBytes)..setRange(0, header.length, header);
    final File file = File(p.join(workspace.path, name));

    await file.writeAsBytes(bytes, flush: true);

    return file;
  }

  MediaCandidate candidateFor(
    File file, {
    required int sizeInBytes,
    int width = 4000,
    int height = 3000,
    MediaContainer target = MediaContainer.jpeg,
    MediaContainer source = MediaContainer.jpeg,
    DateTime? modifiedAt,
  }) {
    return MediaCandidate(
      path: file.path,
      name: p.basename(file.path),
      sizeInBytes: sizeInBytes,
      modifiedAt: modifiedAt ?? DateTime.utc(2019, 7, 14, 9, 30),
      probe: MediaProbe(container: source, width: width, height: height),
      plan: OptimizationPlan.reencode(
        targetContainer: target,
        estimatedBytes: sizeInBytes ~/ 3,
        preset: OptimizeQuality.fallback,
      ),
    );
  }

  Future<OptimizeReport> run(
    IoMediaOptimizeRepo repo,
    List<MediaCandidate> candidates,
  ) async {
    final List<OptimizeUpdate> updates =
        await repo.optimize(candidates: candidates).updates.toList();

    return updates.whereType<OptimizeFinished>().single.report;
  }

  IoMediaOptimizeRepo repoWith(FakeMediaEncoder encoder) =>
      IoMediaOptimizeRepo(photoEncoder: encoder, videoEncoder: encoder);

  group('the happy path', () {
    test('the original is replaced by the smaller file, at the same path',
        () async {
      final File original = await writeJpeg('holiday.jpg', sizeInBytes: 9000000);
      final MediaCandidate candidate =
          candidateFor(original, sizeInBytes: 9000000);

      final OptimizeReport report = await run(
        repoWith(FakeMediaEncoder(outputBytes: 3000000)),
        <MediaCandidate>[candidate],
      );

      expect(report.optimizedCount, 1);
      expect(report.freedBytes, 6000000);
      expect(await original.length(), 3000000);
      expect(original.existsSync(), isTrue);
    });

    test('no working file is left behind', () async {
      final File original = await writeJpeg('a.jpg', sizeInBytes: 9000000);

      await run(
        repoWith(FakeMediaEncoder(outputBytes: 3000000)),
        <MediaCandidate>[candidateFor(original, sizeInBytes: 9000000)],
      );

      expect(_names(workspace), <String>['a.jpg']);
    });

    test('the modification time is carried across', () async {
      // Otherwise a gallery puts every optimised photograph at the top as
      // though it were taken today, which for a camera roll is the whole
      // ordering destroyed.
      final DateTime taken = DateTime.utc(2019, 7, 14, 9, 30);
      final File original = await writeJpeg('a.jpg', sizeInBytes: 9000000);

      await run(
        repoWith(FakeMediaEncoder(outputBytes: 3000000)),
        <MediaCandidate>[
          candidateFor(original, sizeInBytes: 9000000, modifiedAt: taken),
        ],
      );

      expect(
        original.lastModifiedSync().toUtc().difference(taken).abs(),
        lessThan(const Duration(seconds: 2)),
      );
    });

    test('a changed container renames, and the old name goes', () async {
      final File original = await writeJpeg('shot.png', sizeInBytes: 12000000);

      final OptimizeReport report = await run(
        repoWith(FakeMediaEncoder(outputBytes: 2000000)),
        <MediaCandidate>[
          candidateFor(
            original,
            sizeInBytes: 12000000,
            source: MediaContainer.png,
          ),
        ],
      );

      expect(report.optimizedCount, 1);
      expect(report.renamedCount, 1);
      expect(_names(workspace), <String>['shot.jpg']);
    });

    test('several files are reported as one total', () async {
      final File a = await writeJpeg('a.jpg', sizeInBytes: 9000000);
      final File b = await writeJpeg('b.jpg', sizeInBytes: 6000000);

      final OptimizeReport report = await run(
        repoWith(FakeMediaEncoder(shrinkTo: 0.25)),
        <MediaCandidate>[
          candidateFor(a, sizeInBytes: 9000000),
          candidateFor(b, sizeInBytes: 6000000),
        ],
      );

      expect(report.optimizedCount, 2);
      expect(report.freedBytes, (9000000 * 0.75 + 6000000 * 0.75).round());
    });
  });

  group('when the encode is no good', () {
    test('an output no smaller than the input is thrown away', () async {
      // Whatever the estimate promised. An encoder that produced something the
      // same size has done nothing useful.
      final File original = await writeJpeg('a.jpg', sizeInBytes: 9000000);

      final OptimizeReport report = await run(
        repoWith(FakeMediaEncoder(outputBytes: 8900000)),
        <MediaCandidate>[candidateFor(original, sizeInBytes: 9000000)],
      );

      expect(report.skippedCount, 1);
      expect(report.optimizedCount, 0);
      expect(await original.length(), 9000000);
      expect(_names(workspace), <String>['a.jpg']);
    });

    test('an output whose dimensions changed is thrown away', () async {
      // The check that catches an encoder quietly downscaling — which is what
      // every off-the-shelf package would have done, and the reason none was
      // used.
      final File original = await writeJpeg('a.jpg', sizeInBytes: 9000000);

      final OptimizeReport report = await run(
        repoWith(
          FakeMediaEncoder(outputBytes: 3000000, outputWidth: 2000, outputHeight: 1500),
        ),
        <MediaCandidate>[candidateFor(original, sizeInBytes: 9000000)],
      );

      expect(report.skippedCount, 1);
      expect(await original.length(), 9000000);
    });

    test('an output whose header will not parse is thrown away', () async {
      final File original = await writeJpeg('a.jpg', sizeInBytes: 9000000);

      final OptimizeReport report = await run(
        repoWith(FakeMediaEncoder(outputBytes: 3000000, writeGarbage: true)),
        <MediaCandidate>[candidateFor(original, sizeInBytes: 9000000)],
      );

      expect(report.skippedCount, 1);
      expect(await original.length(), 9000000);
    });

    test('an encoder that threw leaves the original untouched', () async {
      final File original = await writeJpeg('a.jpg', sizeInBytes: 9000000);

      final OptimizeReport report = await run(
        repoWith(FakeMediaEncoder(throwsAfter: 0)),
        <MediaCandidate>[candidateFor(original, sizeInBytes: 9000000)],
      );

      expect(report.failedCount, 1);
      expect(await original.length(), 9000000);
      expect(_names(workspace), <String>['a.jpg']);
    });

    test('an encoder that wrote nothing at all is a skip, not a loss',
        () async {
      final File original = await writeJpeg('a.jpg', sizeInBytes: 9000000);

      final OptimizeReport report = await run(
        repoWith(FakeMediaEncoder(writeNothing: true)),
        <MediaCandidate>[candidateFor(original, sizeInBytes: 9000000)],
      );

      expect(report.skippedCount, 1);
      expect(original.existsSync(), isTrue);
    });

    test('one file failing does not stop the ones after it', () async {
      final File bad = await writeJpeg('bad.jpg', sizeInBytes: 9000000);
      final File good = await writeJpeg('good.jpg', sizeInBytes: 9000000);

      final OptimizeReport report = await run(
        repoWith(FakeMediaEncoder(shrinkTo: 0.3, failPaths: <String>{bad.path})),
        <MediaCandidate>[
          candidateFor(bad, sizeInBytes: 9000000),
          candidateFor(good, sizeInBytes: 9000000),
        ],
      );

      expect(report.failedCount, 1);
      expect(report.optimizedCount, 1);
      expect(await bad.length(), 9000000);
      expect(await good.length(), lessThan(9000000));
    });
  });

  group('the destination', () {
    test('a rename onto a name already taken is refused outright', () async {
      // Not resolved by inventing `shot (2).jpg`. A user who finds that beside
      // a missing `shot.png` has been handed a puzzle instead of a result.
      final File original = await writeJpeg('shot.png', sizeInBytes: 12000000);
      await writeJpeg('shot.jpg', sizeInBytes: 500000);

      final OptimizeReport report = await run(
        repoWith(FakeMediaEncoder(outputBytes: 2000000)),
        <MediaCandidate>[
          candidateFor(
            original,
            sizeInBytes: 12000000,
            source: MediaContainer.png,
          ),
        ],
      );

      expect(report.skippedCount, 1);
      expect(report.optimizedCount, 0);
      expect(await original.length(), 12000000);
      expect(_names(workspace), <String>['shot.jpg', 'shot.png']);
    });

    test('the working file is written beside the original, not in temp',
        () async {
      // A rename across volumes is a copy, and the system temporary directory
      // is routinely on a different one — which would mean writing four
      // gigabytes twice to free two.
      final File original = await writeJpeg('a.jpg', sizeInBytes: 9000000);
      final FakeMediaEncoder encoder = FakeMediaEncoder(outputBytes: 3000000);

      await run(repoWith(encoder), <MediaCandidate>[
        candidateFor(original, sizeInBytes: 9000000),
      ]);

      expect(p.dirname(encoder.lastOutputPath!), workspace.path);
      expect(
        p.basename(encoder.lastOutputPath!),
        startsWith(AppOptimizerPolicy.workingPrefix),
      );
    });
  });

  group('cancelling', () {
    test('reports what it managed and says it was stopped', () async {
      // The opposite ending to a cancelled scan. Files are already rewritten
      // and the count is owed to the user.
      final File a = await writeJpeg('a.jpg', sizeInBytes: 9000000);
      final File b = await writeJpeg('b.jpg', sizeInBytes: 9000000);

      final IoMediaOptimizeRepo repo =
          repoWith(FakeMediaEncoder(shrinkTo: 0.3));
      final OptimizeJob job = repo.optimize(
        candidates: <MediaCandidate>[
          candidateFor(a, sizeInBytes: 9000000),
          candidateFor(b, sizeInBytes: 9000000),
        ],
      );

      OptimizeReport? report;

      await for (final OptimizeUpdate update in job.updates) {
        if (update is OptimizeProgress && update.doneCount == 1) {
          await job.cancel();
        }

        if (update is OptimizeFinished) {
          report = update.report;
        }
      }

      expect(report, isNotNull);
      expect(report!.wasCancelled, isTrue);
      expect(report.optimizedCount, 1);
      // The second file is untouched rather than half-written.
      expect(await b.length(), 9000000);
    });
  });

  group('what a crashed run left behind', () {
    test('a working file is swept before the next run starts', () async {
      final File original = await writeJpeg('a.jpg', sizeInBytes: 9000000);
      final File leftover = File(
        p.join(workspace.path, '${AppOptimizerPolicy.workingPrefix}a.jpg'),
      );
      await leftover.writeAsBytes(Uint8List(1000));

      await run(
        repoWith(FakeMediaEncoder(outputBytes: 3000000)),
        <MediaCandidate>[candidateFor(original, sizeInBytes: 9000000)],
      );

      expect(_names(workspace), <String>['a.jpg']);
    });

    test('a moved-aside original is put back rather than deleted', () async {
      // The one case the ladder cannot clean up after itself: a process killed
      // between the two renames. What is on disk under the suffix is the user's
      // file, so it goes back where it came from.
      final File stranded = File(
        p.join(workspace.path, 'b.jpg${AppOptimizerPolicy.supersededSuffix}'),
      );
      await stranded.writeAsBytes(Uint8List(7777));

      final File original = await writeJpeg('a.jpg', sizeInBytes: 9000000);

      await run(
        repoWith(FakeMediaEncoder(outputBytes: 3000000)),
        <MediaCandidate>[candidateFor(original, sizeInBytes: 9000000)],
      );

      expect(_names(workspace), <String>['a.jpg', 'b.jpg']);
      expect(await File(p.join(workspace.path, 'b.jpg')).length(), 7777);
    });

    test('and is left alone where the real name is occupied', () async {
      // Both on disk is the safe answer: the user has their file either way.
      final File taken = await writeJpeg('b.jpg', sizeInBytes: 1200000);
      final File stranded = File(
        p.join(workspace.path, 'b.jpg${AppOptimizerPolicy.supersededSuffix}'),
      );
      await stranded.writeAsBytes(Uint8List(7777));

      final File original = await writeJpeg('a.jpg', sizeInBytes: 9000000);

      await run(
        repoWith(FakeMediaEncoder(outputBytes: 3000000)),
        <MediaCandidate>[candidateFor(original, sizeInBytes: 9000000)],
      );

      expect(stranded.existsSync(), isTrue);
      expect(await taken.length(), 1200000);
    });

    test('the leavings of a build under the old name are swept too', () async {
      // The two names changed with the rename; what is lying in the folder did
      // not. A sweeper that only knew the current pair would walk past both —
      // and the superseded one is the user's file, stranded under a name
      // nothing recognises any more.
      final File stranded = File(
        p.join(
          workspace.path,
          'b.jpg${AppOptimizerPolicy.legacySupersededSuffix}',
        ),
      );
      await stranded.writeAsBytes(Uint8List(7777));

      final File halfEncoded = File(
        p.join(workspace.path, '${AppOptimizerPolicy.legacyWorkingPrefix}c.jpg'),
      );
      await halfEncoded.writeAsBytes(Uint8List(1000));

      final File original = await writeJpeg('a.jpg', sizeInBytes: 9000000);

      await run(
        repoWith(FakeMediaEncoder(outputBytes: 3000000)),
        <MediaCandidate>[candidateFor(original, sizeInBytes: 9000000)],
      );

      // `b.jpg`, not `b.jpg.archonex-o`: the suffix trimmed is the one that
      // matched, so the file comes back under the name the user gave it.
      expect(_names(workspace), <String>['a.jpg', 'b.jpg']);
      expect(await File(p.join(workspace.path, 'b.jpg')).length(), 7777);
    });
  });

  group('support', () {
    test('is the two encoders asked, not the platform guessed at', () async {
      final IoMediaOptimizeRepo repo = IoMediaOptimizeRepo(
        photoEncoder: FakeMediaEncoder(outputBytes: 1),
        videoEncoder: FakeMediaEncoder(outputBytes: 1, available: false),
      );

      final EncoderSupport support = await repo.support();

      expect(support.photos, isTrue);
      expect(support.videos, isFalse);
      expect(support.isPartial, isTrue);
    });
  });
}

List<String> _names(Directory directory) =>
    directory.listSync().map((entity) => p.basename(entity.path)).toList()..sort();
