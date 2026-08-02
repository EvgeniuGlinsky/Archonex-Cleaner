import 'package:flutter/material.dart';

/// Every type decision in the application.
///
/// A `TextStyle` with a literal `fontSize` or `fontWeight` belongs here and
/// nowhere else. Widgets ask the theme — `theme.textTheme.titleMedium` — and
/// where they need a variant they `copyWith` a *named* weight from
/// [AppTypography], not the number 700.
///
/// Every style a widget in this app asks for is set here, including the two
/// that used to be missing. `bodySmall` and `titleSmall` were left to Material's
/// defaults while five widgets asked for them, so the optimiser's tile subtitle
/// came out at 12 in the framework's grey while the cleaner's, one screen over,
/// was 14 in ours. Nothing reports that: an unset entry in a `TextTheme` is
/// filled in from `Typography`, quietly and plausibly.
class AppTypography {
  const AppTypography._();

  /// The family every style below is drawn in.
  ///
  /// `null` means the platform's own UI font: Roboto on Android, Segoe UI on
  /// Windows, SF on Apple, whatever the desktop is set to on Linux. That is the
  /// right default for an app that lists file names, because the system font is
  /// the one already chosen to render them legibly.
  ///
  /// Bundling a family is this constant plus an `assets:` entry in
  /// `pubspec.yaml`, and nothing else in the app changes.
  static const String? fontFamily = null;

  /// Numbers that sit in a column — sizes freed, file counts — are set in the
  /// tabular figures of the same family, so a list does not jitter as it grows.
  static const List<FontFeature> tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  static const double _displaySize = 40;
  static const double _headlineSize = 28;
  static const double _titleLargeSize = 22;
  static const double _titleMediumSize = 16;
  static const double _titleSmallSize = 14;
  static const double _bodyLargeSize = 16;
  static const double _bodyMediumSize = 14;
  static const double _bodySmallSize = 13;
  static const double _labelSize = 13;

  static const double _tightHeight = 1.15;
  static const double _readingHeight = 1.4;

  /// For text that sits inside a row rather than in a paragraph.
  ///
  /// Between the two above. [_readingHeight] is generous by design and adds up
  /// fast in a two-line tile subtitle; [_tightHeight] clips the descenders of a
  /// Cyrillic "у" against the line under it.
  static const double _compactHeight = 1.3;

  /// The one style not derived from [TextTheme]: the freed-space figure on the
  /// summary card, which is the largest thing on the screen on purpose.
  static TextStyle amount(Color color) => TextStyle(
        fontFamily: fontFamily,
        fontSize: _displaySize,
        fontWeight: bold,
        height: _tightHeight,
        fontFeatures: tabularFigures,
        color: color,
      );

  static TextTheme textTheme(ColorScheme colorScheme) {
    final Color onSurface = colorScheme.onSurface;
    final Color onSurfaceVariant = colorScheme.onSurfaceVariant;

    return TextTheme(
      headlineMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: _headlineSize,
        fontWeight: bold,
        height: _tightHeight,
        color: onSurface,
      ),
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: _titleLargeSize,
        fontWeight: semiBold,
        height: _tightHeight,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: _titleMediumSize,
        fontWeight: semiBold,
        color: onSurface,
      ),
      titleSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: _titleSmallSize,
        fontWeight: semiBold,
        color: onSurface,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: _bodyLargeSize,
        fontWeight: regular,
        height: _readingHeight,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: _bodyMediumSize,
        fontWeight: regular,
        height: _readingHeight,
        color: onSurfaceVariant,
      ),
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: _bodySmallSize,
        fontWeight: regular,
        height: _compactHeight,
        color: onSurfaceVariant,
      ),
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: _labelSize,
        fontWeight: medium,
        color: onSurfaceVariant,
      ),
    );
  }
}
