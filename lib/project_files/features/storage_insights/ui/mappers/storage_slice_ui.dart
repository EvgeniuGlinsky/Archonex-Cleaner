import 'package:flutter/material.dart';

import 'package:storage_cleaner/core/theme/app_colors.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/storage_slice.dart';

/// Everything a widget renders about a [StorageSliceCategory].
///
/// The enum carries no copy and no colour, for the reason `JunkCategoryUi`
/// gives: translating the app is an ARB file and restyling it is this one.
///
/// The colour assignment is the part worth reading. The five real categories
/// take the five validated hues *by fixed index* — `photos` is always slot 1,
/// whatever else is on screen — because colour follows the entity and never its
/// rank. A chart that repainted its survivors when a category came back empty
/// would be a chart nobody could compare with the one they saw yesterday. The
/// two rows that are not kinds of file get greys instead of hues, so they never
/// compete with the ones that are.
extension StorageSliceUi on StorageSliceCategory {
  String title(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return switch (this) {
      StorageSliceCategory.photos => l10n.slicePhotos,
      StorageSliceCategory.videos => l10n.sliceVideos,
      StorageSliceCategory.audio => l10n.sliceAudio,
      StorageSliceCategory.documents => l10n.sliceDocuments,
      StorageSliceCategory.archives => l10n.sliceArchives,
      StorageSliceCategory.other => l10n.sliceOther,
      StorageSliceCategory.system => l10n.sliceSystem,
      StorageSliceCategory.free => l10n.sliceFree,
    };
  }

  Color colour(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final ThemeData theme = Theme.of(context);

    return switch (this) {
      StorageSliceCategory.videos => colors.slices[0],
      StorageSliceCategory.photos => colors.slices[1],
      StorageSliceCategory.audio => colors.slices[2],
      StorageSliceCategory.documents => colors.slices[3],
      StorageSliceCategory.archives => colors.slices[4],
      StorageSliceCategory.other => colors.sliceOther,
      StorageSliceCategory.system => colors.sliceSystem,
      // Not drawn as a segment at all — it is the ring's own track, and the row
      // takes the same colour so the legend and the ring agree.
      StorageSliceCategory.free => theme.colorScheme.surfaceContainerHighest,
    };
  }
}
