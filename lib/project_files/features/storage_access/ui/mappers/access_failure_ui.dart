import 'package:flutter/widgets.dart';

import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/models/access_failure.dart';

/// The one place an `AccessFailure` becomes a sentence.
///
/// Beside `StorageAccessUi` rather than inside either tool's mappers, because
/// the cleaner and the optimiser hit the same refusals and would otherwise
/// translate them twice, in two files, out of step. `CleanFailureUi` delegates
/// here through `AccessRefusedFailure`.
extension AccessFailureUi on AccessFailure {
  String message(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return switch (this) {
      StorageAccessDeniedFailure(:final bool canAskAgain) => canAskAgain
          ? l10n.failureAccessDenied
          : l10n.accessDeniedPermanentBody,
    };
  }
}
