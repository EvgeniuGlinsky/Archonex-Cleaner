part of 'quarantine_bloc.dart';

sealed class QuarantineEvent extends Equatable {
  const QuarantineEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Subscribes to the repository. A second start must not leave two
/// subscriptions behind — hence `restartable()`.
final class QuarantineStarted extends QuarantineEvent {
  const QuarantineStarted();
}

final class BatchesChanged extends QuarantineEvent {
  const BatchesChanged(this.batches);

  final List<QuarantineBatch> batches;

  @override
  List<Object?> get props => <Object?>[batches];
}

final class BatchRestoreRequested extends QuarantineEvent {
  const BatchRestoreRequested(this.batchId);

  final String batchId;

  @override
  List<Object?> get props => <Object?>[batchId];
}

final class BatchPurgeRequested extends QuarantineEvent {
  const BatchPurgeRequested(this.batchId);

  final String batchId;

  @override
  List<Object?> get props => <Object?>[batchId];
}

final class PurgeAllRequested extends QuarantineEvent {
  const PurgeAllRequested();
}

final class QuarantineNoticeDismissed extends QuarantineEvent {
  const QuarantineNoticeDismissed();
}
