import 'package:flutter/material.dart';

import 'package:storage_cleaner/core/constants/app_durations.dart';
import 'package:storage_cleaner/core/constants/app_spacing.dart';
import 'package:storage_cleaner/core/theme/app_colors.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';

/// App mark, name and tagline shown while the splash beat runs.
///
/// The entrance is a `TweenAnimationBuilder`, which runs once on the first
/// build and needs no controller and no `State`: the splash is on screen for a
/// second and never rebuilds, so there is nothing for a controller to control.
class SplashBranding extends StatelessWidget {
  const SplashBranding({super.key});

  /// Larger than the 96 the tile used to be, because it no longer has one: the
  /// artwork filled about seven tenths of that square, and this is the size
  /// that leaves it weighing the same on the screen.
  static const double _markSize = 132;
  static const double _fromScale = 0.88;
  static const double _rise = AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return TweenAnimationBuilder<double>(
      duration: AppDurations.splashEntrance,
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * _rise),
          child: Transform.scale(
            scale: _fromScale + (1 - _fromScale) * t,
            child: child,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // The icon's artwork, not the icon: the whole tile would put its own
          // background on a field of nearly the same colour, and a rounded
          // square eight values away from what is behind it reads as a second
          // backdrop — which is the thing this screen was built to avoid.
          Image.asset(
            'assets/brand/app_mark.png',
            width: _markSize,
            height: _markSize,
            filterQuality: FilterQuality.medium,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n.appName,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppColors.onLaunchBackground,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.appTagline,
            style: theme.textTheme.bodyMedium?.copyWith(
              // The tagline reads under the name rather than beside it, and on
              // a coloured field a second full-strength white would compete
              // with it.
              color: AppColors.onLaunchBackground.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}
