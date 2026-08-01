import 'package:flutter/widgets.dart';

import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/models/access_failure.dart';
import 'package:storage_cleaner/project_files/features/storage_access/ui/mappers/access_failure_ui.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/clean_failure.dart';

/// The one place a `CleanFailure` becomes a sentence.
///
/// The switch is exhaustive over a sealed hierarchy, so a failure added without
/// copy does not compile. That is the mechanism working, not an obstacle.
///
/// The access branch delegates rather than answering: those sentences belong to
/// `storage_access/`, which the optimiser reads too.
extension CleanFailureUi on CleanFailure {
  String message(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return switch (this) {
      AccessRefusedFailure(:final AccessFailure cause) => cause.message(context),
      ScanCancelledFailure() => l10n.failureScanCancelled,
      CleanUnsupportedFailure() => l10n.failureUnsupported,
      ScanFailure() => l10n.failureScan,
    };
  }
}
