import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:storage_cleaner/core/utils/file_size_formatter.dart';
import 'package:storage_cleaner/core/widgets/app_screen_header.dart';
import 'package:storage_cleaner/core/widgets/app_screen_layout.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/language_selection/ui/widgets/language_button.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_failure.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/ui/bloc/media_optimizer_bloc.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/ui/mappers/optimize_failure_ui.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/ui/widgets/media_optimizer_actions.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/ui/widgets/media_optimizer_body.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/ui/widgets/media_optimizer_callbacks.dart';

/// The optimiser screen. Listeners, builders and callbacks — no layout maths.
class MediaOptimizerView extends StatelessWidget {
  const MediaOptimizerView({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Scaffold(
      // The back arrow and the language button, and nothing else — the cleaner
      // screen carries the full reason. The title stays in `AppScreenHeader`,
      // where it can carry a subtitle and where it scrolls away with the list.
      appBar: AppBar(actions: const <Widget>[LanguageButton()]),
      body: BlocListener<MediaOptimizerBloc, MediaOptimizerState>(
        listenWhen: (previous, current) =>
            previous.failure != current.failure && current.failure != null,
        listener: _showFailure,
        child: BlocBuilder<MediaOptimizerBloc, MediaOptimizerState>(
          builder: (context, state) {
            // Built once and handed to both slots: two bundles per rebuild
            // would be two sets of closures over the same context for nothing.
            final MediaOptimizerCallbacks callbacks = _callbacks(context);

            return AppScreenLayout(
              header: AppScreenHeader(
                title: l10n.optimizerTitle,
                subtitle: l10n.optimizerSubtitle,
              ),
              body: MediaOptimizerBody(state: state, callbacks: callbacks),
              bottom: MediaOptimizerActions(state: state, callbacks: callbacks),
            );
          },
        ),
      ),
    );
  }

  static void _showFailure(BuildContext context, MediaOptimizerState state) {
    final OptimizeFailure? failure = state.failure;

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
            onPressed: () => _add(context, const OptimizerFailureDismissed()),
          ),
        ),
      );
  }

  MediaOptimizerCallbacks _callbacks(BuildContext context) {
    return MediaOptimizerCallbacks(
      onScanPressed: () => _add(context, const MediaScanRequested()),
      onScanCancelled: () => _add(context, const MediaScanCancelled()),
      onOptimizePressed: () => _confirmOptimize(context),
      onOptimizeCancelled: () => _add(context, const OptimizeCancelled()),
      onGroupToggled: (kind) => _add(context, MediaGroupToggled(kind)),
      onCandidateToggled: (candidate) => _add(
        context,
        MediaCandidateToggled(kind: candidate.kind, path: candidate.path),
      ),
      onGrantAccessPressed: () =>
          _add(context, const OptimizerAccessRequested()),
      onAddFolderPressed: () => _add(context, const OptimizerFolderRequested()),
      onOpenSettingsPressed: () =>
          _add(context, const OptimizerAccessSettingsRequested()),
      onResultDismissed: () => _add(context, const OptimizerResultDismissed()),
    );
  }

  /// The confirmation, and it says the irreversible part out loud.
  ///
  /// The cleaner's equivalent can promise an undo, because a cleanup moves
  /// files into a quarantine for a week. This one cannot: keeping the originals
  /// would mean the disk holding both copies, which frees nothing, and freeing
  /// space is the entire point of the button. So the dialog names it — the
  /// originals are replaced and there is no way back — along with how many
  /// files will end up under a different name, which is the other thing a user
  /// only finds out afterwards if nobody tells them.
  Future<void> _confirmOptimize(BuildContext context) async {
    final MediaOptimizerBloc bloc = context.read<MediaOptimizerBloc>();
    final MediaOptimizerState state = bloc.state;
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n.confirmOptimizeTitle(
            FileSizeFormatter.format(state.estimatedSaving),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.confirmOptimizeBody(state.selectedCount)),
            if (state.renamedSelectedCount > 0)
              Text(l10n.confirmOptimizeRenameNote(state.renamedSelectedCount)),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.optimizeConfirmLabel),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      bloc.add(const OptimizeRequested());
    }
  }

  static void _add(BuildContext context, MediaOptimizerEvent event) =>
      context.read<MediaOptimizerBloc>().add(event);
}
