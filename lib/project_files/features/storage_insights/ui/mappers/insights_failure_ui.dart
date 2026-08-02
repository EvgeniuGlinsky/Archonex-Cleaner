import 'package:flutter/material.dart';

import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/insights_failure.dart';

/// The sentence for each failure, chosen here and nowhere in `domain/`.
///
/// The same arrangement as `CleanFailureUi` and `OptimizeFailureUi`: the sealed
/// class means the switch is exhaustive, so a new member is a compile error
/// here rather than a screen that says nothing.
extension InsightsFailureUi on InsightsFailure {
  String message(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return switch (this) {
      InsightsScanCancelledFailure() => l10n.failureInsightsCancelled,
      InsightsUnsupportedFailure() => l10n.failureInsightsUnsupported,
      InsightsScanFailure() => l10n.failureInsightsScan,
    };
  }
}
