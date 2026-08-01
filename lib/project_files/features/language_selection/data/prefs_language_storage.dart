import 'package:shared_preferences/shared_preferences.dart';

import 'package:archonex_cleaner/project_files/features/language_selection/domain/language_storage.dart';
import 'package:archonex_cleaner/project_files/features/language_selection/domain/models/app_language.dart';

/// `shared_preferences` behind `LanguageStorage`.
///
/// The ISO code is stored rather than the enum index: an index is a number that
/// means whatever position the entry happens to sit at, so adding a language
/// above another one in `AppLanguage` would silently switch everybody who chose
/// the one below. A code that no longer matches any entry reads back as `null`,
/// which is the same answer as a first run and the same behaviour — follow the
/// device.
///
/// The preference store is built lazily behind an optional positional override:
/// the object is constructed while the app root is still building, and a test
/// needs a way in that does not involve a platform channel.
class PrefsLanguageStorage implements LanguageStorage {
  PrefsLanguageStorage([SharedPreferencesAsync? prefs]) : _prefs = prefs;

  static const String _key = 'language.code';

  SharedPreferencesAsync? _prefs;

  SharedPreferencesAsync get _store => _prefs ??= SharedPreferencesAsync();

  /// A store that will not answer costs the user the language they picked, not
  /// their launch: the app opens in the device's language instead of not at all.
  @override
  Future<AppLanguage?> read() async {
    final String? code;

    try {
      code = await _store.getString(_key);
    } catch (_) {
      return null;
    }

    if (code == null) {
      return null;
    }

    for (final AppLanguage language in AppLanguage.values) {
      if (language.code == code) {
        return language;
      }
    }

    return null;
  }

  @override
  Future<void> write(AppLanguage language) async {
    try {
      await _store.setString(_key, language.code);
    } catch (_) {
      return;
    }
  }
}
