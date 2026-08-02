import 'package:storage_cleaner/project_files/features/media_optimizer/data/rules/savings_estimator.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_group.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_quality.dart';

/// Re-measures everything the walk found against a different preset.
///
/// Without it, changing the setting would mean walking the device again — a
/// couple of minutes and the header of every file in a camera roll — to answer
/// a question the app already has all the data for. `MediaCandidate` keeps its
/// `MediaProbe` precisely so this is possible: the estimator needs the header
/// and the size, and both are already in hand.
///
/// Exclusions survive untouched, and a path that stops being worth doing simply
/// falls out of `MediaGroup.worthwhile` with its exclusion sitting inert beside
/// it. That is deliberate: turning the preset up and back down again must leave
/// the user's own unticking exactly where they left it, and the Selection
/// section of the skill is why the record is an exclusion rather than a
/// selection in the first place.
class ReplanForQualityUseCase {
  const ReplanForQualityUseCase();

  List<MediaGroup> call({
    required List<MediaGroup> groups,
    required OptimizeQuality quality,
  }) {
    return groups
        .map(
          (group) => group.copyWith(
            candidates: group.candidates
                .map(
                  (candidate) => candidate.withPlan(
                    SavingsEstimator.plan(
                      probe: candidate.probe,
                      sizeInBytes: candidate.sizeInBytes,
                      quality: quality,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }
}
