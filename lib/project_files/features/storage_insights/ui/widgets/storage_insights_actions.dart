import 'package:flutter/material.dart';

import 'package:storage_cleaner/core/constants/app_spacing.dart';
import 'package:storage_cleaner/core/widgets/app_primary_button.dart';
import 'package:storage_cleaner/core/widgets/app_progress_indicator.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/ui/bloc/storage_insights_bloc.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/ui/widgets/storage_insights_callbacks.dart';

/// The bottom slot: one button, and what it is doing right now.
///
/// Two states rather than the cleaner's four, because there is only one thing
/// this screen can be asked to do. The progress bar is indeterminate throughout
/// — a walk cannot know how many files are ahead of it without walking them
/// first, and a bar that invented a denominator would be worse than one that
/// admits it does not have one.
class StorageInsightsActions extends StatelessWidget {
  const StorageInsightsActions({
    required this.state,
    required this.callbacks,
    super.key,
  });

  final StorageInsightsState state;
  final StorageInsightsCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    if (state.isMeasuring) {
      return Column(
        children: <Widget>[
          AppProgressIndicator(
            label: state.location ?? l10n.insightsMeasuringLabel,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: callbacks.onMeasureCancelled,
            child: Text(l10n.cancelLabel),
          ),
        ],
      );
    }

    return AppPrimaryButton(
      label: state.hasMeasured
          ? l10n.insightsRemeasureLabel
          : l10n.insightsMeasureLabel,
      onPressed: state.canMeasure ? callbacks.onMeasurePressed : null,
    );
  }
}
