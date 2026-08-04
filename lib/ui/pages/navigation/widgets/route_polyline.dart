import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

class RoutePolyline extends StatelessWidget {
  final List<LatLng> points;
  final LatLng? currentPosition;
  final Color color;
  final double strokeWidth;
  final Color traveledColor;
  final double traveledStrokeWidth;

  const RoutePolyline({
    super.key,
    required this.points,
    this.currentPosition,
    this.color = Colors.blue,
    this.strokeWidth = 4.0,
    this.traveledColor = Colors.grey,
    this.traveledStrokeWidth = 2.0,
  });

  /// Calculate distance between two LatLng points in meters
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // meters
    double lat1Rad = point1.latitude * math.pi / 180;
    double lat2Rad = point2.latitude * math.pi / 180;
    double deltaLatRad = (point2.latitude - point1.latitude) * math.pi / 180;
    double deltaLngRad = (point2.longitude - point1.longitude) * math.pi / 180;

    double a =
        math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLngRad / 2) *
            math.sin(deltaLngRad / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// Find the closest point on route to current position and split route
  (List<LatLng> traveled, List<LatLng> remaining)
  _splitRouteAtCurrentPosition() {
    if (currentPosition == null || points.length < 2) {
      return (<LatLng>[], points);
    }

    double minDistance = double.infinity;
    int closestSegmentIndex = 0;
    LatLng? closestPointOnRoute;

    // Find the closest segment and point on the route
    for (int i = 0; i < points.length - 1; i++) {
      final segmentStart = points[i];
      final segmentEnd = points[i + 1];

      // Calculate closest point on this segment to current position
      final closestOnSegment = _getClosestPointOnSegment(
        currentPosition!,
        segmentStart,
        segmentEnd,
      );

      final distance = _calculateDistance(currentPosition!, closestOnSegment);

      if (distance < minDistance) {
        minDistance = distance;
        closestSegmentIndex = i;
        closestPointOnRoute = closestOnSegment;
      }
    }

    // Only consider route as "traveled" if within reasonable distance (50 meters)
    if (minDistance > 50.0) {
      return (<LatLng>[], points);
    }

    // Split the route
    List<LatLng> traveled = points.sublist(0, closestSegmentIndex + 1);
    if (closestPointOnRoute != null) {
      traveled.add(closestPointOnRoute);
    }

    List<LatLng> remaining = [];
    if (closestPointOnRoute != null) {
      remaining.add(closestPointOnRoute);
    }
    remaining.addAll(points.sublist(closestSegmentIndex + 1));

    return (traveled, remaining);
  }

  /// Calculate closest point on a line segment to a given point
  LatLng _getClosestPointOnSegment(
    LatLng point,
    LatLng segmentStart,
    LatLng segmentEnd,
  ) {
    double dx = segmentEnd.longitude - segmentStart.longitude;
    double dy = segmentEnd.latitude - segmentStart.latitude;

    if (dx == 0 && dy == 0) {
      return segmentStart;
    }

    double t =
        ((point.longitude - segmentStart.longitude) * dx +
            (point.latitude - segmentStart.latitude) * dy) /
        (dx * dx + dy * dy);

    t = math.max(0, math.min(1, t));

    return LatLng(
      segmentStart.latitude + t * dy,
      segmentStart.longitude + t * dx,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final (traveledPoints, remainingPoints) = _splitRouteAtCurrentPosition();

    return PolylineLayer(
      polylines: [
        // Traveled route (grey/dimmed)
        if (traveledPoints.length >= 2)
          Polyline(
            points: traveledPoints,
            strokeWidth: traveledStrokeWidth,
            color: traveledColor.withValues(alpha: 0.6),
          ),
        // Remaining route (normal color)
        if (remainingPoints.length >= 2)
          Polyline(
            points: remainingPoints,
            strokeWidth: strokeWidth,
            color: color,
          ),
      ],
    );
  }
}
