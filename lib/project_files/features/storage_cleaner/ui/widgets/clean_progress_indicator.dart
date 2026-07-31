import 'package:flutter/material.dart';

import 'package:archonex_cleaner/core/constants/app_radius.dart';
import 'package:archonex_cleaner/core/constants/app_spacing.dart';

/// A bar and a line of text, used by both the scan and the cleanup.
///
/// The scan passes `null`: a walk has no total until it is over, and a bar
/// pretending to know how far along it is would be a lie the user can watch
/// being told.
class CleanProgressIndicator extends StatelessWidget {
  const CleanProgressIndicator({
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
