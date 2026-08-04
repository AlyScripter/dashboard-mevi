import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

/// Service untuk menyediakan data rute/path untuk komponen UI
class RouteDataService extends ChangeNotifier {
  static final RouteDataService _instance = RouteDataService._internal();
  factory RouteDataService() => _instance;
  RouteDataService._internal();

  // Data rute saat ini
  List<LatLng> _routePoints = [];
  LatLng? _currentPosition;
  LatLng? _destinationPosition;
  LatLng? _nextWaypoint;
  bool _isNavigationActive = false;

  // Getter untuk data rute
  List<LatLng> get routePoints => List.unmodifiable(_routePoints);
  LatLng? get currentPosition => _currentPosition;
  LatLng? get destinationPosition => _destinationPosition;
  LatLng? get nextWaypoint => _nextWaypoint;
  bool get isNavigationActive => _isNavigationActive;

  /// Update rute yang sedang aktif
  void updateRoute({
    required List<LatLng> routePoints,
    LatLng? currentPosition,
    LatLng? destinationPosition,
  }) {
    _routePoints = List.from(routePoints);
    _currentPosition = currentPosition;
    _destinationPosition = destinationPosition;
    _isNavigationActive = routePoints.isNotEmpty;

    // Update next waypoint (waypoint terdekat di depan current position)
    _updateNextWaypoint();

    notifyListeners();
  }

  /// Update posisi saat ini
  void updateCurrentPosition(LatLng position) {
    _currentPosition = position;
    _updateNextWaypoint();
    notifyListeners();
  }

  /// Update next waypoint berdasarkan posisi saat ini
  void _updateNextWaypoint() {
    if (_currentPosition == null || _routePoints.isEmpty) {
      _nextWaypoint = null;
      return;
    }

    // Cari waypoint terdekat yang masih di depan
    double minDistance = double.infinity;
    LatLng? closestWaypoint;

    for (final point in _routePoints) {
      final distance = _calculateDistance(_currentPosition!, point);
      if (distance < minDistance && distance > 0.01) {
        // Minimal 10m di depan
        minDistance = distance;
        closestWaypoint = point;
      }
    }

    _nextWaypoint = closestWaypoint;
  }

  /// Clear data rute
  void clearRoute() {
    _routePoints.clear();
    _currentPosition = null;
    _destinationPosition = null;
    _nextWaypoint = null;
    _isNavigationActive = false;
    notifyListeners();
  }

  /// Hitung jarak antara dua titik menggunakan formula haversine
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // km
    final double dLat = _degreesToRadians(point2.latitude - point1.latitude);
    final double dLng = _degreesToRadians(point2.longitude - point1.longitude);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(point1.latitude)) *
            math.cos(_degreesToRadians(point2.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final double c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Method untuk mendapatkan sample route data untuk testing
  void loadSampleRoute() {
    final sampleRoute = [
      LatLng(-6.8815, 107.6115),
      LatLng(-6.8820, 107.6117),
      LatLng(-6.8825, 107.6120),
      LatLng(-6.8830, 107.6123),
      LatLng(-6.8835, 107.6126),
      LatLng(-6.8840, 107.6129),
    ];

    updateRoute(
      routePoints: sampleRoute,
      currentPosition: sampleRoute.first,
      destinationPosition: sampleRoute.last,
    );
  }
}
