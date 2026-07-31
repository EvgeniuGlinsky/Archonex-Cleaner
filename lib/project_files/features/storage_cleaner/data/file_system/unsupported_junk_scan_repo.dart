import 'dart:async';

import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/junk_scan_repo.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/clean_failure.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_category.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/scan_job.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/scan_update.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/storage_access.dart';

/// The web answer: there is no file system, so there is nothing to walk.
///
/// It refuses rather than returning an empty result, because an empty result
/// reads as "your device is clean" and the truth is "this build cannot look".
/// Capability getters still answer, so the screen explains itself instead of
/// waiting for a scan that will never start.
class UnsupportedJunkScanRepo implements JunkScanRepo {
  const UnsupportedJunkScanRepo();

  @override
  bool get isSupported => false;

  @override
  Future<Set<JunkCategory>> categoriesFor(StorageAccess access) async =>
      const <JunkCategory>{};

  @override
  Future<ScanJob> scan({
    required Set<JunkCategory> categories,
    required StorageAccess access,
  }) async =>
      const _RefusingScanJob();
}

class _RefusingScanJob implements ScanJob {
  const _RefusingScanJob();

  @override
  Stream<ScanUpdate> get updates =>
      Stream<ScanUpdate>.error(const CleanUnsupportedFailure());

  @override
  Future<void> cancel() async {}
}
