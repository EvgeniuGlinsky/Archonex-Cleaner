import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:storage_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/data/file_system/insights_roots_resolver.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/data/file_system/io_storage_insights_repo.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/insights_failure.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/insights_scan_job.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/insights_update.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/storage_slice.dart';

/// The walk, against a real temporary directory.
///
/// One of the deliberate exceptions the Test fakes section of the skill allows,
/// and it earns it the same way `IoQuarantineRepo` does: adding up what is in a
/// directory tree *is* the whole behaviour, and a fake file system would be
/// testing the fake.
void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('storage_cleaner_insights_');
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      await workspace.delete(recursive: true);
    }
  });

  Future<void> write(String relative, int bytes) async {
    final File file = File(p.join(workspace.path, relative));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(List<int>.filled(bytes, 0), flush: true);
  }

  IoStorageInsightsRepo repo() => IoStorageInsightsRepo(
        resolver: _FixedRoots(<String>[workspace.path]),
      );

  Future<Map<StorageSliceCategory, int>> measure(
    IoStorageInsightsRepo repo, {
    void Function(InsightsScanJob job)? onFirstBatch,
  }) async {
    final InsightsScanJob job = await repo.measure(const StorageAccess.open());
    final Map<StorageSliceCategory, int> totals =
        <StorageSliceCategory, int>{};
    bool first = true;

    await for (final InsightsUpdate update in job.updates) {
      if (update is! InsightsMeasured) {
        continue;
      }

      for (final StorageSlice slice in update.slices) {
        totals[slice.category] = (totals[slice.category] ?? 0) + slice.bytes;
      }

      if (first) {
        first = false;
        onFirstBatch?.call(job);
      }
    }

    return totals;
  }

  test('every file lands in a slice, and the slices add up', () async {
    await write('DCIM/IMG_0001.jpg', 1000);
    await write('DCIM/VID_0001.mp4', 4000);
    await write('Music/track.mp3', 2000);
    await write('Download/manual.pdf', 500);
    await write('Download/backup.zip', 700);
    await write('Download/LICENSE', 300);

    final Map<StorageSliceCategory, int> totals = await measure(repo());

    expect(totals[StorageSliceCategory.photos], 1000);
    expect(totals[StorageSliceCategory.videos], 4000);
    expect(totals[StorageSliceCategory.audio], 2000);
    expect(totals[StorageSliceCategory.documents], 500);
    expect(totals[StorageSliceCategory.archives], 700);
    expect(totals[StorageSliceCategory.other], 300);
    expect(totals.values.fold<int>(0, (sum, bytes) => sum + bytes), 8500);
  });

  test('it descends into folders it has never heard of', () async {
    // The walk starts at the top of the volume rather than at a list of known
    // folders, which is the whole difference from the other two.
    await write('Android/media/com.whatsapp/WhatsApp/Media/VID.mp4', 9000);

    final Map<StorageSliceCategory, int> totals = await measure(repo());

    expect(totals[StorageSliceCategory.videos], 9000);
  });

  test('an empty file is not counted', () async {
    await write('DCIM/placeholder.jpg', 0);

    expect(await measure(repo()), isEmpty);
  });

  test('cancelling ends the stream with a failure, not half an answer',
      () async {
    // Half a disk measured is a chart that adds up to nothing anybody can act
    // on, and unlike a cleanup nothing was written that the user is owed a
    // count of.
    for (int index = 0; index < 40; index++) {
      await write('DCIM/IMG_$index.jpg', 1000);
    }

    final InsightsScanJob job = await repo().measure(const StorageAccess.open());

    await expectLater(
      job.updates.map((update) {
        unawaitedCancel(job);

        return update;
      }),
      emitsThrough(emitsError(isA<InsightsScanCancelledFailure>())),
    );
  });

  test('a root that is not there is not an error', () async {
    // A folder can vanish between being resolved and being walked, and a chart
    // that refuses to draw because of it would be worse than one missing a
    // slice.
    final IoStorageInsightsRepo missing = IoStorageInsightsRepo(
      resolver: _FixedRoots(<String>[p.join(workspace.path, 'gone')]),
    );

    expect(await measure(missing), isEmpty);
  });
}

/// Cancels without awaiting, from inside a stream listener.
void unawaitedCancel(InsightsScanJob job) {
  job.cancel();
}

/// Stands in for the platform question the resolver answers, so the walk can be
/// pointed at a temporary directory.
class _FixedRoots implements InsightsRootsResolver {
  const _FixedRoots(this._roots);

  final List<String> _roots;

  @override
  Future<List<String>> resolve(StorageAccess access) async => _roots;
}
