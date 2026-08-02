import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:storage_cleaner/core/constants/app_spacing.dart';
import 'package:storage_cleaner/core/theme/app_typography.dart';

/// One arc of the breakdown ring.
@immutable
class RingSegment {
  const RingSegment({required this.fraction, required this.colour});

  /// `0`–`1` of the whole volume.
  final double fraction;
  final Color colour;
}

/// The whole disk as one ring, cut into as many arcs as there are kinds of file.
///
/// A separate widget from `StorageRing` rather than a generalisation of it, and
/// the reason is in that file's own header: there, the junk arc is painted over
/// the *end* of the used arc because junk is part of used, not a third thing
/// beside it. Its three call sites depend on that. Here every arc is a peer and
/// they lie end to end around the whole circle — the same code cannot mean both,
/// and making it try would break a screen that is already right.
///
/// A donut and not a pie, because the middle is where the figure goes and a
/// figure is what somebody with a full disk is looking for. Segments are
/// separated by a two-pixel gap rather than by a stroke: a stroke is a colour,
/// and a sixth colour on a chart whose whole job is telling five apart is the
/// wrong thing to add. The gap shows the track underneath, which is also what
/// the free arc is drawn in — the absence, in both cases. It is the second
/// channel the palette's tritan separation leans on; see `AppColors.slices`.
class StorageBreakdownRing extends StatelessWidget {
  const StorageBreakdownRing({
    required this.segments,
    required this.title,
    required this.caption,
    this.isBusy = false,
    super.key,
  });

  static const double _diameter = 184;
  static const double _stroke = 20;

  /// In drawing order, starting at twelve o'clock.
  final List<RingSegment> segments;

  /// The figure in the middle, already formatted and translated.
  final String title;
  final String caption;

  /// A measurement is running. Adds the indeterminate sweep on top.
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: SizedBox(
        width: _diameter,
        height: _diameter,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            CustomPaint(
              size: const Size.square(_diameter),
              painter: _BreakdownPainter(
                segments: segments,
                trackColor: theme.colorScheme.surfaceContainerHighest,
                strokeWidth: _stroke,
              ),
            ),
            if (isBusy)
              const SizedBox.square(
                dimension: _diameter,
                child: CircularProgressIndicator(
                  strokeWidth: _stroke,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.transparent,
                ),
              ),
            _Centre(title: title, caption: caption),
          ],
        ),
      ),
    );
  }
}

class _Centre extends StatelessWidget {
  const _Centre({required this.title, required this.caption});

  /// Kept clear of the arc without eating the figure — the same inset
  /// `StorageRing` arrived at, and for the same reason.
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

class _BreakdownPainter extends CustomPainter {
  const _BreakdownPainter({
    required this.segments,
    required this.trackColor,
    required this.strokeWidth,
  });

  /// Twelve o'clock. Canvas angles start at three.
  static const double _start = -math.pi / 2;
  static const double _full = math.pi * 2;

  /// The gap between two arcs, in logical pixels of arc length.
  ///
  /// Two, as the mark spec asks. Converted to an angle from the ring's own
  /// radius rather than fixed, so it stays two pixels wide however large the
  /// ring is drawn.
  static const double _gapPixels = 2;

  final List<RingSegment> segments;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final Rect arc = bounds.deflate(strokeWidth / 2);
    final double radius = arc.width / 2;
    final double gap = radius <= 0 ? 0 : _gapPixels / radius;

    canvas.drawArc(arc, _start, _full, false, _paint(trackColor));

    double cursor = _start;

    for (final RingSegment segment in segments) {
      final double sweep = _clamped(segment.fraction) * _full;

      // Below the gap it would be drawn as nothing, or worse as a backwards
      // arc. A category too small to see is one the row underneath still names,
      // which is the honest place for it.
      if (sweep <= gap) {
        cursor += sweep;

        continue;
      }

      canvas.drawArc(
        arc,
        cursor,
        sweep - gap,
        false,
        _paint(segment.colour),
      );

      cursor += sweep;
    }
  }

  Paint _paint(Color color) => Paint()
    ..color = color
    ..strokeWidth = strokeWidth
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
  bool shouldRepaint(_BreakdownPainter oldDelegate) =>
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.trackColor != trackColor ||
      !_sameSegments(oldDelegate.segments, segments);

  /// `RingSegment` is not `Equatable` and does not need to be: it exists for
  /// this painter and this is the only place two of them are ever compared.
  static bool _sameSegments(List<RingSegment> a, List<RingSegment> b) {
    if (a.length != b.length) {
      return false;
    }

    for (int index = 0; index < a.length; index++) {
      if (a[index].fraction != b[index].fraction ||
          a[index].colour != b[index].colour) {
        return false;
      }
    }

    return true;
  }
}
