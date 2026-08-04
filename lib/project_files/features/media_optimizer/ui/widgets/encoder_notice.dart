import 'package:flutter/material.dart';

import 'package:storage_cleaner/core/constants/app_radius.dart';
import 'package:storage_cleaner/core/constants/app_spacing.dart';
import 'package:storage_cleaner/core/theme/app_colors.dart';
import 'package:storage_cleaner/core/utils/file_size_formatter.dart';
import 'package:storage_cleaner/core/widgets/app_progress_indicator.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';

/// The panel about the video encoder: what is missing, and what can be done.
///
/// A desktop can walk every folder on the disk, work out that six gigabytes of
/// video would come back, and have no encoder to do it with. Silently omitting
/// those files would report a device with nothing to optimise, which is the same
/// lie as a cleaner reporting an empty sandbox as a clean phone — so the gap is
/// said out loud.
///
/// What it says depends on whether the gap can be closed, and that is the whole
/// point of this widget having three states rather than one sentence. It used to
/// have one: *videos need FFmpeg, and this machine has none on its path; install
/// it and open this screen again*. Every word of that was true and it was still
/// the wrong panel, because it hands the application's own job to the user, in a
/// vocabulary — a path, an executable, a package — that the rest of this app
/// deliberately never uses. On the desktops there is now a button; on a phone
/// whose media stack has no HEVC encoder there is nothing to press, and the
/// sentence says so without naming a tool nobody can install there.
class EncoderNotice extends StatelessWidget {
  const EncoderNotice({
    required this.canFetch,
    required this.downloadBytes,
    required this.fetchProgress,
    required this.onFetchPressed,
    required this.onFetchCancelled,
    super.key,
  });

  static const double _iconSize = 22;
  static const double _tintAlpha = 0.12;

  /// Whether this machine can be handed an encoder — see
  /// `MediaOptimizerState.canFetchEncoder`.
  final bool canFetch;

  /// Roughly what that download weighs. Named in the offer, because a download
  /// of unstated size is one nobody agrees to on a metered connection.
  final int downloadBytes;

  /// `0`–`1` while it is running, `null` otherwise.
  final double? fetchProgress;

  final VoidCallback onFetchPressed;
  final VoidCallback onFetchCancelled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColors colors = AppColors.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final double? progress = fetchProgress;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.caution.withValues(alpha: _tintAlpha),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            progress == null ? Icons.info_outline : Icons.downloading_outlined,
            size: _iconSize,
            color: colors.caution,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  progress != null
                      ? l10n.encoderFetchingTitle
                      : canFetch
                          ? l10n.encoderSetupTitle
                          : l10n.encoderMissingTitle,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                if (progress != null) ...<Widget>[
                  // The same bar the scan and the run use. A download of this
                  // size is the one wait in the app long enough that a spinner
                  // would be indistinguishable from a hang.
                  AppProgressIndicator(
                    label: l10n.encoderFetchingBody,
                    progress: progress,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: onFetchCancelled,
                      child: Text(l10n.cancelLabel),
                    ),
                  ),
                ] else ...<Widget>[
                  Text(
                    canFetch
                        ? l10n.encoderSetupBody(
                            FileSizeFormatter.format(downloadBytes),
                          )
                        : l10n.encoderMissingBody,
                    style: theme.textTheme.bodySmall,
                  ),
                  if (canFetch) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    // Tonal rather than filled: the screen's one filled button is
                    // in the bottom slot and is the thing the screen is for.
                    // Two filled buttons is two primary actions.
                    FilledButton.tonal(
                      onPressed: onFetchPressed,
                      child: Text(l10n.encoderSetupLabel),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
