import 'package:equatable/equatable.dart';

import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_container.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_quality.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_verdict.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/video_codec.dart';

/// What `SavingsEstimator` decided about one file: whether to touch it, and if
/// so what to turn it into.
///
/// Two constructors and no third. A plan either describes an encode in full —
/// container, codec, quality, expected size — or it describes a refusal and
/// carries the reason. There is no half-plan, which is what keeps the job from
/// having to ask whether a target is null before it starts an encode.
///
/// [estimatedBytes] is the *output* size and not the saving. The saving needs
/// the original size, which lives on `MediaCandidate` and is not duplicated
/// here: two records of one file's weight is how a screen ends up disagreeing
/// with itself.
final class OptimizationPlan extends Equatable {
  /// A file that will not be touched, and why.
  const OptimizationPlan.skip(this.verdict)
      : assert(
          verdict != OptimizeVerdict.worthIt,
          'A skip cannot be worth doing — use OptimizationPlan.reencode.',
        ),
        targetContainer = null,
        targetCodec = null,
        preset = null,
        estimatedBytes = null;

  /// A file that will be re-encoded, and into what.
  const OptimizationPlan.reencode({
    required MediaContainer this.targetContainer,
    required int this.estimatedBytes,
    required OptimizeQuality this.preset,
    this.targetCodec,
  }) : verdict = OptimizeVerdict.worthIt;

  final OptimizeVerdict verdict;

  /// Non-null exactly when [isWorthIt].
  final MediaContainer? targetContainer;

  /// Video only, and non-null whenever [targetContainer] names a video box.
  final VideoCodec? targetCodec;

  /// How hard the encoder was told to press. Non-null exactly when [isWorthIt].
  ///
  /// The whole preset rather than the one number each encoder needs, because
  /// there are three of those and they are not interchangeable: a JPEG quality,
  /// an x265 CRF and a bits-per-pixel-per-frame target. Carrying all three as
  /// separate fields would mean two of them being null on every plan and each
  /// encoder reaching past the other's. Carrying the choice instead lets each
  /// one take what it understands.
  final OptimizeQuality? preset;

  /// What the output is expected to weigh. An estimate, and named one
  /// everywhere it is shown.
  final int? estimatedBytes;

  bool get isWorthIt => verdict == OptimizeVerdict.worthIt;

  @override
  List<Object?> get props =>
      <Object?>[verdict, targetContainer, targetCodec, preset, estimatedBytes];
}
