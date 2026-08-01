import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:storage_cleaner/project_files/features/storage_cleaner/data/file_system/io_junk_clean_repo.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/clean_job.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/clean_report.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/clean_update.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/junk_category.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/junk_item.dart';

import 'fakes.dart';

/// Driven against a real temporary directory rather than a fake file system,
/// for the reason `io_quarantine_repo_test.dart` gives for the same choice:
/// deleting a file *is* the whole behaviour, and a fake would be testing the
/// fake. What is under test here is narrower than deletion — it is the list the
/// report hands back of everything still sitting where it was found.
void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('storage_cleaner_clean_');
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      await workspace.delete(recursive: true);
    }
  });

  Future<JunkItem> write(String name) async {
    final File file = File(p.join(workspace.path, name));
    await file.writeAsString('junk');

    return JunkItem(
      path: file.path,
      name: name,
      sizeInBytes: await file.length(),
      category: JunkCategory.systemTemp,
      modifiedAt: DateTime(2026),
    );
  }

  Future<CleanReport> run(CleanJob job) async {
    final List<CleanUpdate> updates = await job.updates.toList();

    return updates.whereType<CleanFinished>().last.report;
  }

  test('a finished run leaves nothing behind to report', () async {
    final IoJunkCleanRepo repo =
        IoJunkCleanRepo(quarantine: FakeQuarantineRepo());

    final CleanReport report = await run(
      repo.clean(
        items: <JunkItem>[await write('a.tmp'), await write('b.tmp')],
        quarantine: false,
      ),
    );

    expect(report.permanentCount, 2);
    expect(report.remainingPaths, isEmpty);
  });

  // Cancelled before the first listener arrives, so the loop breaks on its
  // first check and every file is untouched. Deterministic on purpose: racing
  // a real cancellation against a two-file delete would pass for the wrong
  // reason about half the time.
  test('a cancelled run hands back everything it never reached', () async {
    final IoJunkCleanRepo repo =
        IoJunkCleanRepo(quarantine: FakeQuarantineRepo());

    final JunkItem first = await write('a.tmp');
    final JunkItem second = await write('b.tmp');

    final CleanJob job = repo.clean(
      items: <JunkItem>[first, second],
      quarantine: false,
    );
    await job.cancel();

    final CleanReport report = await run(job);

    expect(report.wasCancelled, isTrue);
    expect(report.deletedCount, 0);
    expect(report.remainingPaths, <String>{first.path, second.path});

    // The point of the list: both are still on disk, so both must still be on
    // the screen. A report that only counted them could not say which.
    expect(File(first.path).existsSync(), isTrue);
    expect(File(second.path).existsSync(), isTrue);
  });

  test('a file that is already gone is not reported as still there', () async {
    final IoJunkCleanRepo repo =
        IoJunkCleanRepo(quarantine: FakeQuarantineRepo());

    final JunkItem vanished = await write('a.tmp');
    await File(vanished.path).delete();

    final CleanReport report = await run(
      repo.clean(items: <JunkItem>[vanished], quarantine: false),
    );

    // It counts as skipped — the deleter could not do anything with it — but
    // the row would be a lie either way, and a rescan is what settles it.
    expect(report.skippedCount, 1);
    expect(report.remainingPaths, <String>{vanished.path});
  });
}
