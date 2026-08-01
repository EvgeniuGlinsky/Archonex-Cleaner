import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:archonex_cleaner/core/constants/app_durations.dart';
import 'package:archonex_cleaner/core/constants/app_spacing.dart';
import 'package:archonex_cleaner/core/theme/app_colors.dart';
import 'package:archonex_cleaner/core/theme/app_typography.dart';

/// How full the device is, as the first thing on the screen.
///
/// Two fractions rather than a `DeviceStorageSnapshot`: the widget is drawn on
/// the home screen against the whole disk and on the cleaner against the same
/// disk with the found junk highlighted inside it, and whether there is anything
/// to draw at all is a question the body above it already answers by leaving it
/// out. Handed plain numbers, it has nothing to decide and nothing to be wrong
/// about.
///
/// The junk arc is painted over the *end* of the used arc rather than beside it,
/// because junk is not a third thing next to used and free — it is the part of
/// used that can go, and putting it anywhere else would add up to more than the
/// disk holds.
class StorageRing extends StatelessWidget {
  const StorageRing({
    required this.usedFraction,
    required this.title,
    required this.caption,
    this.junkFraction = 0,
    this.isBusy = false,
    super.key,
  });

  static const double _diameter = 208;
  static const double _stroke = 18;

  /// `0`–`1` of the whole volume.
  final double usedFraction;

  /// `0`–`1` of the whole volume, drawn inside [usedFraction].
  final double junkFraction;

  /// The figure in the middle, already formatted and translated.
  final String title;

  /// The line under it.
  final String caption;

  /// A scan is walking the disk. Adds the indeterminate sweep on top.
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColors colors = AppColors.of(context);

    return Center(
      child: SizedBox(
        width: _diameter,
        height: _diameter,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // Only the used arc is animated. It moves once, from nothing to the
            // real figure, when the plugin answers — which is exactly the jump
            // worth easing. The junk arc arrives in batches many times a second
            // during a scan, and easing each batch would leave it permanently
            // behind the number printed in the middle of it.
            TweenAnimationBuilder<double>(
              duration: AppDurations.ringSweep,
              curve: Curves.easeOutCubic,
              tween: Tween<double>(begin: 0, end: usedFraction),
              builder: (context, used, _) => CustomPaint(
                size: const Size.square(_diameter),
                painter: _RingPainter(
                  usedFraction: used,
                  junkFraction: junkFraction,
                  trackColor: theme.colorScheme.surfaceContainerHighest,
                  usedColor: theme.colorScheme.primary,
                  junkColor: colors.freed,
                  strokeWidth: _stroke,
                ),
              ),
            ),
            if (isBusy)
              SizedBox.square(
                dimension: _diameter,
                child: CircularProgressIndicator(
                  strokeWidth: _stroke,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.transparent,
                ),
              ),
            _RingCentre(title: title, caption: caption),
          ],
        ),
      ),
    );
  }
}

class _RingCentre extends StatelessWidget {
  const _RingCentre({required this.title, required this.caption});

  /// Kept clear of the arc without eating the figure.
  ///
  /// It was [AppSpacing.huge], which left 112 of the ring's 208 and had the
  /// `FittedBox` shrinking the one number the screen exists to show to about
  /// two thirds of its size, with the caption wrapping under it.
  static const double _inset = AppSpacing.xl;

  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FittedBox(
            child: Text(
              title,
              maxLines: 1,
              style: AppTypography.amount(theme.colorScheme.onSurface),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            caption,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.usedFraction,
    required this.junkFraction,
    required this.trackColor,
    required this.usedColor,
    required this.junkColor,
    required this.strokeWidth,
  });

  /// Twelve o'clock. Canvas angles start at three.
  static const double _start = -math.pi / 2;
  static const double _full = math.pi * 2;

  final double usedFraction;
  final double junkFraction;
  final Color trackColor;
  final Color usedColor;
  final Color junkColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final Rect arc = bounds.deflate(strokeWidth / 2);
    final double used = _clamped(usedFraction);
    final double junk = _clamped(junkFraction) > used
        ? used
        : _clamped(junkFraction);

    canvas.drawArc(arc, _start, _full, false, _paint(trackColor));

    if (used > 0) {
      canvas.drawArc(arc, _start, used * _full, false, _paint(usedColor));
    }

    if (junk > 0) {
      canvas.drawArc(
        arc,
        _start + (used - junk) * _full,
        junk * _full,
        false,
        _paint(junkColor),
      );
    }
  }

  Paint _paint(Color color) => Paint()
    ..color = color
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  /// A `NaN` reaching a sweep angle throws inside the canvas, and the fractions
  /// come from a division the caller may have done on a zero total.
  static double _clamped(double value) {
    if (value.isNaN || value <= 0) {
      return 0;
    }

    return value > 1 ? 1 : value;
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.usedFraction != usedFraction ||
      oldDelegate.junkFraction != junkFraction ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.usedColor != usedColor ||
      oldDelegate.junkColor != junkColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
