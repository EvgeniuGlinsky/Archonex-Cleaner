import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_candidate.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_kind.dart';

/// Everything a running scan can say while it runs.
///
/// Sealed so the bloc's switch is exhaustive: an update added without a state
/// change to match does not compile.
sealed class MediaScanUpdate {
  const MediaScanUpdate();
}

/// Which folder the walk has reached, for the line under the progress bar.
final class MediaLocationChanged extends MediaScanUpdate {
  const MediaLocationChanged({required this.label});

  final String label;
}

/// A batch of findings, already probed and already judged.
///
/// A batch and not one file, because a rebuild per file is a frozen screen and
/// a camera roll holds thousands — see `AppOptimizerPolicy.foundBatchSize`.
final class MediaFound extends MediaScanUpdate {
  const MediaFound(this.candidates);

  final List<MediaCandidate> candidates;
}

/// The walk stopped at `AppOptimizerPolicy.maxItemsPerRoot` with more still
/// there. Said out loud rather than implying the folder is accounted for.
final class MediaScanTruncated extends MediaScanUpdate {
  const MediaScanTruncated({required this.kind});

  final MediaKind kind;
}
