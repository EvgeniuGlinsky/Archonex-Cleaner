import 'package:flutter/foundation.dart';

import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_kind.dart';

/// Everything the optimiser screen can be asked to do, in one bundle.
///
/// The same arrangement as `StorageCleanerCallbacks`, for the same reason: nine
/// separate parameters would make every widget signature a wall of arguments,
/// and the bundle keeps `flutter_bloc` and `go_router` out of `ui/widgets/`.
@immutable
class MediaOptimizerCallbacks {
  const MediaOptimizerCallbacks({
    required this.onScanPressed,
    required this.onScanCancelled,
    required this.onOptimizePressed,
    required this.onOptimizeCancelled,
    required this.onGroupToggled,
    required this.onCandidateToggled,
    required this.onGrantAccessPressed,
    required this.onAddFolderPressed,
    required this.onResultDismissed,
  });

  final VoidCallback onScanPressed;
  final VoidCallback onScanCancelled;
  final VoidCallback onOptimizePressed;
  final VoidCallback onOptimizeCancelled;
  final ValueChanged<MediaKind> onGroupToggled;
  final ValueChanged<ToggledCandidate> onCandidateToggled;
  final VoidCallback onGrantAccessPressed;
  final VoidCallback onAddFolderPressed;
  final VoidCallback onResultDismissed;
}

/// A row identified by the two things it takes to find it again.
///
/// A path alone would do — paths are unique — but the bloc would then have to
/// search every group to know which one to rebuild.
@immutable
class ToggledCandidate {
  const ToggledCandidate({required this.kind, required this.path});

  final MediaKind kind;
  final String path;
}
