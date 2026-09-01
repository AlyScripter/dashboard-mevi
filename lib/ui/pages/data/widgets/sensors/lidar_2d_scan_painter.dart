import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Renders a single full-resolution LiDAR scan as a top-down X/Y scatter
/// plot, styled to match the reference "MEVI - Single LiDAR Scan" Python
/// (matplotlib) radar-style figure adapted to the dashboard's dark
/// cockpit theme: near-black plot background, a subtle dark cartesian
/// grid, axis ticks labelled in meters, white scan points, and a small
/// car-shaped (cube) marker at the origin showing the vehicle's forward
/// heading instead of a plain arrow.
///
/// Coordinate convention (matches sensor_msgs/LaserScan + ROS REP-103):
///   - X = forward (the direction the LiDAR/vehicle is facing)
///   - Y = left
///   - angle 0 = forward, positive angle = counter-clockwise (left)
class Lidar2DScanPainter extends CustomPainter {
  /// Raw ranges in meters. NaN / out-of-[rangeMin, rangeMax] entries are
  /// treated as "no return" and skipped.
  final List<double> ranges;
  final double angleMin;
  final double angleIncrement;
  final double rangeMin;
  final double rangeMax;
  final String title;

  /// Half-width/height of the plotted square, in meters — independent of
  /// [rangeMax] (the sensor's real physical spec, still used to filter
  /// which returns count as valid). Keeping this separate lets the view
  /// stay zoomed to a fixed, readable window (e.g. the reference video's
  /// 20x20m) even when the sensor itself is rated for a longer range.
  final double viewRangeMeters;

  Lidar2DScanPainter({
    required this.ranges,
    required this.angleMin,
    required this.angleIncrement,
    required this.rangeMin,
    required this.rangeMax,
    this.viewRangeMeters = 20.0,
    this.title = 'MEVI - Single LiDAR Scan',
  });

  // Dark cockpit theme (matches the rest of the dashboard's blue-black
  // glass look) instead of the original white matplotlib figure.
  static const Color _bgColor = Color(0xFF0A0D13);
  static const Color _gridColor = Color(0xFF1E2633);
  static const Color _axisColor = Color(0xFF3A4558);
  static const Color _tickTextColor = Color(0xFF9AA7BD);
  static const Color _titleColor = Color(0xFFF3F6FC);
  static const Color _pointColor = Color(0xFFF3F6FC); // white scan points
  static const Color _carColor = Color(0xFF22B2FF); // neon HUD blue

  List<Offset> _computePoints() {
    final points = <Offset>[];
    for (int i = 0; i < ranges.length; i++) {
      final r = ranges[i];
      if (r.isNaN || r < rangeMin || r > rangeMax) continue;
      final angle = angleMin + i * angleIncrement;
      final x = r * math.cos(angle);
      final y = r * math.sin(angle);
      points.add(Offset(x, y));
    }
    return points;
  }

