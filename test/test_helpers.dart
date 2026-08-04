/// Common test helpers to reduce duplication across test files
library;

import 'package:dashboardmevi/model/location.dart';
import 'package:dashboardmevi/model/waypoint.dart';

/// Test data constants
class TestData {
  // BRIN coordinates
  static const double brinLat = -6.8825;
  static const double brinLng = 107.6107;

  // Test locations
  static Location get brinLocation => Location(
    name: 'BRIN Test Location',
    latitude: brinLat,
    longitude: brinLng,
  );

  static Location get testLocation =>
      Location(name: 'Test Point', latitude: -6.8826, longitude: 107.6108);

  // Test waypoints
  static Waypoint get startWaypoint => Waypoint(
    name: 'Start',
    longitude: brinLng,
    latitude: brinLat,
    altitude: 10.0,
    heading: 0.0,
    type: WaypointType.path,
  );

  static Waypoint get pathWaypoint => Waypoint(
    name: 'Path',
    longitude: 107.6108,
    latitude: -6.8826,
    altitude: 10.0,
    heading: 90.0,
    type: WaypointType.path,
  );
}

/// Test matchers and utilities
class TestUtils {
  /// Check if coordinate is valid
  static bool isValidCoordinate(double lat, double lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  /// Check if coordinate is in BRIN area
  static bool isInBrinArea(double lat, double lng) {
    return (lat >= -6.89 && lat <= -6.88) && (lng >= 107.60 && lng <= 107.62);
  }
}
