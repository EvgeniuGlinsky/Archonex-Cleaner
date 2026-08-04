import 'package:flutter/foundation.dart';

import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/junk_category.dart';

/// Everything the cleaner screen can be asked to do, in one bundle.
///
/// Ten separate parameters would make every widget signature a wall of
/// arguments; one bundle keeps the widgets receiving nothing but functions, and
/// keeps `flutter_bloc` and `go_router` out of `ui/widgets/` entirely.
@immutable
class StorageCleanerCallbacks {
  const StorageCleanerCallbacks({
    required this.onScanPressed,
    required this.onScanCancelled,
    required this.onCleanPressed,
    required this.onCleanCancelled,
    required this.onCategoryToggled,
    required this.onItemToggled,
    required this.onGrantAccessPressed,
    required this.onAddFolderPressed,
    required this.onOpenSettingsPressed,
    required this.onResultDismissed,
    required this.onQuarantinePressed,
  });

  final VoidCallback onScanPressed;
  final VoidCallback onScanCancelled;
  final VoidCallback onCleanPressed;
  final VoidCallback onCleanCancelled;
  final ValueChanged<JunkCategory> onCategoryToggled;
  final ValueChanged<ToggledItem> onItemToggled;
  final VoidCallback onGrantAccessPressed;
  final VoidCallback onAddFolderPressed;

  /// Offered in place of grant once the system has stopped showing the sheet.
  final VoidCallback onOpenSettingsPressed;

  /// Dismissing a *failure* is not here, though it was: the snack bar carrying
  /// one is raised by the view's own `BlocListener` and dismissed by the same
  /// hand, so nothing in `ui/widgets/` ever asked. The optimiser's bundle never
  /// had the field, and the two now match.
  final VoidCallback onResultDismissed;

  /// The one entry that is a navigation rather than an event.
  final VoidCallback onQuarantinePressed;
}

/// A row identified by the two things it takes to find it again.
///
/// A path alone would do — paths are unique — but the bloc would then have to
/// search every group to know which one to rebuild.
@immutable
class ToggledItem {
  const ToggledItem({required this.category, required this.path});

  final JunkCategory category;
  final String path;
}
