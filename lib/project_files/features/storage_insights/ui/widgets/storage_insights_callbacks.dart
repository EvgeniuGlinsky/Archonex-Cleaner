import 'package:flutter/foundation.dart';

/// Everything the measurement screen can be asked to do.
///
/// Three, which is the whole point of the screen: it reads and reports, and the
/// two things a user might do about the answer are the tools that already
/// exist.
@immutable
class StorageInsightsCallbacks {
  const StorageInsightsCallbacks({
    required this.onMeasurePressed,
    required this.onMeasureCancelled,
    required this.onGrantAccessPressed,
    required this.onAddFolderPressed,
    required this.onOpenSettingsPressed,
  });

  final VoidCallback onMeasurePressed;
  final VoidCallback onMeasureCancelled;
  final VoidCallback onGrantAccessPressed;
  final VoidCallback onAddFolderPressed;
  final VoidCallback onOpenSettingsPressed;
}
