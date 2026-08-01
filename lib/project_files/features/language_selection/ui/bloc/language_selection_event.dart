part of 'language_selection_bloc.dart';

sealed class LanguageSelectionEvent extends Equatable {
  const LanguageSelectionEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Loads the available languages and the currently stored one.
final class LanguageSelectionStarted extends LanguageSelectionEvent {
  const LanguageSelectionStarted();
}

/// The user tapped a language tile. Takes effect immediately.
final class LanguageChanged extends LanguageSelectionEvent {
  const LanguageChanged(this.language);

  final AppLanguage language;

  @override
  List<Object?> get props => <Object?>[language];
}
