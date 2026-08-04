import 'package:flutter/material.dart';

import 'package:storage_cleaner/core/constants/app_radius.dart';
import 'package:storage_cleaner/core/constants/app_spacing.dart';

/// A bar and a line of text, for anything that runs long enough to report.
///
/// In `core/widgets/` because all three flow screens put it in their bottom slot
/// — a scan, a cleanup, a measurement and a re-encode. It lived in the cleaner's
/// own folder while the other two imported it from there, which is a dependency
/// between features that nothing else in the app has.
///
/// A `null` [progress] leaves the bar indeterminate, which is what a walk hands
/// it: a walk has no total until it is over, and a bar pretending to know how
/// far along it is would be a lie the user can watch being told.
class AppProgressIndicator extends StatelessWidget {
  const AppProgressIndicator({
    required this.label,
    this.progress,
    super.key,
  });

  static const double _barHeight = 6;

  final String label;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: _barHeight,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}
