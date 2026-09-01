import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Full top-down (bird's-eye) 2D visualization of MEVI on the road —
/// REVISI: replaces the previous 3D car model + glow-road + raw LIDAR
/// blob rendering (`VehicleStageWidget` / `FrontBevWidget`). The LIDAR
/// point-by-point painting on every frame was too heavy, and the old
/// visual was a forward/perspective camera view rather than a true
/// bird's-eye-view — this widget is a flat, straight-down 2D scene
/// instead, styled after the reference 360°-sensor illustration.
///
/// Renders, back to front:
///   1. Parallel top-down lane lines — no perspective/convergence,
///      since this is looking straight down rather than forward.
///   2. A soft blue "detection zone": radial glow + thin ring behind
///      MEVI, matching the reference's circular sensor-range ring.
///   3. Nearby traffic using `assets/images/car.png` — for now a
///      placeholder demo list ([nearbyVehicles]'s default value) since
///      there's no live surrounding-vehicle detection source yet; pass
///      a real list in once that data exists, no other changes needed.
///   4. MEVI itself, always centered, using `assets/images/mevicar.png`
///      (the same asset already used on the Maps page) with a subtle
///      heading tilt driven by [steeringAngle].
///
/// Deliberately lightweight: everything below is either a handful of
/// `Image.asset` widgets or a single non-repainting `CustomPainter` —
/// no animation controllers, no per-frame LIDAR loop.
class TopDownBevWidget extends StatelessWidget {
  final double steeringAngle;
  final List<NearbyVehicle> nearbyVehicles;

  const TopDownBevWidget({
    super.key,
    this.steeringAngle = 0.0,
    this.nearbyVehicles = const [
      // Placeholder demo traffic — see class docs above. Swap this
      // default for a real detection list once that source exists;
      // everything else in this widget already supports it as-is.
      NearbyVehicle(dx: -0.62, dy: -0.42),
      NearbyVehicle(dx: 0.60, dy: -0.55),
      NearbyVehicle(dx: 0.58, dy: 0.32),
    ],
  });

  @override
  Widget build(BuildContext context) {
    final tilt = (steeringAngle / 35.0).clamp(-1.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final center = Offset(size.width / 2, size.height / 2);
        final carHeight = (size.height * 0.16).clamp(70.0, 130.0);
        final carWidth = carHeight * 0.52;
        final otherCarHeight = carHeight * 0.82;
        final otherCarWidth = otherCarHeight * 0.52;

        return Stack(
          alignment: Alignment.center,
          children: [
            // 1 + 2. Lanes and the blue detection-zone glow/ring.
            const Positioned.fill(
              child: CustomPaint(painter: _TopDownRoadPainter()),
            ),

            // 3. Nearby traffic, drawn under MEVI.
            for (final v in nearbyVehicles)
              Positioned(
                left: center.dx + v.dx * size.width / 2 - otherCarWidth / 2,
                top: center.dy + v.dy * size.height / 2 - otherCarHeight / 2,
                child: Image.asset(
                  'assets/images/car.png',
                  width: otherCarWidth,
                  height: otherCarHeight,
                  fit: BoxFit.contain,
                ),
              ),

            // 4. MEVI — always centered, subtle steering tilt only (no
            // translation — the road/traffic move relative to MEVI in
            // a real system, not the other way around, but since we
            // have no live world-position feed yet MEVI simply stays
            // put in the middle of the scene).
            Transform.rotate(
              angle: tilt * 0.05,
              child: Image.asset(
                'assets/images/mevicar.png',
                width: carWidth,
                height: carHeight,
                fit: BoxFit.contain,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Relative position of a nearby vehicle, expressed as a fraction
/// (-1..1) of the widget's half-width/half-height rather than raw
/// pixels, so placement scales automatically with the widget's size.
/// (0, 0) is MEVI; negative `dy` is ahead of MEVI, negative `dx` is to
/// MEVI's left.
class NearbyVehicle {
  final double dx;
  final double dy;
  const NearbyVehicle({required this.dx, required this.dy});
}

/// Paints the flat 2D lane lines and the soft blue circular detection
/// zone around MEVI. Static (never repaints) — no LIDAR points, no
/// perspective, just the bird's-eye backdrop.
class _TopDownRoadPainter extends CustomPainter {
  const _TopDownRoadPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ringRadius = math.min(size.width, size.height) * 0.42;

    // Soft outer glow behind the ring.
    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF2196F3).withValues(alpha: 0.28),
              const Color(0xFF2196F3).withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: ringRadius * 1.35),
          );
    canvas.drawCircle(center, ringRadius * 1.35, glowPaint);

    // Thin detection-range ring, styled after the reference "360°" ring.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFF64B5F6).withValues(alpha: 0.55);
    canvas.drawCircle(center, ringRadius, ringPaint);

    // Lane lines: 2 solid outer boundaries + 2 dashed inner dividers,
    // all perfectly vertical/parallel — a true top-down view has no
    // perspective convergence, unlike the old forward-camera road.
    final laneGap = size.width * 0.19;
    final xs = [
      center.dx - laneGap * 1.5,
      center.dx - laneGap * 0.5,
      center.dx + laneGap * 0.5,
      center.dx + laneGap * 1.5,
    ];

    final solidPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white.withValues(alpha: 0.22);
    canvas.drawLine(Offset(xs[0], 0), Offset(xs[0], size.height), solidPaint);
    canvas.drawLine(Offset(xs[3], 0), Offset(xs[3], size.height), solidPaint);

    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white.withValues(alpha: 0.30);
    _drawDashedLine(
      canvas,
      Offset(xs[1], 0),
      Offset(xs[1], size.height),
      dashPaint,
    );
    _drawDashedLine(
      canvas,
      Offset(xs[2], 0),
      Offset(xs[2], size.height),
      dashPaint,
    );
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLength = 16.0;
    const gapLength = 14.0;
    final totalLength = (end - start).distance;
    if (totalLength == 0) return;
    final direction = (end - start) / totalLength;
    double drawn = 0;
    while (drawn < totalLength) {
      final segEnd = math.min(drawn + dashLength, totalLength);
      canvas.drawLine(
        start + direction * drawn,
        start + direction * segEnd,
        paint,
      );
      drawn = segEnd + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant _TopDownRoadPainter oldDelegate) => false;
}
