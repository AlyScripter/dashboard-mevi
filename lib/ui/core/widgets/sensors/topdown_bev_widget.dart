import 'dart:math' as math;
import 'package:flutter/material.dart';
// `hide Path`: latlong2 exports its own `Path<T extends LatLng>` class
// (used for GPS path smoothing) which otherwise collides with
// `dart:ui`'s `Path` — the one actually needed below for drawing the
// road polylines — causing `argument_type_not_assignable` /
// `undefined_method` errors on `Path()`, `.moveTo()`, `.lineTo()`.
import 'package:latlong2/latlong.dart' hide Path;
import 'package:dashboardmevi/ui/pages/navigation/utils/navigation_utils.dart';

/// Full top-down (bird's-eye) 2D visualization of MEVI on the road.
///
/// REVISI 3: the road is no longer a fixed straight lane — when a live
/// navigation route + GPS position are available (passed in from the
/// Maps page's `NavigationCubit`, now shared app-wide — see
/// `LayoutDashboard`), the single-lane boundary lines actually FOLLOW
/// the real route geometry: a left turn on the map draws as a left
/// turn here, a right turn as a right turn, matching the Maps page 1:1.
/// MEVI itself always stays centered and pointing "up" — the standard
/// "heading-up" convention every turn-by-turn nav view uses: it's the
/// road that sweeps/curves underneath the car as the vehicle's heading
/// and position change, not the other way around.
///
/// If no route/position is available yet (e.g. destination not set),
/// this falls back to the previous static straight single-lane road so
/// the page never looks broken while waiting for navigation data.
///
/// Renders, back to front:
///   1. The single-lane road — curved route-following boundary lines
///      when live nav data is available, straight parallel lines
///      otherwise.
///   2. A soft blue "detection zone": radial glow + thin ring hugging
///      close around MEVI.
///   3. Nearby traffic using `assets/images/car.png` — disabled for
///      now ([nearbyVehicles] defaults to an empty list). Pass a real
///      list in once a live surrounding-vehicle detection source
///      exists; the rendering code below already supports it as-is.
///   4. MEVI itself, always centered, using `assets/images/mevicar.png`.
class TopDownBevWidget extends StatelessWidget {
  final double steeringAngle;
  final List<NearbyVehicle> nearbyVehicles;

  /// Live route geometry, in the same point order as the Maps page
  /// (start → destination) — pass `NavigationState.routePoints` here.
  /// Leave empty (the default) to fall back to the static straight
  /// road.
  final List<LatLng> routePoints;

  /// Live vehicle position — pass `NavigationState.current` here.
  /// Required together with [routePoints] to draw the route-following
  /// road; leave null to fall back to the static straight road.
  final LatLng? currentPosition;

  /// Live compass heading in degrees (0 = north, clockwise) — same
  /// source already used by the Maps page's heading HUD / car marker
  /// (IMU yaw, falling back to `NavigationState.fallbackHeadingDeg`).
  final double headingDeg;

  const TopDownBevWidget({
    super.key,
    this.steeringAngle = 0.0,
    // Other traffic hidden for now — see class docs above. Pass a real
    // detection list in once that data source exists; no other change
    // is needed for it to render again.
    this.nearbyVehicles = const [],
    this.routePoints = const [],
    this.currentPosition,
    this.headingDeg = 0.0,
  });

  /// How far ahead of / behind the vehicle the route is sampled, in
  /// meters — keeps the drawn road segment relevant to what's visible
  /// in the widget without walking the whole route every frame.
  static const double _lookAheadMeters = 45.0;
  static const double _lookBehindMeters = 10.0;

  /// Real-world half-width of the single lane, in meters — used only
  /// to scale the route geometry; the static fallback road still uses
  /// its own fixed pixel fraction so it's unaffected by this constant.
  static const double _laneHalfWidthMeters = 1.8;

