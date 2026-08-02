import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/storage_slice.dart';

/// What a measurement says while it is running.
///
/// The same two-event shape as `MediaScanUpdate`, and deliberately so: a label
/// for the line under the bar, and batches of totals. There is no "finished"
/// event because the stream closing is the finish — a job that both emitted a
/// result and closed would give the bloc two places to decide it was done.
sealed class InsightsUpdate {
  const InsightsUpdate();
}

/// The walk moved into a folder worth naming.
final class InsightsLocationChanged extends InsightsUpdate {
  const InsightsLocationChanged(this.label);

  final String label;
}

/// A batch of files, already summed.
///
/// Totals rather than the files themselves, which is the whole difference
/// between this walk and the optimiser's. Nothing here is ever shown as a row
/// or acted on individually, so keeping a hundred thousand paths in memory to
/// add up their sizes at the end would be a list nobody reads. The batch is
/// what `AppInsightsPolicy.measuredBatchSize` bounds; one event per file is one
/// bloc rebuild per file.
final class InsightsMeasured extends InsightsUpdate {
  const InsightsMeasured(this.slices);

  /// A delta, not a running total. The bloc accumulates.
  final List<StorageSlice> slices;
}

/// The walk stopped at its ceiling with more still on the disk.
final class InsightsTruncated extends InsightsUpdate {
  const InsightsTruncated();
}
