import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Lidar Polar Painter - Front-arc view (matches lidarnode_w.py FOV)
/// Vehicle at bottom center, arc extends upward showing front view
class LidarPolarPainter extends CustomPainter {
  final List<double> ranges;
  final List<double> intensities;
  final double angleMin; // in radians (e.g., -40° = -0.698 rad)
  final double angleMax; // in radians (e.g., +40° = +0.698 rad)
  final double angleIncrement;
  final double rangeMax;
  final bool showGrid;
  final bool showIntensity;
  final double zoomLevel;
  final Offset panOffset;

  LidarPolarPainter({
    required this.ranges,
    required this.intensities,
    required this.angleMin,
    required this.angleMax,
    required this.angleIncrement,
    required this.rangeMax,
    required this.showGrid,
    required this.showIntensity,
    required this.zoomLevel,
    required this.panOffset,
  });

  // Convert lidar angle to canvas angle (0° = straight up)
  double _lidarToCanvasAngle(double lidarAngle) {
    // Lidar: 0° = forward, positive = right, negative = left
    // Canvas: -90° = up, 0° = right
    return -math.pi / 2 + lidarAngle;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Vehicle at bottom center, arc extends upward
    final center = Offset(size.width / 2, size.height * 0.9) + panOffset;
    final radius = (math.min(size.width, size.height * 0.85) / 2 - 10) * zoomLevel;

    // Draw grid arcs
    if (showGrid) {
      _drawArcGrid(canvas, center, radius);
    }

    // Draw range arcs
    _drawRangeArcs(canvas, center, radius);

    // Draw segment lines
    _drawSegmentLines(canvas, center, radius);

    // Draw LiDAR points
    _drawLidarPoints(canvas, center, radius);

    // Draw vehicle position at bottom
    _drawVehiclePosition(canvas, center);

    // Draw range labels
    _drawRangeLabels(canvas, center, radius);
  }

