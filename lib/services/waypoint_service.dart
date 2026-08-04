import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import '../model/waypoint.dart';

/// Service for loading waypoint data from JSON files
class WaypointService {
  static const String _defaultWaypointPath =
      'deployment/docker/waypoints/brin_waypoint_mission.json';

  /// Load waypoint mission from assets or file system
  static Future<WaypointMission> loadWaypointMission({
    String? customPath,
  }) async {
    final String filePath = customPath ?? _defaultWaypointPath;

    try {
      // Try to load from assets first
      String jsonString;
      try {
        jsonString = await rootBundle.loadString('assets/$filePath');
      } catch (e) {
        // If not in assets, try to load from file system
        final file = File(filePath);
        if (await file.exists()) {
          jsonString = await file.readAsString();
        } else {
          // If file doesn't exist, return default mission
          return getDefaultMission();
        }
      }

      final Map<String, dynamic> jsonData = json.decode(jsonString);
      return WaypointMission.fromJson(jsonData);
    } catch (e) {
      // If loading fails, return default mission
      print('Error loading waypoint mission: $e');
      return getDefaultMission();
    }
  }

  /// Load waypoint mission synchronously from assets
  static Future<WaypointMission> loadFromAssets({
    String assetPath = 'assets/waypoints/brin_waypoint_mission.json',
  }) async {
    try {
      final String jsonString = await rootBundle.loadString(assetPath);
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      return WaypointMission.fromJson(jsonData);
    } catch (e) {
      print('Error loading waypoint mission from assets: $e');
      return getDefaultMission();
    }
  }

  /// Get default mission with hardcoded waypoints as fallback
  static WaypointMission getDefaultMission() {
    return const WaypointMission(
      missionName: "Default BRIN Mission",
      description: "Default waypoints for BRIN facility",
      location: "BRIN, Bandung, Indonesia",
      createdDate: "2025-09-15",
      totalWaypoints: 5,
      pathWaypoints: 5,
      poiWaypoints: 0,
      defaultAltitude: 10.0,
      poiAltitude: 15.0,
      coordinateSystem: "WGS84",
      waypoints: [
        Waypoint(
          name: "waypoint_1",
          longitude: 107.6113890776042,
          latitude: -6.881270131388471,
          altitude: 10.0,
          heading: 0.0,
          type: WaypointType.path,
        ),
        Waypoint(
          name: "waypoint_2",
          longitude: 107.6117390639971,
          latitude: -6.881309649404917,
          altitude: 10.0,
          heading: 0.0,
          type: WaypointType.path,
        ),
        Waypoint(
          name: "waypoint_3",
          longitude: 107.6117246175148,
          latitude: -6.881474283214416,
          altitude: 10.0,
          heading: 0.0,
          type: WaypointType.path,
        ),
        Waypoint(
          name: "waypoint_4",
          longitude: 107.6116913238807,
          latitude: -6.881873708611313,
          altitude: 10.0,
          heading: 0.0,
          type: WaypointType.path,
        ),
        Waypoint(
          name: "waypoint_5",
          longitude: 107.6115896383048,
          latitude: -6.882703380541389,
          altitude: 10.0,
          heading: 0.0,
          type: WaypointType.path,
        ),
      ],
    );
  }

  /// Convert waypoint to Location for backward compatibility
  static Location waypointToLocation(Waypoint waypoint) {
    return Location(
      name: waypoint.name,
      latitude: waypoint.latitude,
      longitude: waypoint.longitude,
    );
  }

  /// Convert list of waypoints to locations
  static List<Location> waypointsToLocations(List<Waypoint> waypoints) {
    return waypoints.map(waypointToLocation).toList();
  }
}

/// Location model class for backward compatibility
class Location {
  final String name;
  final double latitude;
  final double longitude;

  const Location({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Location &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => name.hashCode ^ latitude.hashCode ^ longitude.hashCode;

  @override
  String toString() => 'Location($name: $latitude, $longitude)';
}
