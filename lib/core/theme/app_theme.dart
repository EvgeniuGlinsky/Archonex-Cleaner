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

  /// Floor for a row, replacing the framework's 56.
  ///
  /// The two lines these lists put in a row measure 40 between them, so 56 was
  /// 16 dp of nothing on every row of every list. 48 leaves the four either
  /// side the tiles ask for themselves and nothing more.
  static const double _tileHeight = 48;

  /// How much of `colorScheme.shadow` anything raised off the surface casts.
  ///
  /// Shared by the cards and the `AppBar` so the two do not drift: they are the
  /// only two things in the app that sit above the background.
  static const double _shadowAlpha = 0.12;

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
      // Flat and invisible at rest, a panel the moment anything is behind it.
      // The screens here keep their title in the scroll view, so the bar is
      // `surface` on a `surface` background and the only thing marking where
      // the scroll view begins is the line the content is cut at — and a
      // 28 dp title sliced through at a line nothing draws reads as the list
      // passing under the *title* rather than behind the bar. A shadow alone
      // said it too quietly to see: `_shadowAlpha` at two steps of elevation
      // is a few percent of black over a pale surface, which a phone screen
      // does not resolve. So the bar changes colour as well, which is the one
      // signal that survives being photographed.
      //
      // Through `WidgetStateColor` rather than a second `AppBar` per screen:
      // `AppBar` resolves this theme's `backgroundColor` against its own
      // states and already puts `scrolledUnder` among them.
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 3,
        backgroundColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.scrolledUnder)
              ? colorScheme.surfaceContainer
              : colorScheme.surface,
        ),
        // The tonal overlay Material would apply on top of that is a *second*
        // answer to the same question, and the two together overshot.
        surfaceTintColor: Colors.transparent,
        shadowColor: colorScheme.shadow.withValues(alpha: _shadowAlpha),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        surfaceTintColor: Colors.transparent,
        shadowColor: colorScheme.shadow.withValues(alpha: _shadowAlpha),
        // `md` rather than `lg`: a 24 dp corner on a card 48 dp tall curves for
        // half its height, which reads as padding the card does not have. The
        // two `ExpansionTile`s restate this radius on their own `shape`, and
        // have to, because `clipBehavior: antiAlias` here would otherwise clip
        // their ink at one radius while they drew their border at another.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
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
      // All five are here rather than on the two tiles that want them because
      // `ExpansionTile` exposes none of them, and the `ListTile` it builds
      // reads every one from this. The defaults are 16, 40, 16, 4 and 56; a
      // compact `Checkbox` is 32 across, so what the horizontal three give
      // back is 32 dp a category name gets on a 360 dp phone, and what the
      // vertical two give back is 16 dp of height on a row whose text
      // measures 40 — see `JunkCategoryTile`, where the arithmetic is written
      // out.
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        minLeadingWidth: _leadingWidth,
        horizontalTitleGap: AppSpacing.sm,
        minVerticalPadding: 0,
        minTileHeight: _tileHeight,
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
