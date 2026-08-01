import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/media_optimize_repo.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/encoder_support.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/media_candidate.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/optimize_failure.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/optimize_job.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/optimize_update.dart';

/// The sibling for a platform that cannot rewrite anything.
///
/// Paired with `UnsupportedMediaScanRepo`, and it errors rather than reporting
/// an empty run for the same reason: a run that did nothing and a platform that
/// cannot are different things to say.
class UnsupportedMediaOptimizeRepo implements MediaOptimizeRepo {
  const UnsupportedMediaOptimizeRepo();

  @override
  bool get isSupported => false;

  @override
  Future<EncoderSupport> support() async => const EncoderSupport.none();

  @override
  OptimizeJob optimize({required List<MediaCandidate> candidates}) =>
      const _RefusingOptimizeJob();
}

class _RefusingOptimizeJob implements OptimizeJob {
  const _RefusingOptimizeJob();

  @override
  Stream<OptimizeUpdate> get updates =>
      Stream<OptimizeUpdate>.error(const OptimizeUnsupportedFailure());

  @override
  Future<void> cancel() async {}
}
