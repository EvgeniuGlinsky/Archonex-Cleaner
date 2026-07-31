import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:archonex_cleaner/project_files/features/quarantine/data/use_cases/purge_quarantine_use_case.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/data/use_cases/restore_quarantine_batch_use_case.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/data/use_cases/watch_quarantine_use_case.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/domain/models/quarantine_batch.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/domain/models/restore_failure.dart';

part 'quarantine_event.dart';
part 'quarantine_state.dart';

class QuarantineBloc extends Bloc<QuarantineEvent, QuarantineState> {
  QuarantineBloc({
    required WatchQuarantineUseCase watchQuarantine,
    required RestoreQuarantineBatchUseCase restoreBatch,
    required PurgeQuarantineUseCase purge,
  })  : _watchQuarantine = watchQuarantine,
        _restoreBatch = restoreBatch,
        _purge = purge,
        super(const QuarantineState()) {
    on<QuarantineStarted>(_onStarted, transformer: restartable());
    on<BatchesChanged>(_onBatchesChanged, transformer: sequential());

    // Each of these deletes or moves real files. `droppable()` so a double tap
    // on Restore cannot start a second run against a batch the first has
    // already half emptied.
    on<BatchRestoreRequested>(_onRestoreRequested, transformer: droppable());
    on<BatchPurgeRequested>(_onPurgeRequested, transformer: droppable());
    on<PurgeAllRequested>(_onPurgeAllRequested, transformer: droppable());

    on<QuarantineNoticeDismissed>(_onNoticeDismissed,
        transformer: sequential());
  }

  final WatchQuarantineUseCase _watchQuarantine;
  final RestoreQuarantineBatchUseCase _restoreBatch;
  final PurgeQuarantineUseCase _purge;

  StreamSubscription<List<QuarantineBatch>>? _subscription;

  @override
  Future<void> close() async {
    await _subscription?.cancel();

    return super.close();
  }

  Future<void> _onStarted(
    QuarantineStarted event,
    Emitter<QuarantineState> emit,
  ) async {
    await _subscription?.cancel();
    _subscription =
        _watchQuarantine().listen((batches) => add(BatchesChanged(batches)));
  }

  void _onBatchesChanged(
    BatchesChanged event,
    Emitter<QuarantineState> emit,
  ) {
    emit(
      state.copyWith(
        // A change arriving while a restore is in flight is that restore
        // landing, so the screen leaves `working` here rather than in the
        // handler that started it.
        status: state.status == QuarantineStatus.restored
            ? QuarantineStatus.restored
            : QuarantineStatus.ready,
        batches: event.batches,
      ),
    );
  }

  Future<void> _onRestoreRequested(
    BatchRestoreRequested event,
    Emitter<QuarantineState> emit,
  ) async {
    emit(state.copyWith(status: QuarantineStatus.working, clearFailure: true));

    try {
      await _restoreBatch(event.batchId);
      emit(state.copyWith(status: QuarantineStatus.restored));
    } on RestoreFailure catch (failure) {
      emit(state.copyWith(status: QuarantineStatus.ready, failure: failure));
    }
  }

  Future<void> _onPurgeRequested(
    BatchPurgeRequested event,
    Emitter<QuarantineState> emit,
  ) async {
    emit(state.copyWith(status: QuarantineStatus.working, clearFailure: true));
    await _purge(batchId: event.batchId);
    emit(state.copyWith(status: QuarantineStatus.ready));
  }

  Future<void> _onPurgeAllRequested(
    PurgeAllRequested event,
    Emitter<QuarantineState> emit,
  ) async {
    emit(state.copyWith(status: QuarantineStatus.working, clearFailure: true));
    await _purge();
    emit(state.copyWith(status: QuarantineStatus.ready));
  }

  void _onNoticeDismissed(
    QuarantineNoticeDismissed event,
    Emitter<QuarantineState> emit,
  ) {
    emit(
      state.copyWith(status: QuarantineStatus.ready, clearFailure: true),
    );
  }
}
