import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:dashboardmevi/services/ros_service.dart';

/// Front bird's-eye-view (BEV) widget, styled after adaptive-cruise-control
/// clusters (Tesla/BYD-style) but honest about MEVI's actual sensor
/// coverage: a single forward-facing 2D LIDAR (measured ~60 deg FOV from
/// the recorded rosbag) plus one ultrasonic. There is currently no
/// side/rear sensor, so this widget only ever draws the front arc.
///
/// Unlike the first version, this one does NOT wrap itself in a glass
/// card — it paints directly over the panel background so it reads as
/// part of the panel (open, spacious) rather than a boxed-in widget.
///
/// Data sources (all pre-existing RosService streams — nothing new is
/// published on the ROS side, so this does not touch the data flow):
///  - [RosService.lidarStream]            raw per-angle ranges
///  - [RosService.obstacleDistanceStream] nearest obstacle distance
///  - [RosService.obstaclePositionStream] 'left' | 'right' | 'front' | 'none'
///  - [RosService.steeringAngleStream]    bends the road so the driver can
///    see at a glance whether the controller is steering straight, or
///    into a left/right turn.
///
/// [notificationText] / [notificationIcon] are optional and unused for now
/// — reserved for a future "obstacle ahead" / "turning right" banner.
class FrontBevWidget extends StatefulWidget {
  final String? notificationText;
  final IconData? notificationIcon;
  final Color notificationColor;

  const FrontBevWidget({
    super.key,
    this.notificationText,
    this.notificationIcon,
    this.notificationColor = Colors.amber,
  });

  @override
  State<FrontBevWidget> createState() => _FrontBevWidgetState();
}

