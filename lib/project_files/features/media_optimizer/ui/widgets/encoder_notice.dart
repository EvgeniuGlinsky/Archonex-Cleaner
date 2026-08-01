import 'package:flutter/material.dart';

import 'package:storage_cleaner/core/constants/app_radius.dart';
import 'package:storage_cleaner/core/constants/app_spacing.dart';
import 'package:storage_cleaner/core/theme/app_colors.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';

/// Says out loud that this machine found things it cannot act on.
///
/// The panel the honest version of this feature needs. A desktop can walk every
/// folder on the disk, work out that six gigabytes of video would come back,
/// and have no encoder to do it with — because on Windows and Linux the encoder
/// is whatever `ffmpeg` is on the path, and there may not be one. Silently
/// omitting those files would report a device with nothing to optimise, which
/// is the same lie as a cleaner reporting an empty sandbox as a clean phone.
///
/// It appears only when there is a gap between what was found and what can be
/// done, which is why the screen asks `state.hasBlockedKind` rather than
/// `!support.videos`: a machine with no video encoder and no videos has nothing
/// to explain.
class EncoderNotice extends StatelessWidget {
  const EncoderNotice({super.key});

  static const double _iconSize = 22;
  static const double _tintAlpha = 0.12;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColors colors = AppColors.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.caution.withValues(alpha: _tintAlpha),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, size: _iconSize, color: colors.caution),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.encoderMissingTitle,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.encoderMissingBody,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
