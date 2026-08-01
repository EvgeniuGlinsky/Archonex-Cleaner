import 'package:flutter/widgets.dart';

import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_kind.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_failure.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/models/access_failure.dart';
import 'package:storage_cleaner/project_files/features/storage_access/ui/mappers/access_failure_ui.dart';

/// The one place an `OptimizeFailure` becomes a sentence.
///
/// Exhaustive over a sealed hierarchy, so a failure added without copy does not
/// compile. The access branch delegates rather than answering, exactly as
/// `CleanFailureUi` does: those sentences belong to `storage_access/`, which
/// both tools read.
extension OptimizeFailureUi on OptimizeFailure {
  String message(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return switch (this) {
      OptimizeAccessRefusedFailure(:final AccessFailure cause) =>
        cause.message(context),
      MediaScanCancelledFailure() => l10n.failureMediaScanCancelled,
      OptimizeUnsupportedFailure() => l10n.failureOptimizeUnsupported,
      // Two different instructions behind one failure, which is why it carries
      // the kind: a desktop is told to install something and a phone is told
      // its chip cannot do it.
      NoEncoderFailure(:final MediaKind kind) => switch (kind) {
          MediaKind.video => l10n.failureNoVideoEncoder,
          MediaKind.photo => l10n.failureNoPhotoEncoder,
        },
      MediaScanFailure() => l10n.failureMediaScan,
      OptimizeRunFailure() => l10n.failureOptimizeRun,
    };
  }
}
