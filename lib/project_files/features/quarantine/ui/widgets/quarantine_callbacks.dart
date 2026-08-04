import 'package:flutter/foundation.dart';

/// Everything the quarantine screen can be asked to do.
///
/// Emptying the whole thing is not here. That button lives on the view, behind a
/// confirmation, and a second way to reach the same event — one that no dialog
/// stands in front of — is the kind of shortcut that gets taken by accident
/// later.
@immutable
class QuarantineCallbacks {
  const QuarantineCallbacks({
    required this.onRestorePressed,
    required this.onPurgePressed,
  });

  final ValueChanged<String> onRestorePressed;
  final ValueChanged<String> onPurgePressed;
}
