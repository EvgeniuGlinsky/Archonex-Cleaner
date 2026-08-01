import 'package:flutter/material.dart';

import 'package:storage_cleaner/core/constants/app_spacing.dart';
import 'package:storage_cleaner/core/utils/file_size_formatter.dart';
import 'package:storage_cleaner/core/widgets/app_primary_button.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/ui/bloc/storage_cleaner_bloc.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/ui/widgets/clean_progress_indicator.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/ui/widgets/storage_cleaner_callbacks.dart';

/// The bottom slot: one button, and what it is doing right now.
///
/// Four states rather than four widgets, because the slot is one decision —
/// which single thing the user can do next — and splitting it would be four
/// files agreeing about a fifth condition.
class StorageCleanerActions extends StatelessWidget {
  const StorageCleanerActions({
    required this.state,
    required this.callbacks,
    super.key,
  });

  final StorageCleanerState state;
  final StorageCleanerCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    if (state.isScanning) {
      return _Running(
        label: state.scanningLocation == null
            ? l10n.scanningLabel
            : l10n.scanningLocation(state.scanningLocation!),
        onCancelPressed: callbacks.onScanCancelled,
        cancelLabel: l10n.cancelLabel,
      );
    }

    if (state.isCleaning) {
      return _Running(
        label: l10n.cleaningLabel,
        progress: state.progress,
        onCancelPressed: callbacks.onCleanCancelled,
        cancelLabel: l10n.cancelLabel,
      );
    }

    if (!state.hasFindings) {
      return AppPrimaryButton(
        label: state.hasScanned ? l10n.rescanLabel : l10n.scanLabel,
        onPressed: state.canScan ? callbacks.onScanPressed : null,
      );
    }

    return Column(
      children: <Widget>[
        AppPrimaryButton(
          label: state.selectedCount == 0
              ? l10n.nothingSelectedLabel
              : l10n.cleanLabel(
                  FileSizeFormatter.format(state.selectedBytes),
                ),
          isDestructive: true,
          onPressed: state.canClean ? callbacks.onCleanPressed : null,
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
        OutlinedButton(
          onPressed: onCancelPressed,
          child: Text(cancelLabel),
        ),
      ],
    );
  }
}
