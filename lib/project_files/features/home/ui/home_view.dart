import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:archonex_cleaner/core/router/app_route.dart';
import 'package:archonex_cleaner/core/widgets/app_screen_header.dart';
import 'package:archonex_cleaner/core/widgets/app_screen_layout.dart';
import 'package:archonex_cleaner/l10n/app_localizations.dart';
import 'package:archonex_cleaner/project_files/features/home/domain/models/app_tool.dart';
import 'package:archonex_cleaner/project_files/features/home/ui/bloc/home_bloc.dart';
import 'package:archonex_cleaner/project_files/features/home/ui/widgets/home_body.dart';
import 'package:archonex_cleaner/project_files/features/home/ui/widgets/home_callbacks.dart';
import 'package:archonex_cleaner/project_files/features/language_selection/ui/language_dialog.dart';

/// The screen the app opens on. Listeners, builders and callbacks.
///
/// No bottom slot: the tool cards *are* the actions, and a primary button under
/// them would be a third thing to press on a screen whose whole job is to offer
/// two.
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) => AppScreenLayout(
          header: AppScreenHeader(
            title: l10n.appName,
            subtitle: l10n.homeSubtitle,
            trailing: IconButton(
              tooltip: l10n.languageButtonTooltip,
              icon: const Icon(Icons.language),
              onPressed: () => showLanguageDialog(context),
            ),
          ),
          body: HomeBody(state: state, callbacks: _callbacks(context)),
        ),
      ),
    );
  }

  HomeCallbacks _callbacks(BuildContext context) {
    return HomeCallbacks(
      onToolPressed: (tool) => _openTool(context, tool),
      onLanguagePressed: () => showLanguageDialog(context),
    );
  }

  /// Pushed, not `go`ne to, so the back gesture lands on this screen and the
  /// other tool is one tap away — the same reason the cleaner pushes the
  /// quarantine.
  ///
  /// The read is repeated on the way back because the tool the user just used
  /// exists to move the very number this screen is showing.
  Future<void> _openTool(BuildContext context, AppTool tool) async {
    final HomeBloc bloc = context.read<HomeBloc>();

    await switch (tool) {
      AppTool.cleaner =>
        context.pushNamed<void>(AppRoute.storageCleaner.routeName),
      AppTool.optimizer =>
        context.pushNamed<void>(AppRoute.mediaOptimizer.routeName),
    };

    bloc.add(const HomeStarted());
  }
}
