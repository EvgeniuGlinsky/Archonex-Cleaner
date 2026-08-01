import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:archonex_cleaner/project_files/features/language_selection/data/use_cases/get_available_languages_use_case.dart';
import 'package:archonex_cleaner/project_files/features/language_selection/data/use_cases/get_selected_language_use_case.dart';
import 'package:archonex_cleaner/project_files/features/language_selection/data/use_cases/select_language_use_case.dart';
import 'package:archonex_cleaner/project_files/features/language_selection/domain/language_repo.dart';
import 'package:archonex_cleaner/project_files/features/language_selection/ui/bloc/language_selection_bloc.dart';
import 'package:archonex_cleaner/project_files/features/language_selection/ui/widgets/language_dialog_body.dart';

/// Opens the language picker over whatever screen asked for it.
///
/// A dialog rather than the route this used to be. The app no longer asks the
/// question at startup — the device answers it — so what is left is a correction
/// somebody makes rarely and from anywhere, and sending them to a screen and
/// back for it loses the place they were in. It is also the one shape that reads
/// right on a phone and on a desktop window, which a bottom sheet does not.
///
/// This function does the wiring the deleted `language_selection_page.dart` did:
/// a dialog is its own route, so nothing else can put the bloc above it.
Future<void> showLanguageDialog(BuildContext context) {
  // Read before the await, not inside the builder: the dialog's context belongs
  // to a route that this one does not sit above.
  final LanguageRepo repo = context.read<LanguageRepo>();

  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider<LanguageSelectionBloc>(
      create: (_) => LanguageSelectionBloc(
        getAvailableLanguages: GetAvailableLanguagesUseCase(repo),
        getSelectedLanguage: GetSelectedLanguageUseCase(repo),
        selectLanguage: SelectLanguageUseCase(repo),
      )..add(const LanguageSelectionStarted()),
      child: const LanguageDialogBody(),
    ),
  );
}
