import 'dart:async';

import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/junk_clean_repo.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/clean_failure.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/clean_job.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/clean_update.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/junk_item.dart';

/// The web sibling of `IoJunkCleanRepo`. See `UnsupportedJunkScanRepo`.
///
/// Unreachable in practice — nothing can be found, so nothing can be selected,
/// so the button is never enabled — and it refuses anyway, because "unreachable
/// in practice" is a statement about today's UI.
class UnsupportedJunkCleanRepo implements JunkCleanRepo {
  const UnsupportedJunkCleanRepo();

  @override
  bool get isSupported => false;

  @override
  CleanJob clean({required List<JunkItem> items, bool quarantine = true}) =>
      const _RefusingCleanJob();
}

class _RefusingCleanJob implements CleanJob {
  const _RefusingCleanJob();

  @override
  Stream<CleanUpdate> get updates =>
      Stream<CleanUpdate>.error(const CleanUnsupportedFailure());

  @override
  Future<void> cancel() async {}
}
