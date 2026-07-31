import 'package:flutter/foundation.dart';

/// Everything the quarantine screen can be asked to do.
@immutable
class QuarantineCallbacks {
  const QuarantineCallbacks({
    required this.onRestorePressed,
    required this.onPurgePressed,
    required this.onPurgeAllPressed,
  });

  final ValueChanged<String> onRestorePressed;
  final ValueChanged<String> onPurgePressed;
  final VoidCallback onPurgeAllPressed;
}
