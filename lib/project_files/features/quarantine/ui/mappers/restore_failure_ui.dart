import 'package:flutter/widgets.dart';

import 'package:archonex_cleaner/l10n/app_localizations.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/domain/models/restore_failure.dart';

/// The one place a `RestoreFailure` becomes a sentence.
///
/// Exhaustive over a sealed hierarchy, like `CleanFailureUi`: a failure added
/// without copy does not compile.
extension RestoreFailureUi on RestoreFailure {
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
    };
  }
}
