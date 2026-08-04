import 'package:flutter_test/flutter_test.dart';
import 'package:dashboardmevi/services/waypoint_service.dart';
import 'package:dashboardmevi/model/waypoint.dart';

void main() {
  group('WaypointService', () {
    test('getDefaultMission returns valid mission with 5 waypoints', () {
      // Act
      final mission = WaypointService.getDefaultMission();

      // Assert
      expect(mission.missionName, 'Default BRIN Mission');
      expect(mission.totalWaypoints, 5);
      expect(mission.pathWaypoints, 5);
      expect(mission.poiWaypoints, 0);
      expect(mission.waypoints.length, 5);
      expect(mission.defaultAltitude, 10.0);
      expect(mission.coordinateSystem, 'WGS84');
    });

    test('getDefaultMission waypoints have correct structure', () {
      // Act
      final mission = WaypointService.getDefaultMission();
      final firstWaypoint = mission.waypoints.first;

      // Assert
      expect(firstWaypoint.name, 'waypoint_1');
      expect(firstWaypoint.longitude, 107.6113890776042);
      expect(firstWaypoint.latitude, -6.881270131388471);
      expect(firstWaypoint.altitude, 10.0);
      expect(firstWaypoint.type, WaypointType.path);
    });

    test('getDefaultMission has all required fields', () {
      final mission = WaypointService.getDefaultMission();

      expect(mission.description, 'Default waypoints for BRIN facility');
      expect(mission.location, 'BRIN, Bandung, Indonesia');
      expect(mission.createdDate, '2025-09-15');
      expect(mission.poiAltitude, 15.0);
    });

    test('getDefaultMission all waypoints have path type', () {
      final mission = WaypointService.getDefaultMission();

      for (final waypoint in mission.waypoints) {
        expect(waypoint.type, WaypointType.path);
        expect(waypoint.heading, 0.0);
        expect(waypoint.altitude, 10.0);
      }
    });

    test('loadWaypointMission returns default when file not found', () async {
      // Act
      final mission = await WaypointService.loadWaypointMission(
        customPath: 'nonexistent',
      );

      // Assert
      expect(mission.missionName, 'Default BRIN Mission');
      expect(mission.waypoints.length, 5);
    });

    test('loadWaypointMission returns default with no custom path', () async {
      // Act
      final mission = await WaypointService.loadWaypointMission();

      // Assert - may load actual file or default
      expect(mission, isA<WaypointMission>());
      expect(mission.waypoints, isNotEmpty);
    });

    test('loadFromAssets returns default mission on error', () async {
      // Act
      final mission = await WaypointService.loadFromAssets(
        assetPath: 'invalid/path.json',
      );

      // Assert
      expect(mission.missionName, 'Default BRIN Mission');
      expect(mission.waypoints.length, 5);
    });

    test('loadFromAssets with default path returns default mission', () async {
      // Act
      final mission = await WaypointService.loadFromAssets();

      // Assert
      expect(mission, isA<WaypointMission>());
    });

    test('waypointToLocation converts correctly', () {
      // Arrange
      const waypoint = Waypoint(
        name: 'Test Waypoint',
        longitude: 107.6113,
        latitude: -6.8812,
        altitude: 10.0,
        heading: 0.0,
        type: WaypointType.path,
      );

      // Act
      final location = WaypointService.waypointToLocation(waypoint);

      // Assert
      expect(location.name, 'Test Waypoint');
      expect(location.latitude, -6.8812);
      expect(location.longitude, 107.6113);
    });

    test('waypointsToLocations converts list correctly', () {
      // Arrange
      const waypoints = [
        Waypoint(
          name: 'WP1',
          longitude: 107.61,
          latitude: -6.88,
          altitude: 10.0,
          heading: 0.0,
          type: WaypointType.path,
        ),
        Waypoint(
          name: 'WP2',
          longitude: 107.62,
          latitude: -6.89,
          altitude: 10.0,
          heading: 0.0,
          type: WaypointType.path,
        ),
      ];

      // Act
      final locations = WaypointService.waypointsToLocations(waypoints);

      // Assert
      expect(locations.length, 2);
      expect(locations[0].name, 'WP1');
      expect(locations[1].name, 'WP2');
      expect(locations[0].latitude, -6.88);
      expect(locations[1].longitude, 107.62);
    });

    test('waypointsToLocations handles empty list', () {
      final locations = WaypointService.waypointsToLocations([]);
      expect(locations, isEmpty);
    });

    test('waypointsToLocations converts all default waypoints', () {
      final mission = WaypointService.getDefaultMission();
      final locations = WaypointService.waypointsToLocations(mission.waypoints);

      expect(locations.length, mission.waypoints.length);
      expect(locations[0].name, 'waypoint_1');
      expect(locations[4].name, 'waypoint_5');
    });

    test('Location equality works correctly', () {
      // Arrange
      const loc1 = Location(name: 'Test', latitude: -6.88, longitude: 107.61);
      const loc2 = Location(name: 'Test', latitude: -6.88, longitude: 107.61);
      const loc3 = Location(name: 'Other', latitude: -6.88, longitude: 107.61);

      // Assert
      expect(loc1, equals(loc2));
      expect(loc1, isNot(equals(loc3)));
    });

    test('Location equality checks all fields', () {
      const loc1 = Location(name: 'Test', latitude: -6.88, longitude: 107.61);
      const loc2 = Location(name: 'Test', latitude: -6.89, longitude: 107.61);
      const loc3 = Location(name: 'Test', latitude: -6.88, longitude: 107.62);

      expect(loc1, isNot(equals(loc2))); // Different latitude
      expect(loc1, isNot(equals(loc3))); // Different longitude
    });

    test('Location hashCode is consistent', () {
      const loc1 = Location(name: 'Test', latitude: -6.88, longitude: 107.61);
      const loc2 = Location(name: 'Test', latitude: -6.88, longitude: 107.61);

      expect(loc1.hashCode, equals(loc2.hashCode));
    });

    test('Location toString returns formatted string', () {
      // Arrange
      const location = Location(
        name: 'BRIN',
        latitude: -6.88,
        longitude: 107.61,
      );

      // Act
      final result = location.toString();

      // Assert
      expect(result, 'Location(BRIN: -6.88, 107.61)');
    });

    test('Location with different names have different hashCodes', () {
      const loc1 = Location(name: 'Test1', latitude: -6.88, longitude: 107.61);
      const loc2 = Location(name: 'Test2', latitude: -6.88, longitude: 107.61);

      expect(loc1.hashCode, isNot(equals(loc2.hashCode)));
    });
  });
}