class _FrontBevWidgetState extends State<FrontBevWidget>
    with SingleTickerProviderStateMixin {
  final RosService _ros = RosService();

  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.notificationText != null) ...[
              _NotificationPill(
                text: widget.notificationText!,
                icon: widget.notificationIcon ?? Icons.info_outline,
                color: widget.notificationColor,
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: StreamBuilder<List<double>>(
                stream: _ros.lidarStream,
                builder: (context, lidarSnap) {
                  final ranges = lidarSnap.data ?? const <double>[];
                  return StreamBuilder<double>(
                    stream: _ros.obstacleDistanceStream,
                    builder: (context, distSnap) {
                      final obstacleDistance = distSnap.data ?? double.infinity;
                      return StreamBuilder<String>(
                        stream: _ros.obstaclePositionStream,
                        builder: (context, posSnap) {
                          final obstaclePosition = posSnap.data ?? 'none';
                          return StreamBuilder<double>(
                            stream: _ros.steeringAngleStream,
                            builder: (context, steerSnap) {
                              final steeringDeg = (steerSnap.data ?? 0.0).clamp(
                                -35.0,
                                35.0,
                              );
                              return AnimatedBuilder(
                                animation: _pulse,
                                builder: (_, __) {
                                  return CustomPaint(
                                    size: Size(w, h),
                                    painter: _FrontBevPainter(
                                      lidarRanges: ranges,
                                      obstacleDistance: obstacleDistance,
                                      obstaclePosition: obstaclePosition,
                                      steeringDeg: steeringDeg,
                                      pulseScale: _pulse.value,
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NotificationPill extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;

  const _NotificationPill({
    required this.text,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a soft blue "light beam" glow (not a hard-edged road graphic)
/// plus clearer "object" markers for detected LIDAR hits, bending with
/// live steering angle — matched to the reference cluster's minimal
/// glow-only style (no grid, no border, barely-there centerline). The
/// car itself (the real 3D model, see VehicleStageWidget) is drawn by
/// this widget's parent, on top of this painted layer.
///
/// Angle convention matches the original Lidar2DRadarWidget so no ROS-side
/// data or parsing changes: 240 deg raw FOV, -120 deg start, displayed
/// window is -40..+40 deg (the physically populated front cone).
class _FrontBevPainter extends CustomPainter {
  final List<double> lidarRanges;
  final double obstacleDistance;
  final String obstaclePosition;
  final double steeringDeg;
  final double pulseScale;

  static const double lidarFovDegrees = 240.0;
  static const double lidarMinAngle = -120.0;
  static const double lidarMaxRange = 5.6;
  static const double displayFovMin = -40.0;
  static const double displayFovMax = 40.0;
  static const double maxRangeMeters = 6.0;

  const _FrontBevPainter({
    required this.lidarRanges,
    required this.obstacleDistance,
    required this.obstaclePosition,
    required this.steeringDeg,
    required this.pulseScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Smaller footprint than before, and pulled up off the very bottom —
    // matches the reference, where the glow sits centered in the panel
    // with visible black margin on all sides, instead of a road filling
    // the whole widget edge-to-edge.
    final origin = Offset(size.width / 2, size.height * 0.86);
    final forwardSpan = size.height * 0.62;
    final halfWidth = size.width * 0.30;
    final bend = (steeringDeg / 35.0) * halfWidth * 0.85;

    _drawRoad(canvas, origin, forwardSpan, halfWidth, bend);
    _drawLidarObjects(canvas, origin, forwardSpan, halfWidth);

    final hit = _resolveDetectionHit();
    if (hit != null && hit.distance.isFinite) {
      _drawObstacleHighlight(canvas, size, origin, forwardSpan, halfWidth, hit);
    }
  }

  /// A soft blue beam of light (not a hard-edged road shape) — bends with
  /// the live steering angle. Matches the reference cluster: a blurred
  /// gradient glow with no crisp border, no grid lines, and only a very
  /// faint centerline, so it reads as ambient light rising off the car
  /// rather than a drawn lane/road graphic.
  void _drawRoad(
    Canvas canvas,
    Offset origin,
    double forwardSpan,
    double halfWidth,
    double bend,
  ) {
    final roadWidthNear = halfWidth * 0.85;
    final roadWidthFar = halfWidth * 0.20;
    final topY = origin.dy - forwardSpan;
    final midY = origin.dy - forwardSpan * 0.55;

    final nearLeft = Offset(origin.dx - roadWidthNear, origin.dy);
    final nearRight = Offset(origin.dx + roadWidthNear, origin.dy);
    final farLeft = Offset(origin.dx - roadWidthFar + bend, topY);
    final farRight = Offset(origin.dx + roadWidthFar + bend, topY);
    final midLeft = Offset(
      origin.dx - (roadWidthNear + roadWidthFar) / 2 + bend * 0.5,
      midY,
    );
    final midRight = Offset(
      origin.dx + (roadWidthNear + roadWidthFar) / 2 + bend * 0.5,
      midY,
    );

    final roadPath = Path()
      ..moveTo(nearLeft.dx, nearLeft.dy)
      ..quadraticBezierTo(midLeft.dx, midLeft.dy, farLeft.dx, farLeft.dy)
      ..lineTo(farRight.dx, farRight.dy)
      ..quadraticBezierTo(midRight.dx, midRight.dy, nearRight.dx, nearRight.dy)
      ..close();

    // Wide, heavily blurred glow underneath — this is what gives the
    // "light" look instead of a drawn shape with visible edges.
    final outerGlowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF42A5F5).withValues(alpha: 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawPath(roadPath, outerGlowPaint);

    // Slightly tighter, brighter core glow on top of the wide blur.
    final innerGlowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF64B5F6).withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawPath(roadPath, innerGlowPaint);

    // Soft gradient fill, brighter near the car and fading toward the
    // horizon — no stroke/border drawn on top, unlike the previous
    // version, so there is no hard edge line.
    final roadPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.linear(
        Offset(origin.dx, origin.dy),
        Offset(origin.dx, topY),
        [
          const Color(0xFF64B5F6).withValues(alpha: 0.30),
          const Color(0xFF64B5F6).withValues(alpha: 0.0),
        ],
      );
    canvas.drawPath(roadPath, roadPaint);

    // Very faint centerline — just enough to read the steering bend at a
    // glance, without looking like a drawn lane marking (reference has
    // none at all).
    final centerNear = origin;
    final centerFar = Offset(origin.dx + bend, topY);
    final centerMid = Offset(origin.dx + bend * 0.5, midY);
    final centerPath = Path()
      ..moveTo(centerNear.dx, centerNear.dy)
      ..quadraticBezierTo(
        centerMid.dx,
        centerMid.dy,
        centerFar.dx,
        centerFar.dy,
      );

    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.14);
    _drawDashedPath(
      canvas,
      centerPath,
      dashPaint,
      dashLength: 8,
      gapLength: 10,
    );
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dashLength,
    required double gapLength,
  }) {
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final len = draw ? dashLength : gapLength;
        final next = math.min(distance + len, metric.length);
        if (draw) {
          canvas.drawPath(metric.extractPath(distance, next), paint);
        }
        distance = next;
        draw = !draw;
      }
    }
  }

  void _drawLidarObjects(
    Canvas canvas,
    Offset origin,
    double forwardSpan,
    double halfWidth,
  ) {
    if (lidarRanges.isEmpty) return;
    final len = lidarRanges.length;
    final angleIncDeg = lidarFovDegrees / len;
    final startIndex = ((displayFovMin - lidarMinAngle) / angleIncDeg).round();
    final endIndex = ((displayFovMax - lidarMinAngle) / angleIncDeg).round();

    // Group nearby raw points into small "object" blobs instead of a
    // scatter of single-pixel dots, so detections actually read as
    // objects sitting on the road.
    for (int i = startIndex; i <= endIndex && i < len; i++) {
      if (i < 0) continue;
      var d = lidarRanges[i];
      if (!d.isFinite || d <= 0.02 || d > lidarMaxRange || d.isNaN) continue;
      d = d.clamp(0.0, maxRangeMeters);

      final lidarAngleDeg = lidarMinAngle + i * angleIncDeg;
      final rad = _degToRad(lidarAngleDeg);
      final fwd = d * math.cos(rad);
      final lat = d * math.sin(rad);

      final px = origin.dx + (lat / maxRangeMeters) * halfWidth * 2;
      final py = origin.dy - (fwd / maxRangeMeters) * forwardSpan;

      // Blob radius shrinks with distance (perspective feel).
      final depthFactor = 1.0 - (d / maxRangeMeters) * 0.55;
      final radius = 3.6 * depthFactor;
      final color = _colorForDistance(d);

      final shadowPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.black.withValues(alpha: 0.10);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(px, py + radius * 0.6),
          width: radius * 2.4,
          height: radius * 1.1,
        ),
        shadowPaint,
      );

      final blobPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: 0.9);
      canvas.drawCircle(Offset(px, py), radius, blobPaint);
    }
  }

  _DetectionHit? _resolveDetectionHit() {
    if (obstaclePosition != 'none' && obstacleDistance.isFinite) {
      final angle = switch (obstaclePosition) {
        'left' => -25.0,
        'right' => 25.0,
        'front' => 0.0,
        _ => 0.0,
      };
      return _DetectionHit(
        distance: obstacleDistance.clamp(0.0, maxRangeMeters),
        lidarAngle: angle,
      );
    }
    return null;
  }

  void _drawObstacleHighlight(
    Canvas canvas,
    Size size,
    Offset origin,
    double forwardSpan,
    double halfWidth,
    _DetectionHit hit,
  ) {
    final d = hit.distance.clamp(0.0, maxRangeMeters);
    final rad = _degToRad(hit.lidarAngle);
    final fwd = d * math.cos(rad);
    final lat = d * math.sin(rad);
    final px = origin.dx + (lat / maxRangeMeters) * halfWidth * 2;
    final py = origin.dy - (fwd / maxRangeMeters) * forwardSpan;
    final pos = Offset(px, py);
    final color = _colorForDistance(d);

    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.22 * pulseScale)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(pos, 15 * pulseScale, glowPaint);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    canvas.drawCircle(pos, 8.0, ringPaint);

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    canvas.drawCircle(pos, 4.5, dotPaint);

    final tp = TextPainter(
      text: TextSpan(
        text: '${d.toStringAsFixed(1)} m',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final labelY = (pos.dy - 24).clamp(4.0, size.height - tp.height - 4.0);
    final labelRect = Rect.fromLTWH(
      pos.dx - tp.width / 2 - 5,
      labelY,
      tp.width + 10,
      tp.height + 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(6)),
      Paint()..color = const Color(0xFF11151C).withValues(alpha: 0.88),
    );
    tp.paint(canvas, Offset(labelRect.left + 5, labelRect.top + 3));
  }

  Color _colorForDistance(double d) {
    if (d < 1.0) return const Color(0xFFE53935);
    if (d < 2.0) return const Color(0xFFFB8C00);
    return const Color(0xFF43A047);
  }

  double _degToRad(double degrees) => degrees * math.pi / 180.0;

  @override
  bool shouldRepaint(covariant _FrontBevPainter oldDelegate) {
    return oldDelegate.obstacleDistance != obstacleDistance ||
        oldDelegate.obstaclePosition != obstaclePosition ||
        oldDelegate.steeringDeg != steeringDeg ||
        oldDelegate.pulseScale != pulseScale ||
        oldDelegate.lidarRanges.length != lidarRanges.length;
  }
}

class _DetectionHit {
  final double distance;
  final double lidarAngle;
  const _DetectionHit({required this.distance, required this.lidarAngle});
}
