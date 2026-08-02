import 'package:flutter/material.dart';

import 'package:storage_cleaner/core/constants/app_radius.dart';
import 'package:storage_cleaner/core/constants/app_spacing.dart';
import 'package:storage_cleaner/core/theme/app_colors.dart';
import 'package:storage_cleaner/core/theme/app_typography.dart';

/// Assembles the two halves of the design into the theme the app runs on.
///
/// It defines nothing itself: colours come from `app_colors.dart`, type from
/// `app_typography.dart`, and the numbers from `core/constants/`. If a literal
/// appears in this file, it is in the wrong one of the three.
class AppTheme {
  const AppTheme._();

  static const double _buttonHeight = 54;

  /// What a row reserves for whatever sits before its text.
  ///
  /// A compact `Checkbox` and a 24 dp icon both fit; the framework's 40 does
  /// not correspond to anything this app puts there.
  static const double _leadingWidth = 32;

  static ThemeData light() => _build(Brightness.light, AppColors.light);

  static ThemeData dark() => _build(Brightness.dark, AppColors.dark);

  static ThemeData _build(Brightness brightness, AppColors appColors) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: colorScheme,
      fontFamily: AppTypography.fontFamily,
      textTheme: AppTypography.textTheme(colorScheme),
      scaffoldBackgroundColor: colorScheme.surface,
      extensions: <ThemeExtension<Object?>>[appColors],
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        surfaceTintColor: Colors.transparent,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(_buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          textStyle: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 16,
            fontWeight: AppTypography.semiBold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(_buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          textStyle: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 16,
            fontWeight: AppTypography.semiBold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      // `minLeadingWidth` and `horizontalTitleGap` are here rather than on the
      // two tiles that want them because `ExpansionTile` exposes neither, and
      // the `ListTile` it builds reads both from this. The defaults are 40 and
      // 16; a compact `Checkbox` is 32 across, and the 24 those two give back
      // is 24 a category name gets on a 360 dp phone — see `JunkCategoryTile`,
      // where the arithmetic is written out.
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        minLeadingWidth: _leadingWidth,
        horizontalTitleGap: AppSpacing.sm,
      ),
      dividerTheme: DividerThemeData(
        space: AppSpacing.lg,
        thickness: 1,
        color: colorScheme.outlineVariant,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: colorScheme.surfaceContainerHighest,
      ),
    );
  }
}
