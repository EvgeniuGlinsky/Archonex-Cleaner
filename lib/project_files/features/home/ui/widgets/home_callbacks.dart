import 'package:flutter/foundation.dart';

import 'package:storage_cleaner/project_files/features/home/domain/models/app_tool.dart';

/// Everything the home screen can be asked to do.
///
/// One thing, now. There was an `onLanguagePressed` beside it that nothing ever
/// called: the header built its own button and opened the dialog itself, and
/// the callback sat here being passed around for nobody. `LanguageButton` is
/// where that lives.
@immutable
class HomeCallbacks {
  const HomeCallbacks({required this.onToolPressed});

  final ValueChanged<AppTool> onToolPressed;
}