  void _drawArcGrid(Canvas canvas, Offset center, double radius) {
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final startAngle = _lidarToCanvasAngle(angleMin);
    final sweepAngle = angleMax - angleMin;

    // Draw concentric arcs (not full circles)
    for (int i = 1; i <= 4; i++) {
      final arcRadius = radius * (i / 4);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: arcRadius),
        startAngle,
        sweepAngle,
        false,
        gridPaint,
      );
    }
  }

  void _drawRangeArcs(Canvas canvas, Offset center, double radius) {
    final rangePaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final startAngle = _lidarToCanvasAngle(angleMin);
    final sweepAngle = angleMax - angleMin;

    // Draw outer range arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      rangePaint,
    );
  }

  void _drawSegmentLines(Canvas canvas, Offset center, double radius) {
    // Draw segment lines matching lidarnode_w.py: [40, 30, 20, 0, -20, -30, -40]
    final segmentAngles = [40.0, 30.0, 20.0, 0.0, -20.0, -30.0, -40.0];
    
    final linePaint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.3)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (final angleDeg in segmentAngles) {
      final angleRad = angleDeg * math.pi / 180;
      final canvasAngle = _lidarToCanvasAngle(angleRad);
      
      final endPoint = Offset(
        center.dx + radius * math.cos(canvasAngle),
        center.dy + radius * math.sin(canvasAngle),
      );
      
      canvas.drawLine(center, endPoint, linePaint);
    }

    // Draw center line (0°) with different style
    final centerLinePaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final centerAngle = _lidarToCanvasAngle(0);
    final centerEnd = Offset(
      center.dx + radius * math.cos(centerAngle),
      center.dy + radius * math.sin(centerAngle),
    );
    canvas.drawLine(center, centerEnd, centerLinePaint);
  }

  void _drawLidarPoints(Canvas canvas, Offset center, double radius) {
    if (ranges.isEmpty) return;

    for (int i = 0; i < ranges.length; i++) {
      final lidarAngle = angleMin + (i * angleIncrement);
      final range = ranges[i];

      // Skip invalid readings
      if (range <= 0 || range > rangeMax || !range.isFinite) continue;

      // Calculate point position
      final normalizedRange = range / rangeMax;
      final pointRadius = radius * normalizedRange;
      final canvasAngle = _lidarToCanvasAngle(lidarAngle);

      final pointPosition = Offset(
        center.dx + pointRadius * math.cos(canvasAngle),
        center.dy + pointRadius * math.sin(canvasAngle),
      );

      // Color based on distance (closer = red, farther = green)
      Color pointColor;
      if (showIntensity && i < intensities.length) {
        pointColor = _getIntensityColor(intensities[i]);
      } else {
        final distanceRatio = range / rangeMax;
        if (distanceRatio < 0.33) {
          pointColor = Colors.red;
        } else if (distanceRatio < 0.66) {
          pointColor = Colors.orange;
        } else {
          pointColor = Colors.green;
        }
      }

      // Draw glow effect
      final glowPaint = Paint()
        ..color = pointColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pointPosition, 4, glowPaint);

      // Draw solid point
      final pointPaint = Paint()
        ..color = pointColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pointPosition, 2, pointPaint);
    }
  }

  void _drawVehiclePosition(Canvas canvas, Offset center) {
    // Draw vehicle as arrow pointing up (forward)
    final vehiclePaint = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(center.dx, center.dy - 12); // Top point
    path.lineTo(center.dx - 8, center.dy + 4); // Bottom left
    path.lineTo(center.dx - 3, center.dy);
    path.lineTo(center.dx, center.dy + 8); // Bottom center
    path.lineTo(center.dx + 3, center.dy);
    path.lineTo(center.dx + 8, center.dy + 4); // Bottom right
    path.close();

    canvas.drawPath(path, vehiclePaint);

    // Draw outline
    final outlinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, outlinePaint);

    // Draw center dot
    canvas.drawCircle(center, 2, Paint()..color = Colors.white);
  }

  void _drawRangeLabels(Canvas canvas, Offset center, double radius) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final centerAngle = _lidarToCanvasAngle(0); // straight up

    for (int i = 1; i <= 3; i++) {
      final arcRadius = radius * i / 3;
      final rangeValue = (rangeMax * i / 3).toStringAsFixed(1);

      textPainter.text = TextSpan(
        text: '${rangeValue}m',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();

      // Position labels along center line (forward direction)
      final labelPos = Offset(
        center.dx + arcRadius * math.cos(centerAngle) + 5,
        center.dy + arcRadius * math.sin(centerAngle) - textPainter.height / 2,
      );

      textPainter.paint(canvas, labelPos);
    }
  }

  Color _getIntensityColor(double intensity) {
    final normalized = intensity.clamp(0.0, 1.0);
    final hue = 120 - (normalized * 120); // Green to Red
    return HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class LidarHeatmapPainter extends CustomPainter {
  final List<double> ranges;
  final List<double> intensities;
  final double angleMin;
  final double angleMax;
  final double angleIncrement;
  final double rangeMax;
  final bool showGrid;

  LidarHeatmapPainter({
    required this.ranges,
    required this.intensities,
    required this.angleMin,
    required this.angleMax,
    required this.angleIncrement,
    required this.rangeMax,
    required this.showGrid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;

    // Draw background
    final backgroundPaint = Paint()..color = Colors.black.withValues(alpha: 0.8);
    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw heatmap
    _drawHeatmap(canvas, center, radius);

    if (showGrid) {
      _drawGrid(canvas, center, radius);
    }
  }

  void _drawHeatmap(Canvas canvas, Offset center, double radius) {
    if (intensities.isEmpty) return;

    final paint = Paint();
    final numSegments = ranges.length;

    for (int i = 0; i < numSegments; i++) {
      if (i >= ranges.length) break;

      final angle = angleMin + (i * angleIncrement);
      final range = ranges[i];
      final intensity = i < intensities.length ? intensities[i] : 0.0;

      if (range <= 0 || range > rangeMax) continue;

      // Create gradient for this segment
      final normalizedRange = range / rangeMax;
      final segmentRadius = radius * normalizedRange;

      // Calculate segment angles
      final startAngle = angle - angleIncrement / 2 - math.pi / 2;
      final endAngle = angle + angleIncrement / 2 - math.pi / 2;

      // Create path for segment
      final path = Path();
      path.moveTo(center.dx, center.dy);
      path.arcTo(
        Rect.fromCircle(center: center, radius: segmentRadius),
        startAngle,
        endAngle - startAngle,
        false,
      );
      path.close();

      // Set color based on intensity
      paint.color = _getHeatmapColor(intensity).withValues(alpha: 0.7);
      canvas.drawPath(path, paint);
    }
  }

  void _drawGrid(Canvas canvas, Offset center, double radius) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    // Draw concentric circles
    for (int i = 1; i <= 4; i++) {
      final circleRadius = radius * i / 4;
      canvas.drawCircle(center, circleRadius, gridPaint);
    }
  }

  Color _getHeatmapColor(double intensity) {
    final normalized = intensity.clamp(0.0, 1.0);

    if (normalized < 0.25) {
      return Color.lerp(Colors.purple, Colors.blue, normalized * 4)!;
    } else if (normalized < 0.5) {
      return Color.lerp(Colors.blue, Colors.green, (normalized - 0.25) * 4)!;
    } else if (normalized < 0.75) {
      return Color.lerp(Colors.green, Colors.yellow, (normalized - 0.5) * 4)!;
    } else {
      return Color.lerp(Colors.yellow, Colors.red, (normalized - 0.75) * 4)!;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class LidarBirdEyePainter extends CustomPainter {
  final List<double> ranges;
  final List<double> intensities;
  final double angleMin;
  final double angleMax;
  final double angleIncrement;
  final double rangeMax;
  final double zoomLevel;
  final Offset panOffset;

  LidarBirdEyePainter({
    required this.ranges,
    required this.intensities,
    required this.angleMin,
    required this.angleMax,
    required this.angleIncrement,
    required this.rangeMax,
    required this.zoomLevel,
    required this.panOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2) + panOffset;
    final scale =
        (math.min(size.width, size.height) / (rangeMax * 2)) * zoomLevel;

    // Draw coordinate system
    _drawCoordinateSystem(canvas, center, scale);

    // Draw LiDAR points as obstacles
    _drawObstacles(canvas, center, scale);

    // Draw vehicle
    _drawVehicle(canvas, center, scale);

    // Draw field of view
    _drawFieldOfView(canvas, center, scale);
  }

  void _drawCoordinateSystem(Canvas canvas, Offset center, double scale) {
    final axisPaint = Paint()
      ..color = Colors.grey[600]!
      ..strokeWidth = 1;

    // Draw X axis
    canvas.drawLine(
      Offset(center.dx - rangeMax * scale, center.dy),
      Offset(center.dx + rangeMax * scale, center.dy),
      axisPaint,
    );

    // Draw Y axis
    canvas.drawLine(
      Offset(center.dx, center.dy - rangeMax * scale),
      Offset(center.dx, center.dy + rangeMax * scale),
      axisPaint,
    );

    // Draw grid
    final gridPaint = Paint()
      ..color = Colors.grey[700]!.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;

    for (double i = -rangeMax; i <= rangeMax; i += 5) {
      if (i == 0) continue;

      // Vertical lines
      canvas.drawLine(
        Offset(center.dx + i * scale, center.dy - rangeMax * scale),
        Offset(center.dx + i * scale, center.dy + rangeMax * scale),
        gridPaint,
      );

      // Horizontal lines
      canvas.drawLine(
        Offset(center.dx - rangeMax * scale, center.dy + i * scale),
        Offset(center.dx + rangeMax * scale, center.dy + i * scale),
        gridPaint,
      );
    }
  }

  void _drawObstacles(Canvas canvas, Offset center, double scale) {
    final obstaclePaint = Paint();

    for (int i = 0; i < ranges.length; i++) {
      final angle = angleMin + (i * angleIncrement);
      final range = ranges[i];

      if (range <= 0 || range > rangeMax) continue;

      // Convert to Cartesian coordinates (bird's eye view)
      final x = range * math.cos(angle) * scale;
      final y =
          -range * math.sin(angle) * scale; // Negative for screen coordinates

      final obstaclePosition = Offset(center.dx + x, center.dy + y);

      // Color based on distance or intensity
      Color color = Colors.red;
      if (i < intensities.length) {
        color = _getObstacleColor(intensities[i]);
      } else {
        final distanceRatio = range / rangeMax;
        color = Color.lerp(Colors.red, Colors.orange, distanceRatio)!;
      }

      obstaclePaint.color = color;
      canvas.drawCircle(obstaclePosition, 3, obstaclePaint);
    }
  }

  void _drawVehicle(Canvas canvas, Offset center, double scale) {
    final vehiclePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    // Draw vehicle as rectangle
    final vehicleRect = Rect.fromCenter(
      center: center,
      width: 4 * scale, // 4 meters wide
      height: 2 * scale, // 2 meters long
    );

    canvas.drawRect(vehicleRect, vehiclePaint);

    // Draw vehicle outline
    final outlinePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(vehicleRect, outlinePaint);

    // Draw direction indicator (front of vehicle)
    final directionPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3;

    canvas.drawLine(
      Offset(center.dx, center.dy - scale),
      Offset(center.dx, center.dy - 1.5 * scale),
      directionPaint,
    );
  }

  void _drawFieldOfView(Canvas canvas, Offset center, double scale) {
    final fovPaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(center.dx, center.dy);

    // Draw field of view arc
    final fovRadius = rangeMax * scale;
    path.arcTo(
      Rect.fromCircle(center: center, radius: fovRadius),
      angleMin - math.pi / 2,
      angleMax - angleMin,
      false,
    );

    path.close();
    canvas.drawPath(path, fovPaint);

    // Draw FOV outline
    final fovOutlinePaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw FOV boundary lines
    final leftBoundary = Offset(
      center.dx + fovRadius * math.cos(angleMin - math.pi / 2),
      center.dy + fovRadius * math.sin(angleMin - math.pi / 2),
    );

    final rightBoundary = Offset(
      center.dx + fovRadius * math.cos(angleMax - math.pi / 2),
      center.dy + fovRadius * math.sin(angleMax - math.pi / 2),
    );

    canvas.drawLine(center, leftBoundary, fovOutlinePaint);
    canvas.drawLine(center, rightBoundary, fovOutlinePaint);
  }

  Color _getObstacleColor(double intensity) {
    final normalized = intensity.clamp(0.0, 1.0);
    if (normalized > 0.8) return Colors.red;
    if (normalized > 0.6) return Colors.orange;
    if (normalized > 0.4) return Colors.yellow;
    return Colors.green;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
