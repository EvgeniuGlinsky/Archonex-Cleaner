import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:archonex_cleaner/project_files/features/quarantine/domain/models/quarantine_batch.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/domain/quarantine_repo.dart';

/// Adapts the repository's `ValueListenable` to the `Stream` a bloc lives on.
///
/// The same shape the Converter's `watch*UseCase`s have, and for the same
/// reason: a repository that outlives a screen publishes changes as a
/// listenable, and a bloc consumes a stream. Two screens read this one — the
/// quarantine list and the banner on the cleaner — so both see a cleanup land
/// without either asking.
class WatchQuarantineUseCase {
  const WatchQuarantineUseCase(this._repo);

  final QuarantineRepo _repo;

  Stream<List<QuarantineBatch>> call() {
    final ValueListenable<List<QuarantineBatch>> listenable =
        _repo.batchesListenable;

    late final StreamController<List<QuarantineBatch>> controller;

    void publish() => controller.add(listenable.value);

    controller = StreamController<List<QuarantineBatch>>(
      onListen: () {
        // The current value first: a screen opened after the cleanup has to see
        // the batch without waiting for the next change, which may never come.
        publish();
        listenable.addListener(publish);
      },
      onCancel: () => listenable.removeListener(publish),
    );

    return controller.stream;
  }
}
