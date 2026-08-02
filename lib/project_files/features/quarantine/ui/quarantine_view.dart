import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:storage_cleaner/core/constants/app_quarantine_policy.dart';
import 'package:storage_cleaner/core/widgets/app_primary_button.dart';
import 'package:storage_cleaner/core/widgets/app_screen_header.dart';
import 'package:storage_cleaner/core/widgets/app_screen_layout.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/language_selection/ui/widgets/language_button.dart';
import 'package:storage_cleaner/project_files/features/quarantine/domain/models/quarantine_failure.dart';
import 'package:storage_cleaner/project_files/features/quarantine/ui/bloc/quarantine_bloc.dart';
import 'package:storage_cleaner/project_files/features/quarantine/ui/mappers/quarantine_failure_ui.dart';
import 'package:storage_cleaner/project_files/features/quarantine/ui/widgets/quarantine_body.dart';
import 'package:storage_cleaner/project_files/features/quarantine/ui/widgets/quarantine_callbacks.dart';

/// The quarantine screen. Listeners, builders and callbacks.
class QuarantineView extends StatelessWidget {
  const QuarantineView({required this.now, super.key});

  /// The clock the expiry countdown is read against. Injected for the same
  /// reason the repository's is — a "one day left" row is otherwise only
  /// testable by waiting six days.
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Scaffold(
      // Back arrow and language button, as on the two tool screens — the
      // cleaner's view carries the reason the button is up here.
      appBar: AppBar(actions: const <Widget>[LanguageButton()]),
      body: MultiBlocListener(
        listeners: <BlocListener<QuarantineBloc, QuarantineState>>[
          BlocListener<QuarantineBloc, QuarantineState>(
            listenWhen: (previous, current) =>
                previous.failure != current.failure && current.failure != null,
            listener: _showFailure,
          ),
          BlocListener<QuarantineBloc, QuarantineState>(
            listenWhen: (previous, current) =>
                previous.status != current.status &&
                current.status == QuarantineStatus.restored,
            listener: _showRestored,
          ),
        ],
        child: BlocBuilder<QuarantineBloc, QuarantineState>(
          builder: (context, state) => AppScreenLayout(
            header: AppScreenHeader(
              title: l10n.quarantineTitle,
              subtitle: l10n.quarantineSubtitle(
                AppQuarantinePolicy.retention.inDays,
              ),
            ),
            body: QuarantineBody(
              state: state,
              callbacks: _callbacks(context),
              now: now(),
            ),
            bottom: state.isEmpty
                ? null
                : AppPrimaryButton(
                    label: l10n.quarantinePurgeAllLabel,
                    isDestructive: true,
                    onPressed: state.canPurgeAll
                        ? () => _confirmPurgeAll(context)
                        : null,
                  ),
          ),
        ),
      ),
    );
  }

  static void _showFailure(BuildContext context, QuarantineState state) {
    final QuarantineFailure? failure = state.failure;

    if (failure == null) {
      return;
    }

    _notify(context, failure.message(context));
    context.read<QuarantineBloc>().add(const QuarantineNoticeDismissed());
  }

  static void _showRestored(BuildContext context, QuarantineState state) {
    _notify(context, AppLocalizations.of(context)!.quarantineRestoredNotice);
    context.read<QuarantineBloc>().add(const QuarantineNoticeDismissed());
  }

  static void _notify(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  QuarantineCallbacks _callbacks(BuildContext context) {
    return QuarantineCallbacks(
      onRestorePressed: (id) => _add(context, BatchRestoreRequested(id)),
      onPurgePressed: (id) => _add(context, BatchPurgeRequested(id)),
      onPurgeAllPressed: () => _add(context, const PurgeAllRequested()),
    );
  }

  /// Emptying the quarantine is the one action in the app that destroys an undo
  /// rather than a file, so it asks — the per-batch delete does not, because a
  /// single batch can still be seen on the screen behind the dialog.
  Future<void> _confirmPurgeAll(BuildContext context) async {
    final QuarantineBloc bloc = context.read<QuarantineBloc>();
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.confirmPurgeAllTitle),
        content: Text(l10n.confirmPurgeAllBody),
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
      bloc.add(const PurgeAllRequested());
    }
  }

  static void _add(BuildContext context, QuarantineEvent event) =>
      context.read<QuarantineBloc>().add(event);
}
