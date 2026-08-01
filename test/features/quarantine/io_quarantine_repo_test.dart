import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:storage_cleaner/core/constants/app_quarantine_policy.dart';
import 'package:storage_cleaner/project_files/features/quarantine/data/file_system/io_quarantine_repo.dart';
import 'package:storage_cleaner/project_files/features/quarantine/domain/models/quarantine_batch.dart';
import 'package:storage_cleaner/project_files/features/quarantine/domain/models/quarantine_failure.dart';
import 'package:storage_cleaner/project_files/features/quarantine/domain/quarantine_writer.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/junk_category.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/junk_item.dart';

/// The one data-layer class with a test, and it earns it: this is what stands
/// between a cleanup and a set of files nobody can put back. It runs against a
/// real temporary directory, because moving a file between two paths is the
/// whole behaviour and a fake file system would be testing the fake.
///
/// The clock is injected, so a seven-day retention is a literal rather than a
/// week of waiting.
void main() {
  late Directory root;
  late Directory workspace;
  late DateTime now;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('storage_cleaner_quarantine_test_');
    workspace = Directory(p.join(root.path, 'workspace'));
    await workspace.create();
    now = DateTime.utc(2026, 7, 31, 12);
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  IoQuarantineRepo repo() => IoQuarantineRepo(
        now: () => now,
        directory: Directory(p.join(root.path, 'quarantine')),
      );

  Future<JunkItem> writeFile(String name, {int bytes = 16}) async {
    final File file = File(p.join(workspace.path, name));
    await file.writeAsBytes(List<int>.filled(bytes, 0));

    return JunkItem(
      path: file.path,
      name: name,
      sizeInBytes: bytes,
      category: JunkCategory.systemTemp,
      modifiedAt: now.subtract(const Duration(days: 2)),
    );
  }

  Future<JunkItem> writeDirectory(String name) async {
    final Directory directory = Directory(p.join(workspace.path, name));
    await directory.create();
    await File(p.join(directory.path, 'inner.tmp')).writeAsString('x');

    return JunkItem(
      path: directory.path,
      name: name,
      sizeInBytes: 1,
      category: JunkCategory.thumbnails,
      modifiedAt: now.subtract(const Duration(days: 2)),
      isDirectory: true,
    );
  }

  group('keeping', () {
    test('moves the file out of the way rather than copying it', () async {
      final IoQuarantineRepo quarantine = repo();
      await quarantine.load();

      final JunkItem item = await writeFile('a.tmp');
      final QuarantineWriter writer = await quarantine.openBatch();

      expect(await writer.keep(item), isTrue);

      // Freeing space is the point: a copy would leave the original in place.
      expect(await File(item.path).exists(), isFalse);

      final QuarantineBatch? batch = await writer.commit();
      expect(batch, isNotNull);
      expect(batch!.fileCount, 1);
    });

    test('takes a directory whole', () async {
      final IoQuarantineRepo quarantine = repo();
      await quarantine.load();

      final JunkItem item = await writeDirectory('.thumbnails');
      final QuarantineWriter writer = await quarantine.openBatch();

      expect(await writer.keep(item), isTrue);
      expect(await Directory(item.path).exists(), isFalse);
      await writer.commit();
    });

    test('declines a file too large to keep a copy of', () async {
      final IoQuarantineRepo quarantine = repo();
      await quarantine.load();

      final JunkItem huge = JunkItem(
        path: p.join(workspace.path, 'dump.dmp'),
        name: 'dump.dmp',
        sizeInBytes: AppQuarantinePolicy.maxEntryBytes + 1,
        category: JunkCategory.crashDumps,
        modifiedAt: now,
      );

      final QuarantineWriter writer = await quarantine.openBatch();

      // Declining is the whole point: quarantining it would move the bytes and
      // free nothing until the retention expires.
      expect(await writer.keep(huge), isFalse);
      expect(await writer.commit(), isNull);
    });

    test('two files with the same name do not collide', () async {
      final IoQuarantineRepo quarantine = repo();
      await quarantine.load();

      final Directory other = Directory(p.join(workspace.path, 'other'));
      await other.create();
      final File second = File(p.join(other.path, 'cache.db'));
      await second.writeAsString('second');

      final JunkItem first = await writeFile('cache.db');
      final JunkItem duplicate = JunkItem(
        path: second.path,
        name: 'cache.db',
        sizeInBytes: 6,
        category: JunkCategory.systemTemp,
        modifiedAt: now,
      );

      final QuarantineWriter writer = await quarantine.openBatch();
      expect(await writer.keep(first), isTrue);
      expect(await writer.keep(duplicate), isTrue);

      final QuarantineBatch batch = (await writer.commit())!;
      expect(
        batch.entries.map((entry) => entry.storedName).toSet().length,
        2,
      );
    });

    test('a batch that kept nothing leaves no directory behind', () async {
      final Directory quarantineDirectory =
          Directory(p.join(root.path, 'quarantine'));
      final IoQuarantineRepo quarantine = repo();
      await quarantine.load();

      final QuarantineWriter writer = await quarantine.openBatch();
      expect(await writer.commit(), isNull);

      final List<FileSystemEntity> entries =
          await quarantineDirectory.list().toList();

      expect(
        entries.whereType<Directory>(),
        isEmpty,
        reason: 'an empty batch should not create a directory',
      );
    });
  });

  group('restoring', () {
    test('puts every file back where it came from', () async {
      final IoQuarantineRepo quarantine = repo();
      await quarantine.load();

      final JunkItem item = await writeFile('a.tmp');
      final QuarantineWriter writer = await quarantine.openBatch();
      await writer.keep(item);
      final QuarantineBatch batch = (await writer.commit())!;

      await quarantine.restore(batch.id);

      expect(await File(item.path).exists(), isTrue);
      expect(quarantine.batchesListenable.value, isEmpty);
    });

    test('refuses before moving anything when a destination is taken',
        () async {
      final IoQuarantineRepo quarantine = repo();
      await quarantine.load();

      final JunkItem first = await writeFile('a.tmp');
      final JunkItem second = await writeFile('b.tmp');
      final QuarantineWriter writer = await quarantine.openBatch();
      await writer.keep(first);
      await writer.keep(second);
      final QuarantineBatch batch = (await writer.commit())!;

      // Something is at the old path again.
      await File(second.path).writeAsString('new content');

      await expectLater(
        quarantine.restore(batch.id),
        throwsA(isA<RestoreTargetOccupiedFailure>()),
      );

      // Half a restore is worse than none, so the other file stayed put too.
      expect(await File(first.path).exists(), isFalse);
      expect(quarantine.batchesListenable.value, hasLength(1));
    });

    test('reports how a partial restore split', () async {
      final IoQuarantineRepo quarantine = repo();
      await quarantine.load();

      final JunkItem first = await writeFile('a.tmp');
      final JunkItem second = await writeFile('b.tmp');
      final QuarantineWriter writer = await quarantine.openBatch();
      await writer.keep(first);
      await writer.keep(second);
      final QuarantineBatch batch = (await writer.commit())!;

      // The quarantine emptied from outside the app.
      await File(
        p.join(root.path, 'quarantine', batch.id, batch.entries.last.storedName),
      ).delete();

      await expectLater(
        quarantine.restore(batch.id),
        throwsA(
          isA<PartialRestoreFailure>()
              .having((f) => f.restoredCount, 'restored', 1)
              .having((f) => f.lostCount, 'lost', 1),
        ),
      );

      expect(await File(first.path).exists(), isTrue);
    });
  });

  group('retention', () {
    test('a batch inside its window survives the sweep', () async {
      final IoQuarantineRepo quarantine = repo();
      await quarantine.load();

      final QuarantineWriter writer = await quarantine.openBatch();
      await writer.keep(await writeFile('a.tmp'));
      await writer.commit();

      now = now.add(AppQuarantinePolicy.retention - const Duration(hours: 1));
      await quarantine.purgeExpired();

      expect(quarantine.batchesListenable.value, hasLength(1));
    });

    test('a batch past its window is swept', () async {
      final IoQuarantineRepo quarantine = repo();
      await quarantine.load();

      final QuarantineWriter writer = await quarantine.openBatch();
      final JunkItem item = await writeFile('a.tmp');
      await writer.keep(item);
      await writer.commit();

      now = now.add(AppQuarantinePolicy.retention + const Duration(hours: 1));
      await quarantine.purgeExpired();

      expect(quarantine.batchesListenable.value, isEmpty);
      expect(await File(item.path).exists(), isFalse);
    });

    test('the countdown never goes negative', () async {
      final IoQuarantineRepo quarantine = repo();
      await quarantine.load();

      final QuarantineWriter writer = await quarantine.openBatch();
      await writer.keep(await writeFile('a.tmp'));
      final QuarantineBatch batch = (await writer.commit())!;

      expect(
        batch.daysLeftAt(now.add(const Duration(days: 100))),
        0,
      );
    });
  });

  group('the manifest', () {
    test('survives a restart', () async {
      final IoQuarantineRepo first = repo();
      await first.load();

      final QuarantineWriter writer = await first.openBatch();
      await writer.keep(await writeFile('a.tmp'));
      final QuarantineBatch batch = (await writer.commit())!;

      final IoQuarantineRepo second = repo();
      await second.load();

      expect(second.batchesListenable.value.map((b) => b.id), <String>[batch.id]);
      expect(second.batchesListenable.value.single.fileCount, 1);
    });

    test('an unreadable manifest reports nothing rather than throwing',
        () async {
      final Directory quarantineDirectory =
          Directory(p.join(root.path, 'quarantine'));
      await quarantineDirectory.create(recursive: true);
      await File(
        p.join(quarantineDirectory.path, AppQuarantinePolicy.manifestName),
      ).writeAsString('{ not json at all');

      final IoQuarantineRepo quarantine = repo();

      await quarantine.load();

      expect(quarantine.batchesListenable.value, isEmpty);
    });
  });

  test('purging one batch leaves the others alone', () async {
    final IoQuarantineRepo quarantine = repo();
    await quarantine.load();

    final QuarantineWriter first = await quarantine.openBatch();
    await first.keep(await writeFile('a.tmp'));
    final QuarantineBatch batchA = (await first.commit())!;

    now = now.add(const Duration(minutes: 1));

    final QuarantineWriter second = await quarantine.openBatch();
    await second.keep(await writeFile('b.tmp'));
    final QuarantineBatch batchB = (await second.commit())!;

    await quarantine.purge(batchA.id);

    expect(
      quarantine.batchesListenable.value.map((batch) => batch.id),
      <String>[batchB.id],
    );
  });

  test('batches are published newest first', () async {
    final IoQuarantineRepo quarantine = repo();
    await quarantine.load();

    final QuarantineWriter first = await quarantine.openBatch();
    await first.keep(await writeFile('a.tmp'));
    final QuarantineBatch older = (await first.commit())!;

    now = now.add(const Duration(minutes: 5));

    final QuarantineWriter second = await quarantine.openBatch();
    await second.keep(await writeFile('b.tmp'));
    final QuarantineBatch newer = (await second.commit())!;

    expect(
      quarantine.batchesListenable.value.map((batch) => batch.id),
      <String>[newer.id, older.id],
    );
  });
}
