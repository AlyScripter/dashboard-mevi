import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

/// Service for calculating remaining distance during navigation
class NavigationDistanceService extends ChangeNotifier {
  static final NavigationDistanceService _instance =
      NavigationDistanceService._internal();
  factory NavigationDistanceService() => _instance;
  NavigationDistanceService._internal();

  double? _remainingDistance; // in kilometers
  double? _totalDistance;
  LatLng? _currentPosition;
  LatLng? _destinationPosition;
  List<LatLng> _routePoints = [];

  // Callback to update UI
  void Function(double remainingKm)? onDistanceUpdate;

  // Getters
  double? get remainingDistance => _remainingDistance;
  double? get totalDistance => _totalDistance;
  double? get progressPercentage =>
      (_totalDistance != null && _remainingDistance != null)
      ? ((_totalDistance! - _remainingDistance!) / _totalDistance!) * 100
      : null;

  /// Update route information
  void updateRoute({
    required List<LatLng> routePoints,
    required LatLng destination,
    LatLng? currentPosition,
  }) {
    _routePoints = List.from(routePoints);
    _destinationPosition = destination;
    _currentPosition = currentPosition;

    // Calculate total route distance
    _totalDistance = _calculateTotalRouteDistance();

    // Calculate initial remaining distance
    _updateRemainingDistance();

    notifyListeners();
  }

  /// Update current position and recalculate remaining distance
  void updateCurrentPosition(LatLng position) {
    _currentPosition = position;
    _updateRemainingDistance();
  }

  /// Calculate remaining distance from current position to destination
  void _updateRemainingDistance() {
    if (_currentPosition == null || _destinationPosition == null) {
      _remainingDistance = null;
      return;
    }

    if (_routePoints.isEmpty) {
      // Direct distance if no route points
      _remainingDistance = _calculateDistance(
        _currentPosition!,
        _destinationPosition!,
      );
    } else {
      // Calculate distance along the route
      _remainingDistance = _calculateRemainingRouteDistance();
    }

    // Notify UI via callback
    if (_remainingDistance != null && onDistanceUpdate != null) {
      onDistanceUpdate!(_remainingDistance!);
    }

    notifyListeners();
  }

  /// Calculate total distance of the entire route
  double _calculateTotalRouteDistance() {
    if (_routePoints.length < 2) return 0.0;

    double total = 0.0;
    for (int i = 0; i < _routePoints.length - 1; i++) {
      total += _calculateDistance(_routePoints[i], _routePoints[i + 1]);
    }
    return total;
  }

  /// Calculate remaining distance along the route from current position
  double _calculateRemainingRouteDistance() {
    if (_currentPosition == null || _routePoints.isEmpty) return 0.0;

    // Find the closest point on the route to current position
    int closestIndex = _findClosestRoutePointIndex(_currentPosition!);

    // Calculate distance from current position to closest route point
    double remainingDistance = _calculateDistance(
      _currentPosition!,
      _routePoints[closestIndex],
    );

    // Add remaining route segments from closest point to destination
    for (int i = closestIndex; i < _routePoints.length - 1; i++) {
      remainingDistance += _calculateDistance(
        _routePoints[i],
        _routePoints[i + 1],
      );
    }

    return remainingDistance;
  }

  /// Find the closest route point to current position
  int _findClosestRoutePointIndex(LatLng currentPos) {
    double minDistance = double.infinity;
    int closestIndex = 0;

    for (int i = 0; i < _routePoints.length; i++) {
      double distance = _calculateDistance(currentPos, _routePoints[i]);
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    return closestIndex;
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371; // km
    final double dLat = _degreesToRadians(end.latitude - start.latitude);
    final double dLng = _degreesToRadians(end.longitude - start.longitude);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
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

  /// Clear navigation data
  void clearNavigation() {
    _remainingDistance = null;
    _totalDistance = null;
    _currentPosition = null;
    _destinationPosition = null;
    _routePoints.clear();
    notifyListeners();
  }
}
