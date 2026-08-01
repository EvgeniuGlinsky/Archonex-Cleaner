import 'package:storage_cleaner/project_files/features/language_selection/domain/models/app_language.dart';

/// Where the language the user picked by hand survives a restart.
///
/// Split from `LanguageRepo` rather than folded into it, because the repository
/// owns a rule — a stored choice outranks the device's own language — and the
/// storage owns none: it reads a string and writes a string. That is what lets
/// the rule be tested without a platform plugin answering.
abstract interface class LanguageStorage {
  /// `null` on a first run, and on a store that will not answer. Both mean the
  /// same thing to the caller: nobody has chosen yet, so follow the device.
  Future<AppLanguage?> read();

  Future<void> write(AppLanguage language);
}
