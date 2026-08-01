import 'package:flutter/foundation.dart';

import 'package:archonex_cleaner/project_files/features/home/domain/models/app_tool.dart';

/// Everything the home screen can be asked to do.
@immutable
class HomeCallbacks {
  const HomeCallbacks({
    required this.onToolPressed,
    required this.onLanguagePressed,
  });

  final ValueChanged<AppTool> onToolPressed;
  final VoidCallback onLanguagePressed;
}
