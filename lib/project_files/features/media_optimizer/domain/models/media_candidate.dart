import 'package:equatable/equatable.dart';

import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/media_container.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/media_kind.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/media_probe.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/optimization_plan.dart';

/// One file the walk found, everything the header said about it, and what the
/// estimator decided to do with it.
///
/// [path] is the identity, as it is for `JunkItem`: two files with the same
/// name in different folders are two rows, and the same file found twice is
/// one.
///
/// A candidate exists for every media file over the size floor, including the
/// ones the estimator refused. The refusals are the point of showing the list
/// at all — "your largest video is 4 GB and here is why nothing can be done
/// about it" is the answer somebody with a full disk actually needs.
final class MediaCandidate extends Equatable {
  const MediaCandidate({
    required this.path,
    required this.name,
    required this.sizeInBytes,
    required this.modifiedAt,
    required this.probe,
    required this.plan,
  });

  final String path;
  final String name;
  final int sizeInBytes;
  final DateTime modifiedAt;

  /// What the header said. Present even for a refusal, because the screen shows
  /// the resolution and length of a file it is leaving alone.
  final MediaProbe probe;

  final OptimizationPlan plan;

  MediaKind get kind => probe.kind;

  bool get isWorthIt => plan.isWorthIt;

  /// What re-encoding this file is expected to free. Zero for a refusal.
  ///
  /// Floored at zero rather than allowed to go negative: an estimate larger
  /// than the original would be a bug in the table above it, and a negative
  /// saving added into a total silently makes the total wrong instead of
  /// obviously wrong.
  int get estimatedSaving {
    final int? estimated = plan.estimatedBytes;

    if (estimated == null || estimated >= sizeInBytes) {
      return 0;
    }

    return sizeInBytes - estimated;
  }

  /// Whether acting on this file would give it a different name on disk.
  ///
  /// True for a photographic PNG becoming a JPEG and for an AVI becoming an
  /// MP4. The confirmation dialog counts these separately, because a file that
  /// changes extension is a file every link and gallery reference to it stops
  /// finding.
  bool get changesExtension {
    final MediaContainer? target = plan.targetContainer;

    return target != null && target != probe.container;
  }

  @override
  List<Object?> get props =>
      <Object?>[path, name, sizeInBytes, modifiedAt, probe, plan];
}
