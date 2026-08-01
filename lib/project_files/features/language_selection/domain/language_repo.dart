import 'package:flutter/foundation.dart';

import 'package:storage_cleaner/project_files/features/language_selection/domain/models/app_language.dart';

/// Contract for reading and storing the app language.
abstract interface class LanguageRepo {
  List<AppLanguage> getAvailableLanguages();

  AppLanguage getSelectedLanguage();

  void selectLanguage(AppLanguage language);

  /// Puts back the language chosen by hand on an earlier run, if there was one.
  ///
  /// Awaited on the splash rather than run from the constructor, so the first
  /// screen after it is already drawn in the right language instead of
  /// repainting into it a frame later.
  Future<void> restore();

  /// Notifies listeners whenever [selectLanguage] changes the selection, so
  /// the app root can rebuild with the new `Locale` without the bloc having to
  /// know that a locale exists at all.
  ValueListenable<AppLanguage> get selectedLanguageListenable;
}
