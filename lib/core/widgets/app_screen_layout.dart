import 'package:flutter/material.dart';

import 'package:storage_cleaner/core/constants/app_breakpoints.dart';
import 'package:storage_cleaner/core/constants/app_spacing.dart';

/// Positioning-only layout shared by the full-page flow screens.
///
/// It never builds content: every slot arrives through the constructor.
///
/// The header scrolls with the body rather than sitting above it. It used to be
/// a fixed `Column` child over an `Expanded` list, and on a 360×640 phone the
/// arithmetic of that was unkind: status bar and `AppBar` take 80, this padding
/// took another 24, and a Russian title with its three-line subtitle took 130
/// more — leaving about 250 for the scrolling half, which is two collapsed
/// tiles. Worse, the list clipped flush against the header with no shadow or
/// divider between them, because `AppBarTheme` deliberately has no
/// `scrolledUnderElevation`; a card sliding up simply got cut in half at a line
/// nothing explained, which reads as passing *under* the title.
///
/// [bottom] stays pinned, and that difference is deliberate. It holds the one
/// thing the screen exists to let the user press, and a primary action that
/// scrolls out of reach is a screen the user has to hunt around before they can
/// finish. The header is prose; the button is the point.
class AppScreenLayout extends StatelessWidget {
  const AppScreenLayout({
    required this.header,
    required this.body,
    this.bottom,
    super.key,
  });

  /// Inset on all four edges of both the scrolling half and the pinned one.
  ///
  /// [AppSpacing.lg] rather than `xl`: at 24 a tile on a 360 dp phone was left
  /// 312 dp to fit a checkbox, an icon, a name and two figures into, and it did
  /// not. The 16 dp this gives back is a third of what made the tiles fit.
  static const double _inset = AppSpacing.lg;

  final Widget header;
  final Widget body;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.maxContentWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    _inset,
                    AppSpacing.sm,
                    _inset,
                    _inset,
                  ),
                  children: <Widget>[
                    header,
                    const SizedBox(height: AppSpacing.lg),
                    body,
                  ],
                ),
              ),
              if (bottom != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _inset,
                    AppSpacing.sm,
                    _inset,
                    _inset,
                  ),
                  child: bottom,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
