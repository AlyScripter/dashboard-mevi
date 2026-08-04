import 'dart:convert';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

class GeoJsonRouteManager {
  List<LatLng> _lineStringPoints = [];

  Future<void> loadGeoJsonData(String geoJsonString) async {
    Map<String, dynamic> geoJson = jsonDecode(geoJsonString);
    _lineStringPoints = _collectLineStringCoordinates(geoJson);
  }

  List<LatLng> get lineStringPoints => _lineStringPoints;

  List<LatLng> _collectLineStringCoordinates(Map<String, dynamic> geoJson) {
    List<LatLng> lineStringCoordinates = [];

    for (var feature in geoJson['features']) {
      var geometry = feature['geometry'];

      if (geometry['type'] == 'LineString') {
        var coordinates = geometry['coordinates'];
        lineStringCoordinates.addAll(extractCoordinates(coordinates));
      }
    }
    return lineStringCoordinates;
  }

  List<LatLng> extractCoordinates(List<dynamic> coordinates) {
    List<LatLng> points = [];
    for (var coord in coordinates) {
      if (coord is List && coord.length == 2) {
        points.add(LatLng(coord[1], coord[0]));
      } else if (coord is List) {
        points.addAll(extractCoordinates(coord));
      }
    }
    return points;
  }

  LatLng findClosestPoint(LatLng currentPosition) {
    if (_lineStringPoints.isEmpty) {
      throw Exception("No LineString data available");
    }

    LatLng closestPoint = _lineStringPoints[0];
    double closestDistance = _calculateDistance(currentPosition, closestPoint);

    for (LatLng point in _lineStringPoints) {
      double distance = _calculateDistance(currentPosition, point);
      if (distance < closestDistance) {
        closestDistance = distance;
        closestPoint = point;
      }
    }

    return closestPoint;
  }

  bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    bool isInside = false;
    int n = polygon.length;

    for (int i = 0, j = n - 1; i < n; j = i++) {
      if ((polygon[i].longitude > point.longitude) != (polygon[j].longitude > point.longitude) &&
          (point.latitude < (polygon [j].latitude - polygon[i].latitude) * (point.longitude - polygon[i].longitude) / (polygon[j].longitude - polygon[i].longitude) + polygon[i].latitude)) {
        isInside = !isInside;
      }
    }
    return isInside;
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371;
    final double dLat = _degreesToRadians(end.latitude - start.latitude);
    final double dLng = _degreesToRadians(end.longitude - start.longitude);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(start.latitude)) *
            math.cos(_degreesToRadians(end.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }
}