import 'package:equatable/equatable.dart';

import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_report.dart';

/// Everything a running re-encode can say.
sealed class OptimizeUpdate {
  const OptimizeUpdate();
}

/// How far along the run is.
///
/// Two progressions rather than one, because they move at completely different
/// speeds and a single bar built from either is a lie. [doneCount] steps once
/// per file, which on a folder of videos can be once every two minutes;
/// [fileProgress] moves continuously inside the file being worked on, which is
/// the only thing that tells the user the app has not hung.
///
/// Mixes in `Equatable` rather than extending it — the sealed parent is not an
/// `Equatable` — because a state holding this needs value equality or the
/// screen rebuilds on every identical frame. `CleanProgress` does the same.
final class OptimizeProgress extends OptimizeUpdate with Equatable {
  const OptimizeProgress({
    required this.doneCount,
    required this.totalCount,
    required this.freedBytes,
    required this.currentName,
    this.fileProgress,
  });

  final int doneCount;
  final int totalCount;

  /// What the disk has actually gained so far.
  final int freedBytes;

  /// The file being worked on, for the line under the bar.
  final String currentName;

  /// How far into that one file, where the encoder reports it. `null` where it
  /// does not, and the bar for the file is then indeterminate rather than
  /// invented.
  final double? fileProgress;

  /// Overall progress across the run, counting the file in flight.
  double get fraction {
    if (totalCount <= 0) {
      return 0;
    }

    return ((doneCount + (fileProgress ?? 0)) / totalCount).clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props =>
      <Object?>[doneCount, totalCount, freedBytes, currentName, fileProgress];
}

/// The run is over, cancelled or not, and this is what it did.
final class OptimizeFinished extends OptimizeUpdate {
  const OptimizeFinished(this.report);

  final OptimizeReport report;
}
