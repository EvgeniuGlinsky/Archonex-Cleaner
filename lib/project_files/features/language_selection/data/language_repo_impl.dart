import 'package:flutter/foundation.dart';

import 'package:archonex_cleaner/project_files/features/language_selection/domain/language_repo.dart';
import 'package:archonex_cleaner/project_files/features/language_selection/domain/models/app_language.dart';

/// In-memory implementation, as in the Converter.
///
/// The choice is lost on restart, which is the honest state of this feature
/// rather than an oversight: persisting it is a `SharedPreferencesAsync` behind
/// a `LanguageStorage` interface, and nothing above this layer changes when it
/// lands.
class LanguageRepoImpl implements LanguageRepo {
  final ValueNotifier<AppLanguage> _selectedLanguage =
      ValueNotifier<AppLanguage>(AppLanguage.english);

  @override
  List<AppLanguage> getAvailableLanguages() => AppLanguage.values;

  @override
  AppLanguage getSelectedLanguage() => _selectedLanguage.value;

  @override
  void selectLanguage(AppLanguage language) =>
      _selectedLanguage.value = language;

  @override
  ValueListenable<AppLanguage> get selectedLanguageListenable =>
      _selectedLanguage;
}