  /// Chooses a "nice" tick step (1, 2, 2.5, 5, 10 x 10^n) for a given
  /// span, aiming for roughly [targetTicks] intervals — mirrors the
  /// behaviour of matplotlib's default MaxNLocator.
  double _niceStep(double span, int targetTicks) {
    if (span <= 0) return 1.0;
    final rough = span / targetTicks;
    final magnitude = math
        .pow(10, (math.log(rough) / math.ln10).floor())
        .toDouble();
    final residual = rough / magnitude;
    double niceResidual;
    if (residual > 5) {
      niceResidual = 10;
    } else if (residual > 2) {
      niceResidual = 5;
    } else if (residual > 1) {
      niceResidual = 2;
    } else {
      niceResidual = 1;
    }
    return niceResidual * magnitude;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(Offset.zero & size, Paint()..color = _bgColor);

    final points = _computePoints();

    // ---- Fixed bounds: always show the same [viewRangeMeters] window ----
    // This is a display choice (kept tight/zoomed so scan points stay
    // legible, matching the reference 20x20m video) and intentionally
    // decoupled from `rangeMax`, which is the sensor's real physical
    // spec and only used above to decide which returns are valid.
    final double span = viewRangeMeters > 0 ? viewRangeMeters : 20.0;
    final double pad = span * 0.05;
    double xMin = -span - pad;
    double xMax = span + pad;
    double yMin = -span - pad;
    double yMax = span + pad;

    // ---- Layout: reserve margins for title / axis labels / ticks ----
    const double leftMargin = 56;
    const double rightMargin = 18;
    const double topMargin = 34;
    const double bottomMargin = 46;

    final plotRect = Rect.fromLTRB(
      leftMargin,
      topMargin,
      size.width - rightMargin,
      size.height - bottomMargin,
    );

    if (plotRect.width <= 0 || plotRect.height <= 0) return;

    double dataToPx(double x) =>
        plotRect.left + (x - xMin) / (xMax - xMin) * plotRect.width;
    double dataToPy(double y) =>
        // Flip vertically: data-Y increases upward, canvas-Y increases
        // downward.
        plotRect.bottom - (y - yMin) / (yMax - yMin) * plotRect.height;

    // ---- Grid + ticks ----
    final gridPaint = Paint()
      ..color = _gridColor
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = _axisColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final xStep = _niceStep(xMax - xMin, 7);
    final yStep = _niceStep(yMax - yMin, 7);

    // Vertical grid lines + X tick labels
    double xTick = (xMin / xStep).ceil() * xStep;
    for (; xTick <= xMax + 1e-9; xTick += xStep) {
      final px = dataToPx(xTick);
      canvas.drawLine(
        Offset(px, plotRect.top),
        Offset(px, plotRect.bottom),
        gridPaint,
      );
      _drawText(
        canvas,
        _fmtTick(xTick),
        Offset(px, plotRect.bottom + 6),
        anchor: Alignment.topCenter,
        color: _tickTextColor,
        fontSize: 11,
      );
    }

    // Horizontal grid lines + Y tick labels
    double yTick = (yMin / yStep).ceil() * yStep;
    for (; yTick <= yMax + 1e-9; yTick += yStep) {
      final py = dataToPy(yTick);
      canvas.drawLine(
        Offset(plotRect.left, py),
        Offset(plotRect.right, py),
        gridPaint,
      );
      _drawText(
        canvas,
        _fmtTick(yTick),
        Offset(plotRect.left - 8, py),
        anchor: Alignment.centerRight,
        color: _tickTextColor,
        fontSize: 11,
      );
    }

    // Axis border box
    canvas.drawRect(plotRect, axisPaint);

    // Clip scatter/markers to the plot area so nothing bleeds into margins.
    canvas.save();
    canvas.clipRect(plotRect);

    // ---- Scatter points ----
    final pointPaint = Paint()..color = _pointColor.withValues(alpha: 0.85);
    for (final p in points) {
      canvas.drawCircle(
        Offset(dataToPx(p.dx), dataToPy(p.dy)),
        2.4,
        pointPaint,
      );
    }

    // ---- Vehicle marker: a cube/box car silhouette at the origin,
    // facing +X (forward), replacing the old heading arrow ----
    final origin = Offset(dataToPx(0), dataToPy(0));
    _drawCarMarker(canvas, origin, 22, 13, _carColor);

    canvas.restore();

    // ---- Title ----
    _drawText(
      canvas,
      title,
      Offset(size.width / 2, 6),
      anchor: Alignment.topCenter,
      color: _titleColor,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );

    // ---- Axis labels ----
    _drawText(
      canvas,
      'X (meter)',
      Offset(plotRect.center.dx, size.height - 8),
      anchor: Alignment.bottomCenter,
      color: _tickTextColor,
      fontSize: 12,
    );

    canvas.save();
    canvas.translate(14, plotRect.center.dy);
    canvas.rotate(-math.pi / 2);
    _drawText(
      canvas,
      'Y (meter)',
      Offset.zero,
      anchor: Alignment.center,
      color: _tickTextColor,
      fontSize: 12,
    );
    canvas.restore();
  }

  String _fmtTick(double v) {
    if (v.abs() < 1e-9) v = 0;
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  /// Draws a small top-down car silhouette (a rounded "cube"/box body plus
  /// a pointed nose) centered at [center] and facing screen +X — i.e. the
  /// LiDAR/vehicle forward direction — replacing the old heading-arrow +
  /// triangle marker. [length] and [width] are in screen pixels so the
  /// icon stays a constant on-screen size regardless of zoom/range.
  void _drawCarMarker(
    Canvas canvas,
    Offset center,
    double length,
    double width,
    Color color,
  ) {
    final halfL = length / 2;
    final halfW = width / 2;
    final bodyRect = Rect.fromCenter(
      center: center,
      width: length,
      height: width,
    );
    final bodyRRect = RRect.fromRectAndRadius(
      bodyRect,
      Radius.circular(halfW * 0.5),
    );

    // Soft glow behind the body, matching the dashboard's neon HUD look.
    canvas.drawRRect(
      bodyRRect,
      Paint()
        ..color = color.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Cube/box body.
    canvas.drawRRect(bodyRRect, Paint()..color = color);
    canvas.drawRRect(
      bodyRRect,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Pointed nose on the +X (forward) edge showing heading, echoing the
    // reference video's arrow without drawing a literal arrow.
    final noseTipX = center.dx + halfL + halfW * 0.6;
    final nosePath = Path()
      ..moveTo(center.dx + halfL, center.dy - halfW * 0.7)
      ..lineTo(noseTipX, center.dy)
      ..lineTo(center.dx + halfL, center.dy + halfW * 0.7)
      ..close();
    canvas.drawPath(nosePath, Paint()..color = color);

    // Windshield accent line so the box reads as a car, not a plain block.
    canvas.drawLine(
      Offset(center.dx - halfL * 0.15, center.dy - halfW * 0.85),
      Offset(center.dx - halfL * 0.15, center.dy + halfW * 0.85),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..strokeWidth = 1.4,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position, {
    required Alignment anchor,
    Color color = Colors.black,
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final dx = position.dx - (painter.width * (anchor.x + 1) / 2);
    final dy = position.dy - (painter.height * (anchor.y + 1) / 2);
    painter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant Lidar2DScanPainter oldDelegate) {
    return oldDelegate.ranges != ranges ||
        oldDelegate.angleMin != angleMin ||
        oldDelegate.angleIncrement != angleIncrement ||
        oldDelegate.rangeMin != rangeMin ||
        oldDelegate.rangeMax != rangeMax ||
        oldDelegate.viewRangeMeters != viewRangeMeters;
  }
}
