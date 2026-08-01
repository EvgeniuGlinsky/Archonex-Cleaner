import 'package:flutter/material.dart';

import 'package:archonex_cleaner/l10n/app_localizations.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/media_kind.dart';

/// Everything a widget renders about a [MediaKind].
///
/// The enum carries no copy and no icon, for the reason `JunkCategoryUi` gives:
/// translating the app is an ARB file and restyling it is this one.
extension MediaKindUi on MediaKind {
  String title(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return switch (this) {
      MediaKind.video => l10n.mediaVideosTitle,
      MediaKind.photo => l10n.mediaPhotosTitle,
    };
  }

  String subtitle(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return switch (this) {
      MediaKind.video => l10n.mediaVideosSubtitle,
      MediaKind.photo => l10n.mediaPhotosSubtitle,
    };
  }

  IconData get icon => switch (this) {
        MediaKind.video => Icons.movie_outlined,
        MediaKind.photo => Icons.photo_outlined,
      };
}
