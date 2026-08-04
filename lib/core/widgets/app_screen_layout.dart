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
/// tiles. Worse, the list clipped flush against the header, and a card sliding
/// up simply got cut in half at a line nothing explained, which reads as
/// passing *under* the title. The `AppBar` above this now raises itself once
/// something is behind it, so the one line content is still cut at is a line
/// the bar's own shadow accounts for.
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
    this.fillsViewport = false,
    super.key,
  });

  /// Inset on all four edges of both the scrolling half and the pinned one.
  ///
  /// [AppSpacing.md] rather than `xl`: at 24 a tile on a 360 dp phone was left
  /// 312 dp to fit a checkbox, an icon, a name and two figures into, and it did
  /// not. Each step down since has gone straight into the category name, which
  /// is the one thing on these screens with nowhere else to go — the cards
  /// carry their own padding, so the gap to the window edge is the only inset
  /// counted twice. Below 12 the cards stop reading as cards.
  static const double _inset = AppSpacing.md;

  final Widget header;
  final Widget body;
  final Widget? bottom;

  /// Whether the scrolling half should be at least as tall as the window, so a
  /// short [body] can spread into the space instead of leaving it blank.
  ///
  /// Off by default, and it has to be: filling the viewport means measuring the
  /// content's intrinsic height, and the two category tiles lay their figures out
  /// with a `LayoutBuilder`, which cannot be measured that way — it throws rather
  /// than running its callback speculatively. So this is for screens whose short
  /// state holds no tiles, which is the only state that has room to spare
  /// anyway. `StorageInsightsView` turns it on until something has been counted,
  /// and its body then takes the remainder with an `Expanded`.
  final bool fillsViewport;

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
              Expanded(child: fillsViewport ? _filled() : _scrolled()),
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

  static const EdgeInsets _padding = EdgeInsets.fromLTRB(
    _inset,
    AppSpacing.sm,
    _inset,
    _inset,
  );

  /// The ordinary case: one list, measured by its contents.
  Widget _scrolled() {
    return ListView(
      padding: _padding,
      children: <Widget>[
        header,
        const SizedBox(height: AppSpacing.lg),
        body,
      ],
    );
  }

  /// At least a windowful, so [body] can take what is left over.
  Widget _filled() {
    return CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding: _padding,
          sliver: SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                header,
                const SizedBox(height: AppSpacing.lg),
                body,
              ],
            ),
          ),
        ),
      ],
    );
  }
}
