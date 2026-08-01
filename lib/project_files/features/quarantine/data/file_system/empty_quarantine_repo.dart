import 'package:flutter/foundation.dart';

import 'package:storage_cleaner/project_files/features/quarantine/domain/models/quarantine_batch.dart';
import 'package:storage_cleaner/project_files/features/quarantine/domain/quarantine_repo.dart';
import 'package:storage_cleaner/project_files/features/quarantine/domain/quarantine_writer.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/junk_item.dart';

/// The web sibling of `IoQuarantineRepo`.
///
/// Named for what it does rather than `unsupported_`, the way
/// `FreeOnlySubscriptionRepo` is in the Converter: it does not refuse. Every
/// call succeeds and answers with nothing, because a quarantine on a platform
/// that can delete nothing is permanently, correctly empty — and a screen
/// reading `batchesListenable` should render an empty list rather than handle
/// an exception for a state that is not an error.
class EmptyQuarantineRepo implements QuarantineRepo {
  EmptyQuarantineRepo();

  final ValueNotifier<List<QuarantineBatch>> _batches =
      ValueNotifier<List<QuarantineBatch>>(const <QuarantineBatch>[]);

  @override
  ValueListenable<List<QuarantineBatch>> get batchesListenable => _batches;

  @override
  Future<void> load() async {}

  @override
  Future<QuarantineWriter> openBatch() async => const _NoQuarantineWriter();

  @override
  Future<void> restore(String batchId) async {}

  @override
  Future<void> purge(String batchId) async {}

  @override
  Future<void> purgeAll() async {}

  @override
  Future<void> purgeExpired() async {}
}

class _NoQuarantineWriter implements QuarantineWriter {
  const _NoQuarantineWriter();

  @override
  Future<bool> keep(JunkItem item) async => false;

  @override
  Future<QuarantineBatch?> commit() async => null;
}
