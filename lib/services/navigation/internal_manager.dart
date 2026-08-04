import 'dart:convert';
import 'dart:math' as math; // Importing the dart:math library

import 'package:latlong2/latlong.dart';

class InternalRouteManager {
  final List<LatLng> _internalRoad = [];

  // Load GeoJSON data and populate internal roads
  Future<void> loadGeoJsonData(String geoJsonString) async {
    try {
      final geoJson = jsonDecode(geoJsonString);
      final lineStringFeatures = geoJson['features']
          .where((feature) => feature['geometry']['type'] == 'LineString');

      lineStringFeatures.forEach((feature) {
        final coordinates = feature['geometry']['coordinates'];
        coordinates.forEach((coordinate) {
          _internalRoad.add(LatLng(coordinate[1], coordinate[0]));
        });
      });
    } catch (e) {
      print('Error loading GeoJSON data: $e');
    }
  }

  List<LatLng> getInternalRoute() {
    return List.unmodifiable(_internalRoad);
  }

  bool isPointOnInternalRoad(LatLng point) {
    for (var coord in _internalRoad) {
      if (_calculateDistance(point, coord) < 0.0001) {
        return true;
      }
    }
    return false;
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