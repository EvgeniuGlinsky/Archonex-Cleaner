import 'package:flutter/material.dart';

import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_quality.dart';

/// Everything a widget renders about an [OptimizeQuality].
///
/// The enum carries the numbers and no copy, for the reason `MediaKindUi`
/// gives: translating the app is an ARB file and restyling it is this one.
extension OptimizeQualityUi on OptimizeQuality {
  String title(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return switch (this) {
      OptimizeQuality.gentle => l10n.qualityGentle,
      OptimizeQuality.balanced => l10n.qualityBalanced,
      OptimizeQuality.maximum => l10n.qualityMaximum,
    };
  }

  /// One sentence about what the choice costs, under the switch.
  ///
  /// Written in terms of what the user will see rather than in bitrates. "0.035
  /// bits per pixel per frame" is the honest description and is no help at all
  /// to somebody deciding whether to press it on their holiday footage.
  String hint(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return switch (this) {
      OptimizeQuality.gentle => l10n.qualityGentleHint,
      OptimizeQuality.balanced => l10n.qualityBalancedHint,
      OptimizeQuality.maximum => l10n.qualityMaximumHint,
    };
  }
}
