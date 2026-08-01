import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:archonex_cleaner/core/constants/app_quarantine_policy.dart';
import 'package:archonex_cleaner/core/router/app_route.dart';
import 'package:archonex_cleaner/core/utils/file_size_formatter.dart';
import 'package:archonex_cleaner/core/widgets/app_screen_header.dart';
import 'package:archonex_cleaner/core/widgets/app_screen_layout.dart';
import 'package:archonex_cleaner/l10n/app_localizations.dart';
import 'package:archonex_cleaner/project_files/features/language_selection/ui/language_dialog.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/clean_failure.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/ui/bloc/storage_cleaner_bloc.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/ui/mappers/clean_failure_ui.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/ui/widgets/storage_cleaner_actions.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/ui/widgets/storage_cleaner_body.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/ui/widgets/storage_cleaner_callbacks.dart';

/// The cleaner screen. Listeners, builders and callbacks — no layout maths.
class StorageCleanerView extends StatelessWidget {
  const StorageCleanerView({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Scaffold(
      // An empty bar, purely for the back arrow: this screen is pushed from the
      // home screen now, and the other tool is behind it. The title stays in
      // `AppScreenHeader` below, where it can carry a subtitle — the quarantine
      // screen is built the same way.
      appBar: AppBar(),
      body: BlocListener<StorageCleanerBloc, StorageCleanerState>(
        listenWhen: (previous, current) =>
            previous.failure != current.failure && current.failure != null,
        listener: _showFailure,
        child: BlocBuilder<StorageCleanerBloc, StorageCleanerState>(
          builder: (context, state) {
            // Built once and handed to both slots: two bundles per rebuild would
            // be two sets of closures over the same context for no reason.
            final StorageCleanerCallbacks callbacks = _callbacks(context);

            return AppScreenLayout(
              header: AppScreenHeader(
                title: l10n.cleanerTitle,
                subtitle: l10n.cleanerSubtitle,
                trailing: IconButton(
                  tooltip: l10n.languageButtonTooltip,
                  icon: const Icon(Icons.language),
                  onPressed: () => showLanguageDialog(context),
                ),
              ),
              body: StorageCleanerBody(state: state, callbacks: callbacks),
              bottom: StorageCleanerActions(
                state: state,
                callbacks: callbacks,
              ),
            );
          },
        ),
      ),
    );
  }

  static void _showFailure(BuildContext context, StorageCleanerState state) {
    final CleanFailure? failure = state.failure;

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
            onPressed: () => _add(context, const FailureDismissed()),
          ),
        ),
      );
  }

  StorageCleanerCallbacks _callbacks(BuildContext context) {
    return StorageCleanerCallbacks(
      onScanPressed: () => _add(context, const ScanRequested()),
      onScanCancelled: () => _add(context, const ScanCancelled()),
      onCleanPressed: () => _confirmClean(context),
      onCleanCancelled: () => _add(context, const CleanCancelled()),
      onCategoryToggled: (category) => _add(context, CategoryToggled(category)),
      onItemToggled: (item) => _add(
        context,
        ItemToggled(category: item.category, path: item.path),
      ),
      onGrantAccessPressed: () => _add(context, const AccessRequested()),
      onAddFolderPressed: () => _add(context, const ScanFolderRequested()),
      onFailureDismissed: () => _add(context, const FailureDismissed()),
      onResultDismissed: () => _add(context, const ResultDismissed()),
      onQuarantinePressed: () =>
          context.pushNamed(AppRoute.quarantine.routeName),
    );
  }

  /// The one confirmation in the app, and the only place the retention and the
  /// permanent count are said out loud before anything happens.
  Future<void> _confirmClean(BuildContext context) async {
    final StorageCleanerBloc bloc = context.read<StorageCleanerBloc>();
    final StorageCleanerState state = bloc.state;
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n.confirmCleanTitle(
            FileSizeFormatter.format(state.selectedBytes),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.confirmCleanBody(AppQuarantinePolicy.retention.inDays)),
            if (state.permanentSelectedCount > 0)
              Text(
                l10n.confirmCleanPermanentNote(state.permanentSelectedCount),
              ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.deleteLabel),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      bloc.add(const CleanRequested());
    }
  }

  static void _add(BuildContext context, StorageCleanerEvent event) =>
      context.read<StorageCleanerBloc>().add(event);
}
