import 'package:archonex_cleaner/project_files/features/language_selection/domain/language_storage.dart';
import 'package:archonex_cleaner/project_files/features/language_selection/domain/models/app_language.dart';

/// Hand-written fake for the language store. No mocking package here — see
/// `CLAUDE.md`.
///
/// It fakes the `domain/` interface rather than `PrefsLanguageStorage`, which is
/// what lets "a stored choice outranks the device" be tested with no platform
/// channel anywhere near it.
class FakeLanguageStorage implements LanguageStorage {
  FakeLanguageStorage({this.stored});

  /// What an earlier run left behind. `null` is a first launch.
  AppLanguage? stored;

  /// A store that will not answer. It reads back `null` and drops writes on the
  /// floor rather than throwing, because that is what the interface says a
  /// broken store does — see `LanguageStorage.read`.
  bool isBroken = false;

  final List<AppLanguage> written = <AppLanguage>[];

  @override
  Future<AppLanguage?> read() async => isBroken ? null : stored;

  @override
  Future<void> write(AppLanguage language) async {
    if (isBroken) {
      return;
    }

    written.add(language);
    stored = language;
  }
}
