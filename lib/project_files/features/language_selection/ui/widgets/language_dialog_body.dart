import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:archonex_cleaner/core/constants/app_spacing.dart';
import 'package:archonex_cleaner/l10n/app_localizations.dart';
import 'package:archonex_cleaner/project_files/features/language_selection/domain/models/app_language.dart';
import 'package:archonex_cleaner/project_files/features/language_selection/ui/bloc/language_selection_bloc.dart';
import 'package:archonex_cleaner/project_files/features/language_selection/ui/widgets/language_list.dart';

/// The contents of the language dialog.
///
/// Sized rather than left to the dialog: three tiles in a `ListView` have no
/// intrinsic height, and an unbounded one inside an `AlertDialog` throws.
class LanguageDialogBody extends StatelessWidget {
  const LanguageDialogBody({super.key});

  static const double _width = 320;
  static const double _tileHeight = 72;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.languageDialogTitle),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      content: SizedBox(
        width: _width,
        height: _height(context),
        child: BlocBuilder<LanguageSelectionBloc, LanguageSelectionState>(
          builder: (context, state) => LanguageList(
            languages: state.languages,
            selectedLanguage: state.selectedLanguage,
            onLanguageSelected: (language) => context
                .read<LanguageSelectionBloc>()
                .add(LanguageChanged(language)),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.doneLabel),
        ),
      ],
    );
  }

  /// Tall enough for every language the app has, so the list never scrolls for
  /// three entries — and still bounded, so adding a tenth one would.
  double _height(BuildContext context) {
    const double perTile = _tileHeight + AppSpacing.md;
    final double wanted = AppLanguage.values.length * perTile;
    final double available = MediaQuery.sizeOf(context).height / 2;

    return wanted < available ? wanted : available;
  }
}
