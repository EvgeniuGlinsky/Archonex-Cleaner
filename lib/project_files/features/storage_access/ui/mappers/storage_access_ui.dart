import 'package:flutter/widgets.dart';

import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';

/// What the screen says about the access it has.
///
/// The interesting case is `appOnly`, which means three different things: on
/// Android it is a refusal that can still be reversed from the sheet, or one the
/// system has stopped offering the sheet for, and on iOS it is the platform and
/// always will be. The model tells them apart with `canRequestMore` and
/// `isPermanentlyDenied`, and this is where that becomes three paragraphs.
///
/// The middle one is the one worth naming. Reading it off `canRequestMore`
/// alone put a permanently-refused Android on the iOS sentence — "no app can
/// read another one's files" — which is not true there and told the user the
/// thing they wanted was impossible when it was two taps away in Settings.
///
/// Whether a notice is drawn at all is `StorageAccess.isNarrowed`, on the model.
/// `full` has nothing to say, and `none` says it through the empty state
/// instead — a notice there would be a box with no action in it, saying what the
/// larger message behind it already says. Both levels still answer below,
/// because the empty state asks this mapper rather than reaching for the ARB
/// keys itself.
extension StorageAccessUi on StorageAccess {
  String title(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return switch (level) {
      StorageAccessLevel.scopedFolders =>
        l10n.accessScopedTitle(grantedRoots.length),
      StorageAccessLevel.appOnly when isPermanentlyDenied =>
        l10n.accessDeniedPermanentTitle,
      StorageAccessLevel.appOnly =>
        canRequestMore ? l10n.accessNarrowedTitle : l10n.accessSandboxTitle,
      StorageAccessLevel.full ||
      StorageAccessLevel.none =>
        l10n.accessUnsupportedTitle,
    };
  }

  String body(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return switch (level) {
      StorageAccessLevel.scopedFolders => l10n.accessScopedBody,
      StorageAccessLevel.appOnly when isPermanentlyDenied =>
        l10n.accessDeniedPermanentBody,
      StorageAccessLevel.appOnly =>
        canRequestMore ? l10n.accessNarrowedBody : l10n.accessSandboxBody,
      StorageAccessLevel.full ||
      StorageAccessLevel.none =>
        l10n.accessUnsupportedBody,
    };
  }
}
