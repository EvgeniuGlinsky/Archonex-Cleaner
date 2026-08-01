import 'package:flutter/material.dart';

import 'package:storage_cleaner/core/constants/app_durations.dart';
import 'package:storage_cleaner/core/constants/app_radius.dart';
import 'package:storage_cleaner/core/constants/app_spacing.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';

/// App mark, name and tagline shown while the splash beat runs.
///
/// The entrance is a `TweenAnimationBuilder`, which runs once on the first
/// build and needs no controller and no `State`: the splash is on screen for a
/// second and never rebuilds, so there is nothing for a controller to control.
class SplashBranding extends StatelessWidget {
  const SplashBranding({super.key});

  static const double _markSize = 96;
  static const double _iconSize = 44;
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
          Container(
            width: _markSize,
            height: _markSize,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(
              Icons.cleaning_services_rounded,
              size: _iconSize,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.appName, style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.appTagline, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
