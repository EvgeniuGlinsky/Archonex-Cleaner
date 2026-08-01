import 'package:flutter/material.dart';

import 'package:storage_cleaner/core/constants/app_spacing.dart';

/// Title + supporting text pair used at the top of the flow screens.
class AppScreenHeader extends StatelessWidget {
  const AppScreenHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String subtitle;

  /// The one action a screen keeps next to its title rather than at the bottom
  /// — the language button, the quarantine button. `null` on most screens.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(subtitle, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: AppSpacing.lg),
          trailing!,
        ],
      ],
    );
  }
}
