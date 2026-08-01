import 'package:flutter/material.dart';

import 'package:storage_cleaner/core/theme/app_colors.dart';

/// Full width call-to-action button. Styling lives in `AppTheme`.
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Draws the button in `AppColors.danger`.
  ///
  /// A flag rather than a second widget: there is exactly one destructive
  /// button in the app and it is identical to this one in every other respect.
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);

    return FilledButton(
      onPressed: onPressed,
      style: isDestructive
          ? FilledButton.styleFrom(
              backgroundColor: colors.danger,
              foregroundColor: colors.onDanger,
            )
          : null,
      child: Text(label),
    );
  }
}
