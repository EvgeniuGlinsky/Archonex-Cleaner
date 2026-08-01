import 'package:flutter/material.dart';

import 'package:storage_cleaner/core/constants/app_spacing.dart';

/// Centres the splash content. Positioning only.
///
/// The one screen with a layout of its own: splash has no header and no bottom
/// slot, so `AppScreenLayout` would be three empty slots and one used one.
class SplashLayout extends StatelessWidget {
  const SplashLayout({required this.body, super.key});

  final Widget body;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(child: body),
      ),
    );
  }
}
