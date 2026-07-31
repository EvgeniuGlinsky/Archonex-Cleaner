import 'package:flutter/widgets.dart';

import 'package:archonex_cleaner/l10n/app_localizations.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/clean_failure.dart';

/// The one place a `CleanFailure` becomes a sentence.
///
/// The switch is exhaustive over a sealed hierarchy, so a failure added without
/// copy does not compile. That is the mechanism working, not an obstacle.
extension CleanFailureUi on CleanFailure {
  String message(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return switch (this) {
      StorageAccessDeniedFailure(:final bool canAskAgain) => canAskAgain
          ? l10n.failureAccessDenied
          : l10n.accessDeniedPermanentBody,
      ScanCancelledFailure() => l10n.failureScanCancelled,
      CleanUnsupportedFailure() => l10n.failureUnsupported,
      ScanFailure() => l10n.failureScan,
    };
  }
}
