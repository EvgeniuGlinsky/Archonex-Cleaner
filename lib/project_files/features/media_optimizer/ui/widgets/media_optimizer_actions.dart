import 'package:flutter/material.dart';

import 'package:archonex_cleaner/core/constants/app_spacing.dart';
import 'package:archonex_cleaner/core/utils/file_size_formatter.dart';
import 'package:archonex_cleaner/core/widgets/app_primary_button.dart';
import 'package:archonex_cleaner/l10n/app_localizations.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/ui/bloc/media_optimizer_bloc.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/ui/widgets/media_optimizer_callbacks.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/ui/widgets/clean_progress_indicator.dart';

/// The bottom slot: one button, and what it is doing right now.
///
/// Four states rather than four widgets, matching `StorageCleanerActions`: the
/// slot is one decision — which single thing the user can do next — and
/// splitting it would be four files agreeing about a fifth condition.
///
/// The running state shows the file name and a bar that fills inside it, which
/// the cleaner's does not need. Deleting is over in seconds; a transcode is
/// minutes per file, and a bar that only steps once a file has finished is
/// indistinguishable from a hang.
class MediaOptimizerActions extends StatelessWidget {
  const MediaOptimizerActions({
    required this.state,
    required this.callbacks,
    super.key,
  });

  final MediaOptimizerState state;
  final MediaOptimizerCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    if (state.isScanning) {
      return _Running(
        label: state.scanningLocation == null
            ? l10n.scanningLabel
            : l10n.scanningLocation(state.scanningLocation!),
        cancelLabel: l10n.cancelLabel,
        onCancelPressed: callbacks.onScanCancelled,
      );
    }

    if (state.isOptimizing) {
      return _Running(
        label: state.progress == null
            ? l10n.optimizingLabel
            : l10n.optimizingFile(state.progress!.currentName),
        progress: state.runProgress,
        cancelLabel: l10n.cancelLabel,
        onCancelPressed: callbacks.onOptimizeCancelled,
      );
    }

    if (!state.hasWorthwhile) {
      return AppPrimaryButton(
        label: state.hasScanned ? l10n.rescanLabel : l10n.mediaScanLabel,
        onPressed: state.canScan ? callbacks.onScanPressed : null,
      );
    }

    return Column(
      children: <Widget>[
        AppPrimaryButton(
          label: state.selectedCount == 0
              ? l10n.nothingSelectedLabel
              : l10n.optimizeLabel(
                  FileSizeFormatter.format(state.estimatedSaving),
                ),
          onPressed: state.canOptimize ? callbacks.onOptimizePressed : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: state.canScan ? callbacks.onScanPressed : null,
          child: Text(l10n.rescanLabel),
        ),
      ],
    );
  }
}

class _Running extends StatelessWidget {
  const _Running({
    required this.label,
    required this.cancelLabel,
    required this.onCancelPressed,
    this.progress,
  });

  final String label;
  final String cancelLabel;
  final VoidCallback onCancelPressed;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        CleanProgressIndicator(label: label, progress: progress),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(onPressed: onCancelPressed, child: Text(cancelLabel)),
      ],
    );
  }
}
