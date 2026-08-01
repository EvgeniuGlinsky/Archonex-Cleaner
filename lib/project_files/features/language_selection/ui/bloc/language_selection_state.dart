part of 'language_selection_bloc.dart';

final class LanguageSelectionState extends Equatable {
  const LanguageSelectionState({
    this.languages = const <AppLanguage>[],
    this.selectedLanguage = AppLanguage.english,
  });

  final List<AppLanguage> languages;
  final AppLanguage selectedLanguage;

  LanguageSelectionState copyWith({
    List<AppLanguage>? languages,
    AppLanguage? selectedLanguage,
  }) {
    return LanguageSelectionState(
      languages: languages ?? this.languages,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
    );
  }

  @override
  List<Object?> get props => <Object?>[languages, selectedLanguage];
}
