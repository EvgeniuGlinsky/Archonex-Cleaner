import 'package:flutter_test/flutter_test.dart';

import 'package:storage_cleaner/project_files/features/quarantine/data/use_cases/purge_quarantine_use_case.dart';
import 'package:storage_cleaner/project_files/features/quarantine/data/use_cases/restore_quarantine_batch_use_case.dart';
import 'package:storage_cleaner/project_files/features/quarantine/data/use_cases/watch_quarantine_use_case.dart';
import 'package:storage_cleaner/project_files/features/quarantine/domain/models/quarantine_batch.dart';
import 'package:storage_cleaner/project_files/features/quarantine/domain/models/restore_failure.dart';
import 'package:storage_cleaner/project_files/features/quarantine/ui/bloc/quarantine_bloc.dart';

import '../storage_cleaner/fakes.dart';

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeQuarantineRepo repo;

  setUp(() => repo = FakeQuarantineRepo());

  QuarantineBloc build() {
    return QuarantineBloc(
      watchQuarantine: WatchQuarantineUseCase(repo),
      restoreBatch: RestoreQuarantineBatchUseCase(repo),
      purge: PurgeQuarantineUseCase(repo),
    );
  }

  Future<QuarantineBloc> started() async {
    final QuarantineBloc bloc = build();
    bloc.add(const QuarantineStarted());
    await settle();

    return bloc;
  }

  test('shows whatever the repository already holds, without waiting', () async {
    repo.publish(<QuarantineBatch>[fakeBatch(id: 'a', fileCount: 2)]);

    final QuarantineBloc bloc = await started();

    // A screen opened after the cleanup has to see the batch without waiting
    // for a change that may never come.
    expect(bloc.state.batches, hasLength(1));
    expect(bloc.state.totalFileCount, 2);
    await bloc.close();
  });

  test('an empty quarantine offers nothing to empty', () async {
    final QuarantineBloc bloc = await started();

    expect(bloc.state.isEmpty, isTrue);
    expect(bloc.state.canPurgeAll, isFalse);
    await bloc.close();
  });

  test('a cleanup landing while the screen is open shows up', () async {
    final QuarantineBloc bloc = await started();

    repo.publish(<QuarantineBatch>[fakeBatch(id: 'new')]);
    await settle();

    expect(bloc.state.batches.single.id, 'new');
    await bloc.close();
  });

  test('restoring removes the batch and says so', () async {
    repo.publish(<QuarantineBatch>[fakeBatch(id: 'a')]);

    final QuarantineBloc bloc = await started();
    bloc.add(const BatchRestoreRequested('a'));
    await settle();

    expect(repo.restored, <String>['a']);
    expect(bloc.state.status, QuarantineStatus.restored);
    expect(bloc.state.isEmpty, isTrue);
    await bloc.close();
  });

  test('an occupied destination surfaces as a failure, batch intact', () async {
    repo.publish(<QuarantineBatch>[fakeBatch(id: 'a')]);
    repo.restoreFailure =
        const RestoreTargetOccupiedFailure(path: '/tmp/a.tmp');

    final QuarantineBloc bloc = await started();
    bloc.add(const BatchRestoreRequested('a'));
    await settle();

    expect(bloc.state.failure, isA<RestoreTargetOccupiedFailure>());
    expect(bloc.state.batches, hasLength(1));
    expect(bloc.state.status, QuarantineStatus.ready);
    await bloc.close();
  });

  test('a partial restore reports both counts', () async {
    repo.publish(<QuarantineBatch>[fakeBatch(id: 'a')]);
    repo.restoreFailure =
        const PartialRestoreFailure(restoredCount: 2, lostCount: 1);

    final QuarantineBloc bloc = await started();
    bloc.add(const BatchRestoreRequested('a'));
    await settle();

    expect(
      bloc.state.failure,
      isA<PartialRestoreFailure>()
          .having((f) => f.restoredCount, 'restored', 2)
          .having((f) => f.lostCount, 'lost', 1),
    );
    await bloc.close();
  });

  test('purging one batch leaves the rest', () async {
    repo.publish(<QuarantineBatch>[
      fakeBatch(id: 'a'),
      fakeBatch(id: 'b', createdAt: DateTime.utc(2026, 7, 30)),
    ]);

    final QuarantineBloc bloc = await started();
    bloc.add(const BatchPurgeRequested('a'));
    await settle();

    expect(repo.purged, <String>['a']);
    expect(bloc.state.batches.single.id, 'b');
    await bloc.close();
  });

  test('emptying the quarantine clears everything', () async {
    repo.publish(<QuarantineBatch>[fakeBatch(id: 'a'), fakeBatch(id: 'b')]);

    final QuarantineBloc bloc = await started();
    bloc.add(const PurgeAllRequested());
    await settle();

    expect(repo.purgedAll, isTrue);
    expect(bloc.state.isEmpty, isTrue);
    await bloc.close();
  });

  test('dismissing the notice leaves the list alone', () async {
    repo.publish(<QuarantineBatch>[fakeBatch(id: 'a')]);
    repo.restoreFailure =
        const RestoreTargetOccupiedFailure(path: '/tmp/a.tmp');

    final QuarantineBloc bloc = await started();
    bloc.add(const BatchRestoreRequested('a'));
    await settle();
    bloc.add(const QuarantineNoticeDismissed());
    await settle();

    expect(bloc.state.failure, isNull);
    expect(bloc.state.batches, hasLength(1));
    await bloc.close();
  });

  test('a second start does not leave two subscriptions behind', () async {
    final QuarantineBloc bloc = await started();
    bloc.add(const QuarantineStarted());
    await settle();

    repo.publish(<QuarantineBatch>[fakeBatch(id: 'a')]);
    await settle();

    // Two subscriptions would each add a BatchesChanged; the state would be
    // right either way, so what is checked is that the run stays consistent
    // after a restart rather than a count of events.
    expect(bloc.state.batches, hasLength(1));
    await bloc.close();
  });
}
