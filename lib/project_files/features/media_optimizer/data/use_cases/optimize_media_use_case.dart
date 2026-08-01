import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/media_optimize_repo.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/encoder_support.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/media_candidate.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/media_kind.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/optimize_failure.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/optimize_job.dart';

/// Starts a run over the files the user agreed to.
///
/// Two guards rather than one, and the second is the interesting one. Being on
/// a platform that can rewrite files is not the same as having an encoder for
/// the kind in hand, so a list containing a video is refused on a machine with
/// no video encoder — with the kind in the failure, because "install ffmpeg"
/// and "this device has no HEVC encoder" are different instructions and the
/// screen has to choose between them.
///
/// An empty list is a `StateError` rather than a failure, as it is in
/// `CleanJunkUseCase`: the button that produced it is disabled, so getting here
/// is a programmer error and not something to give the user a sentence about.
class OptimizeMediaUseCase {
  const OptimizeMediaUseCase({
    required MediaOptimizeRepo repo,
    required EncoderSupport Function() support,
  })  : _repo = repo,
        _support = support;

  final MediaOptimizeRepo _repo;

  /// Read at call time rather than injected as a value, because it is answered
  /// asynchronously when the screen opens and the bloc holds the result.
  final EncoderSupport Function() _support;

  OptimizeJob call({required List<MediaCandidate> candidates}) {
    if (!_repo.isSupported) {
      throw const OptimizeUnsupportedFailure();
    }

    if (candidates.isEmpty) {
      throw StateError('Nothing to optimise. The button should have been off.');
    }

    final EncoderSupport support = _support();

    for (final MediaKind kind in MediaKind.values) {
      final bool wanted = candidates.any((candidate) => candidate.kind == kind);

      if (wanted && !support.supports(kind)) {
        throw NoEncoderFailure(kind);
      }
    }

    return _repo.optimize(candidates: candidates);
  }
}
