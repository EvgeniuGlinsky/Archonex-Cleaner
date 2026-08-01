import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'package:storage_cleaner/project_files/features/language_selection/domain/language_repo.dart';
import 'package:storage_cleaner/project_files/features/language_selection/domain/language_storage.dart';
import 'package:storage_cleaner/project_files/features/language_selection/domain/models/app_language.dart';

/// Answers the language question in the order the user would expect it asked.
///
/// The device already knows what language its owner reads, so the app never
/// asks: the first frame is drawn in the first system locale that matches an
/// `AppLanguage`, and English only where none does. A choice made by hand
/// afterwards outranks that permanently — `restore` puts it back on the next
/// launch, which is why the two are separate steps rather than one constructor
/// that guesses.
///
/// The locale reader is injected for the reason the clock is in
/// `IoQuarantineRepo`: "a Russian device opens in Russian" is otherwise only
/// testable by changing the machine's language.
class LanguageRepoImpl implements LanguageRepo {
  factory LanguageRepoImpl(
    LanguageStorage storage, {
    List<Locale> Function()? deviceLocales,
  }) =>
      LanguageRepoImpl._(storage, deviceLocales ?? _systemLocales);

  /// The device's answer is in place before the first frame, not after the
  /// storage read comes back: the splash screen carries the tagline, and a
  /// second of English on a Russian phone is the flash this whole change exists
  /// to remove.
  LanguageRepoImpl._(this._storage, List<Locale> Function() deviceLocales)
      : _deviceLocales = deviceLocales,
        _selectedLanguage =
            ValueNotifier<AppLanguage>(_matchDevice(deviceLocales()));

  final LanguageStorage _storage;
  final List<Locale> Function() _deviceLocales;
  final ValueNotifier<AppLanguage> _selectedLanguage;

  @override
  List<AppLanguage> getAvailableLanguages() => AppLanguage.values;

  @override
  AppLanguage getSelectedLanguage() => _selectedLanguage.value;

  /// The screen switches now and the store catches up. Deliberately not awaited
  /// and deliberately swallowing: the app is already redrawn in the new
  /// language, so a store that will not take the write costs the user their
  /// choice on the *next* launch rather than this tap.
  @override
  void selectLanguage(AppLanguage language) {
    _selectedLanguage.value = language;
    unawaited(_storage.write(language).catchError((_) {}));
  }

  /// Nothing stored means nobody has chosen, so the device's answer stands —
  /// including on the launch after a store that failed to write.
  @override
  Future<void> restore() async {
    final AppLanguage? stored = await _storage.read();

    if (stored != null) {
      _selectedLanguage.value = stored;

      return;
    }

    _selectedLanguage.value = _matchDevice(_deviceLocales());
  }

  @override
  ValueListenable<AppLanguage> get selectedLanguageListenable =>
      _selectedLanguage;

  static List<Locale> _systemLocales() => PlatformDispatcher.instance.locales;

  /// The system hands over a *list*, in the order the user ranked it. A device
  /// set to Ukrainian first and Russian second gets Russian rather than English,
  /// because the second preference is still a language they read and English may
  /// not be on the list at all.
  static AppLanguage _matchDevice(List<Locale> locales) {
    for (final Locale locale in locales) {
      for (final AppLanguage language in AppLanguage.values) {
        if (language.code == locale.languageCode) {
          return language;
        }
      }
    }

    return AppLanguage.english;
  }
}
