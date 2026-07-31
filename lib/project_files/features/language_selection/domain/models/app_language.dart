/// Languages the app can run in.
///
/// One entry per ARB file in `lib/l10n/`. Adding a language is an entry here
/// and a file there; nothing else in the app knows how many there are.
enum AppLanguage {
  english(code: 'en', label: 'English', nativeLabel: 'English'),
  russian(code: 'ru', label: 'Russian', nativeLabel: 'Русский'),
  chinese(code: 'zh', label: 'Chinese', nativeLabel: '中文');

  const AppLanguage({
    required this.code,
    required this.label,
    required this.nativeLabel,
  });

  /// ISO 639-1 code, handed straight to the localization delegate.
  final String code;

  /// Name in English.
  final String label;

  /// Name as written by native speakers. Deliberately not translated: a user
  /// looking for their own language is looking for their own word for it.
  final String nativeLabel;
}
