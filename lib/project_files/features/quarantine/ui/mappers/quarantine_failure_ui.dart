import 'package:flutter/widgets.dart';

import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/quarantine/domain/models/quarantine_failure.dart';

/// The one place a `QuarantineFailure` becomes a sentence.
///
/// Exhaustive over a sealed hierarchy, like `CleanFailureUi`: a failure added
/// without copy does not compile.
extension QuarantineFailureUi on QuarantineFailure {
  String message(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return switch (this) {
      RestoreTargetOccupiedFailure(:final String path) =>
        l10n.failureRestoreTargetOccupied(path),
      PartialRestoreFailure(
        :final int restoredCount,
        :final int lostCount,
      ) =>
        l10n.failureRestore(restoredCount, lostCount),
      PurgeFailure() => l10n.failurePurge,
    };
  }
}
