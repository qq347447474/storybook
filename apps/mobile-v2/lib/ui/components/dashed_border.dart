/// Dashed strokes the hand-off draws but Flutter has no `Border.dashed` for.
///
/// Two call sites need them (`.media-ph { border: 1px dashed }` app.css L1035,
/// `.pace-row { border-top: 1px dashed }` app.css L2815), so the dash walk
/// lives here once instead of inside either component.
///
/// Cost: both painters are stateless and walk the path on every paint, which
/// is a handful of `extractPath` calls for a 320 × 213 frame. They never
/// animate, and `shouldRepaint` only fires when size or colour changes, so a
/// scrolling list does not re-dash per frame.
library;

import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/rendering.dart';

/// Paints a dashed outline of a rounded rectangle.
///
/// The dashes follow the same rounded path the fill uses, so a 1 px stroke
/// sits exactly on the container edge (the path is inset by half a stroke to
/// keep the stroke inside the box).
class DashedBoxBorderPainter extends CustomPainter {
  const DashedBoxBorderPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 1,
    this.dashLength = 5,
    this.gapLength = 4,
  });

  /// Stroke colour — a `line-strong` token at the call site.
  final Color color;

  /// Corner radius of the underlying box.
  final double radius;

  /// Stroke weight.
  final double strokeWidth;

  /// Length of one painted dash.
  final double dashLength;

  /// Length of the gap between two dashes.
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final double inset = strokeWidth / 2;
    final RRect outline = RRect.fromRectAndRadius(
      Offset(inset, inset) & Size(size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(radius - inset),
    );
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    _paintDashedPath(
      canvas,
      Path()..addRRect(outline),
      paint,
      dashLength: dashLength,
      gapLength: gapLength,
    );
  }

  @override
  bool shouldRepaint(DashedBoxBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gapLength != gapLength;
  }
}

/// Paints a dashed horizontal rule across the full width of the box.
///
/// Used as a section separator that reads as "same card, new topic" without
/// the weight of a solid divider (`.pace-row` in the retell feedback).
class DashedLinePainter extends CustomPainter {
  const DashedLinePainter({
    required this.color,
    this.strokeWidth = 1,
    this.dashLength = 4,
    this.gapLength = 4,
  });

  /// Stroke colour.
  final Color color;

  /// Stroke weight.
  final double strokeWidth;

  /// Length of one painted dash.
  final double dashLength;

  /// Length of the gap between two dashes.
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final Path line = Path()
      ..moveTo(0, strokeWidth / 2)
      ..lineTo(size.width, strokeWidth / 2);
    _paintDashedPath(
      canvas,
      line,
      paint,
      dashLength: dashLength,
      gapLength: gapLength,
    );
  }

  @override
  bool shouldRepaint(DashedLinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gapLength != gapLength;
  }
}

/// Walks [path] and strokes [dashLength] on, [gapLength] off.
void _paintDashedPath(
  Canvas canvas,
  Path path,
  Paint paint, {
  required double dashLength,
  required double gapLength,
}) {
  // A non-positive dash would either paint nothing or never advance.
  final double dash = dashLength > 0 ? dashLength : 1;
  final double gap = gapLength > 0 ? gapLength : 1;

  for (final PathMetric metric in path.computeMetrics()) {
    double distance = 0;
    while (distance < metric.length) {
      final double dashEnd = math.min(distance + dash, metric.length);
      canvas.drawPath(metric.extractPath(distance, dashEnd), paint);
      distance = dashEnd + gap;
    }
  }
}
