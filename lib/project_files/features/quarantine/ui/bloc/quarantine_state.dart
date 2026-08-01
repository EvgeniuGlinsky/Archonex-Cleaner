part of 'quarantine_bloc.dart';

enum QuarantineStatus { loading, ready, working, restored }

final class QuarantineState extends Equatable {
  const QuarantineState({
    this.status = QuarantineStatus.loading,
    this.batches = const <QuarantineBatch>[],
    this.failure,
  });

  final QuarantineStatus status;

  /// Newest first, as the repository publishes them.
  final List<QuarantineBatch> batches;

  final QuarantineFailure? failure;

  bool get isEmpty => batches.isEmpty;

  bool get isBusy => status == QuarantineStatus.working;

  int get totalBytes =>
      batches.fold(0, (sum, batch) => sum + batch.totalBytes);

  int get totalFileCount =>
      batches.fold(0, (sum, batch) => sum + batch.fileCount);

  /// Whether emptying the whole thing is worth offering.
  bool get canPurgeAll => !isEmpty && !isBusy;

  bool get canAct => !isBusy;

  QuarantineState copyWith({
    QuarantineStatus? status,
    List<QuarantineBatch>? batches,
    QuarantineFailure? failure,
    bool clearFailure = false,
  }) {
    return QuarantineState(
      status: status ?? this.status,
      batches: batches ?? this.batches,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  List<Object?> get props => <Object?>[status, batches, failure];
}
