import 'package:equatable/equatable.dart';

import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/clean_report.dart';

/// What a running cleanup reports.
sealed class CleanUpdate {
  const CleanUpdate();
}

/// How far the queue has got.
///
/// Counts files rather than bytes because a cleanup is thousands of tiny files
/// and two large ones, and a bar driven by bytes sits still and then jumps.
/// `Equatable` mixed in rather than extended, because the sealed parent already
/// takes the extends slot — and the bloc state holds one of these, so identity
/// equality would rebuild the screen on every tick regardless.
final class CleanProgress extends CleanUpdate with Equatable {
  const CleanProgress({
    required this.doneCount,
    required this.totalCount,
    required this.freedBytes,
  });

  final int doneCount;
  final int totalCount;

  /// Freed so far — the number the screen counts up.
  final int freedBytes;

  double get fraction => totalCount == 0 ? 0 : doneCount / totalCount;

  @override
  List<Object?> get props => <Object?>[doneCount, totalCount, freedBytes];
}

/// The run is over and this is what it did.
///
/// Always the last event, and the stream closes normally afterwards — including
/// after a cancellation, which is why `CleanReport.wasCancelled` exists. What
/// was already deleted stays deleted, so a cancelled run still owes the user a
/// count, and an error-terminated stream would throw that count away.
final class CleanFinished extends CleanUpdate {
  const CleanFinished(this.report);

  final CleanReport report;
}
