import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:archonex_cleaner/project_files/features/language_selection/data/use_cases/get_available_languages_use_case.dart';
import 'package:archonex_cleaner/project_files/features/language_selection/data/use_cases/get_selected_language_use_case.dart';
import 'package:archonex_cleaner/project_files/features/language_selection/data/use_cases/select_language_use_case.dart';
import 'package:archonex_cleaner/project_files/features/language_selection/domain/models/app_language.dart';

part 'language_selection_event.dart';
part 'language_selection_state.dart';

/// Applies the language the moment it is tapped.
///
/// It used to hold the pick until a continue button confirmed it, which is the
/// right shape for a screen the user is passing through and the wrong one for
/// the dialog this now lives in: the whole app behind the dialog is already
/// redrawn in the new language, so a button asking whether they meant it is a
/// button for a decision they can already see the result of. Backing out is
/// tapping the language back.
class LanguageSelectionBloc
    extends Bloc<LanguageSelectionEvent, LanguageSelectionState> {
  LanguageSelectionBloc({
    required GetAvailableLanguagesUseCase getAvailableLanguages,
    required GetSelectedLanguageUseCase getSelectedLanguage,
    required SelectLanguageUseCase selectLanguage,
  })  : _getAvailableLanguages = getAvailableLanguages,
        _getSelectedLanguage = getSelectedLanguage,
        _selectLanguage = selectLanguage,
        super(const LanguageSelectionState()) {
    on<LanguageSelectionStarted>(_onStarted, transformer: restartable());
    on<LanguageChanged>(_onLanguageChanged, transformer: sequential());
  }

  final GetAvailableLanguagesUseCase _getAvailableLanguages;
  final GetSelectedLanguageUseCase _getSelectedLanguage;
  final SelectLanguageUseCase _selectLanguage;

  void _onStarted(
    LanguageSelectionStarted event,
    Emitter<LanguageSelectionState> emit,
  ) {
    emit(
      state.copyWith(
        languages: _getAvailableLanguages(),
        selectedLanguage: _getSelectedLanguage(),
      ),
    );
  }

  void _onLanguageChanged(
    LanguageChanged event,
    Emitter<LanguageSelectionState> emit,
  ) {
    _selectLanguage(event.language);
    emit(state.copyWith(selectedLanguage: event.language));
  }
}
