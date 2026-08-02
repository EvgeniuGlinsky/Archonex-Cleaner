import 'package:flutter/material.dart';

import 'package:storage_cleaner/core/constants/app_spacing.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_quality.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/ui/mappers/optimize_quality_ui.dart';

/// The one setting this app has, above the list it changes.
///
/// Above rather than behind a settings screen, because it is not a preference
/// in the usual sense — it is the other half of the number on the button. Every
/// estimate on this screen is measured against it, and moving it re-measures
/// them all in place, so a user who thinks the offer is too small can see what
/// pressing harder would actually give them before they agree to anything.
///
/// A `SegmentedButton` and not a slider: there are three answers and they are
/// named, and a slider would imply a continuum the encoders do not have.
/// Icons are off — three Russian words with a tick in front of each does not
/// fit a 360 dp phone, and the selected one is already obvious.
class QualitySelector extends StatelessWidget {
  const QualitySelector({
    required this.quality,
    required this.isEnabled,
    required this.onChanged,
    super.key,
  });

  final OptimizeQuality quality;

  /// False while a run is going. The files in flight were planned under the
  /// current preset and the encoder has already been told; changing it
  /// underneath them would leave the report describing one thing and the disk
  /// holding another.
  final bool isEnabled;

  final ValueChanged<OptimizeQuality> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.qualityTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<OptimizeQuality>(
                showSelectedIcon: false,
                segments: <ButtonSegment<OptimizeQuality>>[
                  for (final OptimizeQuality value in OptimizeQuality.values)
                    ButtonSegment<OptimizeQuality>(
                      value: value,
                      label: Text(
                        value.title(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                selected: <OptimizeQuality>{quality},
                onSelectionChanged:
                    isEnabled ? (values) => onChanged(values.first) : null,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(quality.hint(context), style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
