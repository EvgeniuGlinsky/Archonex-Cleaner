import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:storage_cleaner/core/widgets/app_screen_header.dart';
import 'package:storage_cleaner/core/widgets/app_screen_layout.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/language_selection/ui/widgets/language_button.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/insights_failure.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/ui/bloc/storage_insights_bloc.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/ui/mappers/insights_failure_ui.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/ui/widgets/storage_insights_actions.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/ui/widgets/storage_insights_body.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/ui/widgets/storage_insights_callbacks.dart';

/// The measurement screen. Listeners, builders and callbacks — no layout maths.
///
/// Stateless, unlike the two tool screens: its bloc arrives with the route, so
/// there is nothing to tell about coming back.
class StorageInsightsView extends StatelessWidget {
  const StorageInsightsView({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(actions: const <Widget>[LanguageButton()]),
      body: BlocListener<StorageInsightsBloc, StorageInsightsState>(
        listenWhen: (previous, current) =>
            previous.failure != current.failure && current.failure != null,
        listener: _showFailure,
        child: BlocBuilder<StorageInsightsBloc, StorageInsightsState>(
          builder: (context, state) {
            final StorageInsightsCallbacks callbacks = _callbacks(context);

            return AppScreenLayout(
              header: AppScreenHeader(
                title: l10n.insightsTitle,
                subtitle: l10n.insightsSubtitle,
              ),
              body: StorageInsightsBody(state: state, callbacks: callbacks),
              bottom: StorageInsightsActions(
                state: state,
                callbacks: callbacks,
              ),
            );
          },
        ),
      ),
    );
  }

  static void _showFailure(BuildContext context, StorageInsightsState state) {
    final InsightsFailure? failure = state.failure;

    if (failure == null) {
      return;
    }

    final AppLocalizations l10n = AppLocalizations.of(context)!;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(failure.message(context)),
          action: SnackBarAction(
            label: l10n.dismissLabel,
            onPressed: () => _add(context, const InsightsFailureDismissed()),
          ),
        ),
      );
  }

  StorageInsightsCallbacks _callbacks(BuildContext context) {
    return StorageInsightsCallbacks(
      onMeasurePressed: () => _add(context, const InsightsMeasureRequested()),
      onMeasureCancelled: () =>
          _add(context, const InsightsMeasureCancelled()),
      onGrantAccessPressed: () => _add(context, const InsightsAccessRequested()),
      onAddFolderPressed: () => _add(context, const InsightsFolderRequested()),
      onOpenSettingsPressed: () =>
          _add(context, const InsightsAccessSettingsRequested()),
    );
  }

  static void _add(BuildContext context, StorageInsightsEvent event) =>
      context.read<StorageInsightsBloc>().add(event);
}
