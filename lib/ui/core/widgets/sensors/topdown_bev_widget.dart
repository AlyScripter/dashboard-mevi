import 'dart:math' as math;
import 'package:flutter/material.dart';
// `hide Path`: latlong2 exports its own `Path<T extends LatLng>` class
// (used for GPS path smoothing) which otherwise collides with
// `dart:ui`'s `Path` — the one actually needed below for drawing the
// road polylines — causing `argument_type_not_assignable` /
// `undefined_method` errors on `Path()`, `.moveTo()`, `.lineTo()`.
import 'package:latlong2/latlong.dart' hide Path;
import 'package:dashboardmevi/ui/pages/navigation/utils/navigation_utils.dart';
import 'pedestrian_marker.dart';

/// Full top-down (bird's-eye) 2D visualization of MEVI on the road.
///
/// REVISI 6 — matched against the reference BEV mock-up (gambar 1):
///  - The single dividing line down the middle of the lane is now a
///    dashed centerline (previously the lane only had its two solid
///    outer boundary lines, no center marking at all).
///  - The detection zone around MEVI is now a layered "radar" look —
///    an outer soft glow plus TWO concentric rings (faint outer / more
///    solid inner) instead of one single thin ring — closer to the
///    multi-ring sonar-style circle in the reference image.
///  - Nearby detections (`nearbyVehicles`) are drawn with a thin blue
///    detection box around each sprite, same as the boxed car/pedestrian
///    in the reference. A `DetectedObjectKind` now distinguishes cars
///    (rendered with `assets/images/car.png`, unchanged) from
///    pedestrians (rendered with the new vector [PedestrianMarker] —
///    see that file's doc comment for why a vector marker is used
///    instead of a raster asset).
///  - Light/dark colors re-tuned: dashed centerline, both detection
///    rings, and detection boxes all pick a light-mode-safe color the
///    same way the existing lane boundary lines already did, so the
///    scene stays readable on both the black (dark) and white (light)
///    page background.
///
/// REVISI 5 (kept): the road follows the real Maps route — this page
/// reads the shared `NavigationCubit` (promoted to an app-wide ancestor
/// in `LayoutDashboard`, same instance the Maps page itself uses) for
/// `routePoints` + `current` position, and the same IMU-yaw-with-fallback
/// heading source already used by the Maps page's heading HUD / car
/// marker. With no active route yet, this falls back to its static
/// straight single-lane road on its own — no extra handling needed.
///
/// Renders, back to front:
///   1. The single-lane road — curved route-following boundary lines
///      when live nav data is available, straight parallel lines
///      otherwise — plus a dashed centerline down the middle.
///   2. A layered blue "detection zone": radial glow + two concentric
///      rings hugging close around MEVI.
///   3. Nearby traffic / pedestrians, each inside a thin detection box —
///      cars use `assets/images/car.png`, pedestrians use the vector
///      [PedestrianMarker]. Empty by default; pass real detections in
///      once a live surrounding-object detection source exists.
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
    final isLight = Theme.of(context).brightness == Brightness.light;

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
        // Pedestrians read as a narrower, slightly shorter box than
        // the nearby-car sprite in the reference image.
        final pedestrianHeight = otherCarHeight * 0.82;
        final pedestrianWidth = pedestrianHeight * 0.42;

        final roadGeometry = _buildRoadGeometry(center, laneHalfWidthPx);

        return Stack(
          alignment: Alignment.center,
          children: [
            // 1 + 2. Single-lane road (curved when live nav data is
            // available) with dashed centerline, and the layered blue
            // detection-zone glow/rings.
            Positioned.fill(
              child: CustomPaint(
                painter: _TopDownRoadPainter(
                  laneHalfWidthPx: laneHalfWidthPx,
                  carHeight: carHeight,
                  road: roadGeometry,
                  isLight: isLight,
                ),
              ),
            ),

            // 3. Nearby detections, drawn under MEVI — each boxed like
            // the reference's blue detection outline around cars /
            // pedestrians.
            for (final v in nearbyVehicles)
              _buildDetectionSprite(
                v: v,
                center: center,
                size: size,
                carWidth: otherCarWidth,
                carHeight: otherCarHeight,
                pedestrianWidth: pedestrianWidth,
                pedestrianHeight: pedestrianHeight,
                isLight: isLight,
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

  /// Builds one nearby detection (car or pedestrian), boxed in a thin
  /// blue detection outline, positioned via [NearbyVehicle.dx]/[dy]
  /// exactly like before.
  Widget _buildDetectionSprite({
    required NearbyVehicle v,
    required Offset center,
    required Size size,
    required double carWidth,
    required double carHeight,
    required double pedestrianWidth,
    required double pedestrianHeight,
    required bool isLight,
  }) {
    final isPedestrian = v.kind == DetectedObjectKind.pedestrian;
    final boxWidth = isPedestrian ? pedestrianWidth : carWidth;
    final boxHeight = isPedestrian ? pedestrianHeight : carHeight;
    // A little breathing room between the sprite and its detection box,
    // matching the reference's boxes (they hug the sprite, not the
    // pixel-tight bounds).
    const boxPadding = 6.0;

    final boxColor = isLight
        ? const Color(0xFF1976D2)
        : const Color(0xFF29B6F6);

    return Positioned(
      left: center.dx + v.dx * size.width / 2 - boxWidth / 2 - boxPadding,
      top: center.dy + v.dy * size.height / 2 - boxHeight / 2 - boxPadding,
      child: Container(
        width: boxWidth + boxPadding * 2,
        height: boxHeight + boxPadding * 2,
        padding: const EdgeInsets.all(boxPadding),
        decoration: BoxDecoration(
          border: Border.all(
            color: boxColor.withValues(alpha: isLight ? 0.85 : 0.9),
            width: 1.4,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: isPedestrian
            ? PedestrianMarker(width: boxWidth, height: boxHeight)
            : Image.asset(
                'assets/images/car.png',
                width: boxWidth,
                height: boxHeight,
                fit: BoxFit.contain,
              ),
      ),
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

    return _RoadGeometry(left: left, right: right, center: centerlinePx);
  }
}

/// What kind of nearby object [NearbyVehicle] represents — controls
/// which sprite is drawn inside its detection box.
enum DetectedObjectKind { car, pedestrian }

/// Relative position of a nearby detected object, expressed as a
/// fraction (-1..1) of the widget's half-width/half-height rather than
/// raw pixels, so placement scales automatically with the widget's
/// size. (0, 0) is MEVI; negative `dy` is ahead of MEVI, negative `dx`
/// is to MEVI's left.
class NearbyVehicle {
  final double dx;
  final double dy;

  /// Defaults to [DetectedObjectKind.car] so existing call sites that
  /// only pass `dx`/`dy` keep rendering exactly as before.
  final DetectedObjectKind kind;

  const NearbyVehicle({
    required this.dx,
    required this.dy,
    this.kind = DetectedObjectKind.car,
  });
}

/// The single lane's two boundary lines plus its centerline, already
/// projected into local pixel space (centered on MEVI, heading-up) by
/// [TopDownBevWidget._buildRoadGeometry].
class _RoadGeometry {
  final List<Offset> left;
  final List<Offset> right;
  final List<Offset> center;
  const _RoadGeometry({
    required this.left,
    required this.right,
    required this.center,
  });
}

/// Paints the single-lane road (curved route or straight fallback),
/// its dashed centerline, and the layered blue circular detection zone
/// hugging MEVI.
class _TopDownRoadPainter extends CustomPainter {
  final double laneHalfWidthPx;
  final double carHeight;
  final _RoadGeometry? road;
  final bool isLight;

  const _TopDownRoadPainter({
    required this.laneHalfWidthPx,
    required this.carHeight,
    required this.road,
    required this.isLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);

    final center = Offset(size.width / 2, size.height / 2);
    // Ring sized to hug closely around MEVI rather than the whole scene.
    final ringRadius = carHeight / 2 * 1.25;

    // --- Layered "radar" detection zone -----------------------------
    // Soft outer glow behind the rings.
    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF2196F3).withValues(alpha: isLight ? 0.16 : 0.28),
              const Color(0xFF2196F3).withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: ringRadius * 1.35),
          );
    canvas.drawCircle(center, ringRadius * 1.35, glowPaint);

    // Outer ring — faint, sits further out, styled after the fainter
    // outer sonar ring in the reference image.
    final outerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF1E88E5).withValues(alpha: isLight ? 0.28 : 0.3);
    canvas.drawCircle(center, ringRadius * 1.18, outerRingPaint);

    // Inner ring — the main detection-range ring, styled after the
    // reference "360°" ring, hugging closest to MEVI.
    final innerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFF1E88E5).withValues(alpha: isLight ? 0.6 : 0.55);
    canvas.drawCircle(center, ringRadius, innerRingPaint);

    // --- Lane boundary lines -----------------------------------------
    // REVISI: light mode → garis batas lane pakai warna gelap (bukan
    // putih transparan) supaya tetap terlihat di atas background putih.
    final solidPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = isLight
          ? const Color(0xFF1A2331).withValues(alpha: 0.28)
          : Colors.white.withValues(alpha: 0.22)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Dashed centerline paint — same family of color as the boundary
    // lines but a little more visible, matching the reference's
    // clearly-dashed center divider.
    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = isLight
          ? const Color(0xFF1A2331).withValues(alpha: 0.35)
          : Colors.white.withValues(alpha: 0.45)
      ..strokeCap = StrokeCap.round;

    final liveRoad = road;
    if (liveRoad != null) {
      // Route-following road: draw each boundary as a connected
      // polyline through the projected points — this is what actually
      // curves left/right in sync with the real map route.
      canvas.drawPath(_pathThrough(liveRoad.left), solidPaint);
      canvas.drawPath(_pathThrough(liveRoad.right), solidPaint);
      _drawDashedPolyline(canvas, liveRoad.center, dashPaint);
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
      _drawDashedLine(
        canvas,
        Offset(center.dx, 0),
        Offset(center.dx, size.height),
        dashPaint,
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

  /// Draws a dashed straight line between [start] and [end] — used for
  /// the static-fallback centerline.
  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLength = 16.0;
    const gapLength = 14.0;
    final totalLength = (end - start).distance;
    if (totalLength == 0) return;
    final direction = (end - start) / totalLength;

    var drawn = 0.0;
    while (drawn < totalLength) {
      final segStart = start + direction * drawn;
      final segEndLen = math.min(drawn + dashLength, totalLength);
      final segEnd = start + direction * segEndLen;
      canvas.drawLine(segStart, segEnd, paint);
      drawn += dashLength + gapLength;
    }
  }

  /// Draws a dashed line following a connected polyline — used for the
  /// route-following centerline so the dashes bend through curves the
  /// same way the solid boundary lines do.
  void _drawDashedPolyline(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    const dashLength = 16.0;
    const gapLength = 14.0;

    var remainingInPhase = dashLength;
    var drawing = true;

    for (var i = 0; i < points.length - 1; i++) {
      var segStart = points[i];
      final segEnd = points[i + 1];
      var segRemaining = (segEnd - segStart).distance;
      if (segRemaining == 0) continue;
      final dir = (segEnd - segStart) / segRemaining;

      while (segRemaining > 0) {
        final step = math.min(remainingInPhase, segRemaining);
        final next = segStart + dir * step;
        if (drawing) {
          canvas.drawLine(segStart, next, paint);
        }
        segStart = next;
        segRemaining -= step;
        remainingInPhase -= step;

        if (remainingInPhase <= 0) {
          drawing = !drawing;
          remainingInPhase = drawing ? dashLength : gapLength;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TopDownRoadPainter oldDelegate) => true;
}