  @override
  Widget build(BuildContext context) {
    final tilt = (steeringAngle / 35.0).clamp(-1.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final center = Offset(size.width / 2, size.height / 2);

        // Single-lane half-width in pixels — must match
        // _TopDownRoadPainter's static fallback so MEVI lines up with
        // the lane, and also defines the meters→pixels scale used for
        // the route-following road (see _buildRoadGeometry).
        final laneHalfWidthPx = size.width * 0.22;
        // MEVI sized relative to the lane's width.
        final carWidth = (laneHalfWidthPx * 2 * 0.44).clamp(
          0.0,
          size.width * 0.9,
        );
        final carHeight = carWidth / 0.52;
        final otherCarHeight = (size.height * 0.16).clamp(70.0, 130.0) * 0.82;
        final otherCarWidth = otherCarHeight * 0.52;

        final roadGeometry = _buildRoadGeometry(center, laneHalfWidthPx);

        return Stack(
          alignment: Alignment.center,
          children: [
            // 1 + 2. Single-lane road (curved when live nav data is
            // available) and the blue detection-zone glow/ring.
            Positioned.fill(
              child: CustomPaint(
                painter: _TopDownRoadPainter(
                  laneHalfWidthPx: laneHalfWidthPx,
                  carHeight: carHeight,
                  road: roadGeometry,
                ),
              ),
            ),

            // 3. Nearby traffic, drawn under MEVI (empty by default — see docs).
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

            // 4. MEVI — always centered. When following a live route,
            // the road itself is already drawn in heading-up space
            // (see _buildRoadGeometry) so it's the one doing the
            // turning; MEVI just points straight up with only a
            // subtle steering-wheel tilt on top, same as the static
            // fallback case.
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

  /// Builds the route-following road geometry in local pixel space
  /// (centered on MEVI, heading-up), or returns null to fall back to
  /// the static straight road.
  _RoadGeometry? _buildRoadGeometry(Offset center, double laneHalfWidthPx) {
    final pos = currentPosition;
    if (pos == null || routePoints.length < 2) return null;

    final metersToPx = laneHalfWidthPx / _laneHalfWidthMeters;
    final headingRad = headingDeg * (math.pi / 180.0);
    final cosH = math.cos(headingRad);
    final sinH = math.sin(headingRad);

    // 1. Find the route point nearest to the vehicle's current
    // position — the road segment we draw is centered on this index.
    var nearestIndex = 0;
    var nearestDist = double.infinity;
    for (var i = 0; i < routePoints.length; i++) {
      final d = NavigationUtils.calculateDistance(pos, routePoints[i]);
      if (d < nearestDist) {
        nearestDist = d;
        nearestIndex = i;
      }
    }

    // 2. Walk backward/forward from that index, accumulating distance,
    // to build a short window of route points around the vehicle —
    // no need to project the whole route every frame.
    final windowIndices = <int>[nearestIndex];
    var accum = 0.0;
    for (var i = nearestIndex; i > 0 && accum < _lookBehindMeters; i--) {
      accum += NavigationUtils.calculateDistance(
        routePoints[i],
        routePoints[i - 1],
      );
      windowIndices.insert(0, i - 1);
    }
    accum = 0.0;
    for (
      var i = nearestIndex;
      i < routePoints.length - 1 && accum < _lookAheadMeters;
      i++
    ) {
      accum += NavigationUtils.calculateDistance(
        routePoints[i],
        routePoints[i + 1],
      );
      windowIndices.add(i + 1);
    }
    if (windowIndices.length < 2) return null;

    // 3. Project each window point into the vehicle's local frame:
    // meters east/north relative to the vehicle, rotated so the
    // vehicle's own heading points "up" (screen -y) — the standard
    // heading-up convention every turn-by-turn nav view uses. A left
    // turn on the map then bends left here too, a right turn bends
    // right, matching Maps 1:1.
    final centerlinePx = <Offset>[];
    for (final idx in windowIndices) {
      final p = routePoints[idx];
      final dLatRad = (p.latitude - pos.latitude) * (math.pi / 180.0);
      final dLonRad = (p.longitude - pos.longitude) * (math.pi / 180.0);
      const earthRadius = 6371000.0;
      final north = dLatRad * earthRadius;
      final east =
          dLonRad * earthRadius * math.cos(pos.latitude * (math.pi / 180.0));

      // Rotate world (east, north) into vehicle-local (right, forward).
      final right = east * cosH - north * sinH;
      final forward = east * sinH + north * cosH;

      centerlinePx.add(
        Offset(
          center.dx + right * metersToPx,
          center.dy - forward * metersToPx,
        ),
      );
    }

    // 4. Offset the centerline left/right by the lane half-width to
    // get the two boundary lines, using each point's local segment
    // direction so the offset lines stay parallel through curves.
    final laneHalfWidthPxLocal = _laneHalfWidthMeters * metersToPx;
    final left = <Offset>[];
    final right = <Offset>[];
    for (var i = 0; i < centerlinePx.length; i++) {
      final prev = centerlinePx[math.max(0, i - 1)];
      final next = centerlinePx[math.min(centerlinePx.length - 1, i + 1)];
      var dir = next - prev;
      if (dir.distance == 0) dir = const Offset(0, -1);
      final unit = dir / dir.distance;
      final perp = Offset(-unit.dy, unit.dx); // 90° rotation
      left.add(centerlinePx[i] - perp * laneHalfWidthPxLocal);
      right.add(centerlinePx[i] + perp * laneHalfWidthPxLocal);
    }

    return _RoadGeometry(left: left, right: right);
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

/// The single lane's two boundary lines, already projected into local
/// pixel space (centered on MEVI, heading-up) by
/// [TopDownBevWidget._buildRoadGeometry].
class _RoadGeometry {
  final List<Offset> left;
  final List<Offset> right;
  const _RoadGeometry({required this.left, required this.right});
}

/// Paints the single-lane road (curved route or straight fallback) and
/// the soft blue circular detection zone hugging MEVI.
class _TopDownRoadPainter extends CustomPainter {
  final double laneHalfWidthPx;
  final double carHeight;
  final _RoadGeometry? road;

  const _TopDownRoadPainter({
    required this.laneHalfWidthPx,
    required this.carHeight,
    required this.road,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);

    final center = Offset(size.width / 2, size.height / 2);
    // Ring sized to hug closely around MEVI rather than the whole scene.
    final ringRadius = carHeight / 2 * 1.25;

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

    final solidPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final liveRoad = road;
    if (liveRoad != null) {
      // Route-following road: draw each boundary as a connected
      // polyline through the projected points — this is what actually
      // curves left/right in sync with the real map route.
      canvas.drawPath(_pathThrough(liveRoad.left), solidPaint);
      canvas.drawPath(_pathThrough(liveRoad.right), solidPaint);
    } else {
      // Static fallback: perfectly vertical/parallel lines — used
      // whenever there's no live route/position yet, so the page
      // never looks broken while waiting for navigation data.
      final leftX = center.dx - laneHalfWidthPx;
      final rightX = center.dx + laneHalfWidthPx;
      canvas.drawLine(Offset(leftX, 0), Offset(leftX, size.height), solidPaint);
      canvas.drawLine(
        Offset(rightX, 0),
        Offset(rightX, size.height),
        solidPaint,
      );
    }
  }

  Path _pathThrough(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _TopDownRoadPainter oldDelegate) => true;
}
