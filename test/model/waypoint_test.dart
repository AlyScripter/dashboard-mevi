import 'package:flutter_test/flutter_test.dart';
import 'package:dashboardmevi/model/waypoint.dart';

void main() {
  group('Waypoint', () {
    test('should create Waypoint from json', () {
      final json = {
        'name': 'WP1',
        'display_name': 'Waypoint 1',
        'longitude': 107.6107,
        'latitude': -6.8825,
        'altitude': 100.0,
        'heading': 90.0,
        'type': 'path',
      };

      final waypoint = Waypoint.fromJson(json);

      expect(waypoint.name, 'WP1');
      expect(waypoint.displayName, 'Waypoint 1');
      expect(waypoint.longitude, 107.6107);
      expect(waypoint.latitude, -6.8825);
      expect(waypoint.altitude, 100.0);
      expect(waypoint.heading, 90.0);
      expect(waypoint.type, WaypointType.path);
    });

    test('should create Waypoint without display name', () {
      final json = {
        'name': 'WP2',
        'longitude': 107.6108,
        'latitude': -6.8826,
        'altitude': 105.0,
        'heading': 180.0,
        'type': 'poi',
      };

      final waypoint = Waypoint.fromJson(json);

      expect(waypoint.name, 'WP2');
      expect(waypoint.displayName, null);
      expect(waypoint.type, WaypointType.poi);
    });

    test('should convert Waypoint to json', () {
      final waypoint = Waypoint(
        name: 'WP1',
        displayName: 'Waypoint 1',
        longitude: 107.6107,
        latitude: -6.8825,
        altitude: 100.0,
        heading: 90.0,
        type: WaypointType.path,
      );

      final json = waypoint.toJson();

      expect(json['name'], 'WP1');
      expect(json['display_name'], 'Waypoint 1');
      expect(json['longitude'], 107.6107);
      expect(json['latitude'], -6.8825);
      expect(json['altitude'], 100.0);
      expect(json['heading'], 90.0);
    });

    test('should check equality', () {
      final waypoint1 = Waypoint(
        name: 'WP1',
        longitude: 107.6107,
        latitude: -6.8825,
        altitude: 100.0,
        heading: 90.0,
        type: WaypointType.path,
      );

      final waypoint2 = Waypoint(
        name: 'WP1',
        longitude: 107.6107,
        latitude: -6.8825,
        altitude: 100.0,
        heading: 90.0,
        type: WaypointType.path,
      );

      expect(waypoint1, waypoint2);
      expect(waypoint1.hashCode, waypoint2.hashCode);
    });

    test('should return correct toString', () {
      final waypoint = Waypoint(
        name: 'WP1',
        longitude: 107.6107,
        latitude: -6.8825,
        altitude: 100.0,
        heading: 90.0,
        type: WaypointType.path,
      );

      expect(waypoint.toString(), contains('WP1'));
      expect(waypoint.toString(), contains('-6.8825'));
      expect(waypoint.toString(), contains('107.6107'));
    });
  });

  group('BoundaryPoint', () {
    test('should create BoundaryPoint', () {
      final point = BoundaryPoint(longitude: 107.6107, latitude: -6.8825);

      expect(point.longitude, 107.6107);
      expect(point.latitude, -6.8825);
    });

    test('should create BoundaryPoint from coordinates', () {
      final point = BoundaryPoint.fromCoordinates(107.6107, -6.8825);

      expect(point.longitude, 107.6107);
      expect(point.latitude, -6.8825);
    });

    test('should convert BoundaryPoint to json', () {
      final point = BoundaryPoint(longitude: 107.6107, latitude: -6.8825);
      final json = point.toJson();

      expect(json['longitude'], 107.6107);
      expect(json['latitude'], -6.8825);
    });

    test('should return correct toString', () {
      final point = BoundaryPoint(longitude: 107.6107, latitude: -6.8825);

      expect(point.toString(), contains('107.6107'));
      expect(point.toString(), contains('-6.8825'));
    });
  });

  group('CBFBoundary', () {
    test('should create CBFBoundary', () {
      final leftBoundary = [
        BoundaryPoint(longitude: 107.6107, latitude: -6.8825),
        BoundaryPoint(longitude: 107.6108, latitude: -6.8826),
      ];
      final rightBoundary = [
        BoundaryPoint(longitude: 107.6109, latitude: -6.8827),
        BoundaryPoint(longitude: 107.6110, latitude: -6.8828),
      ];

      final boundary = CBFBoundary(
        leftBoundary: leftBoundary,
        rightBoundary: rightBoundary,
      );

      expect(boundary.leftBoundary.length, 2);
      expect(boundary.rightBoundary.length, 2);
    });

    test('should create CBFBoundary from navigation data', () {
      final boundary = CBFBoundary.fromNavigationData();

      expect(boundary.leftBoundary, isNotEmpty);
      expect(boundary.rightBoundary, isNotEmpty);
    });

    test('should have boundary points', () {
      final boundary = CBFBoundary.fromNavigationData();

      expect(boundary.leftBoundary.length, greaterThan(0));
      expect(boundary.rightBoundary.length, greaterThan(0));
    });
  });

  group('WaypointType', () {
    test('should parse WaypointType from string', () {
      expect(WaypointType.fromString('path'), WaypointType.path);
      expect(WaypointType.fromString('poi'), WaypointType.poi);
    });

    test('should handle unknown type', () {
      expect(WaypointType.fromString('unknown'), WaypointType.path);
    });

    test('should convert to string correctly', () {
      expect(WaypointType.path.toString(), 'path');
      expect(WaypointType.poi.toString(), 'poi');
    });
  });

  group('WaypointMission', () {
    test('should create WaypointMission from json', () {
      final json = {
        'mission_name': 'Test Mission',
        'description': 'Test Description',
        'location': 'Bandung',
        'created_date': '2024-01-01',
        'total_waypoints': 10,
        'path_waypoints': 8,
        'poi_waypoints': 2,
        'default_altitude': 100.0,
        'poi_altitude': 120.0,
        'coordinate_system': 'WGS84',
        'waypoints': [
          {
            'name': 'WP1',
            'longitude': 107.6107,
            'latitude': -6.8825,
            'altitude': 100.0,
            'heading': 90.0,
            'type': 'path',
          },
        ],
      };

      final mission = WaypointMission.fromJson(json);

      expect(mission.missionName, 'Test Mission');
      expect(mission.description, 'Test Description');
      expect(mission.location, 'Bandung');
      expect(mission.totalWaypoints, 10);
      expect(mission.waypoints.length, 1);
      expect(mission.cbfBoundary, isNotNull);
    });

    test('should convert WaypointMission to json', () {
      final mission = WaypointMission(
        missionName: 'Test Mission',
        description: 'Test Description',
        location: 'Bandung',
        createdDate: '2024-01-01',
        totalWaypoints: 1,
        pathWaypoints: 1,
        poiWaypoints: 0,
        defaultAltitude: 100.0,
        poiAltitude: 120.0,
        coordinateSystem: 'WGS84',
        waypoints: [
          Waypoint(
            name: 'WP1',
            longitude: 107.6107,
            latitude: -6.8825,
            altitude: 100.0,
            heading: 90.0,
            type: WaypointType.path,
          ),
        ],
        cbfBoundary: CBFBoundary.fromNavigationData(),
      );

      final json = mission.toJson();

      expect(json['mission_name'], 'Test Mission');
      expect(json['total_waypoints'], 1);
      expect(json['waypoints'], isA<List>());
    });

    test('should get path waypoints only', () {
      final mission = WaypointMission(
        missionName: 'Test',
        description: 'Test',
        location: 'Test',
        createdDate: '2024-01-01',
        totalWaypoints: 3,
        pathWaypoints: 2,
        poiWaypoints: 1,
        defaultAltitude: 100.0,
        poiAltitude: 120.0,
        coordinateSystem: 'WGS84',
        waypoints: [
          Waypoint(
            name: 'WP1',
            longitude: 107.6107,
            latitude: -6.8825,
            altitude: 100.0,
            heading: 90.0,
            type: WaypointType.path,
          ),
          Waypoint(
            name: 'WP2',
            longitude: 107.6108,
            latitude: -6.8826,
            altitude: 100.0,
            heading: 90.0,
            type: WaypointType.poi,
          ),
          Waypoint(
            name: 'WP3',
            longitude: 107.6109,
            latitude: -6.8827,
            altitude: 100.0,
            heading: 90.0,
            type: WaypointType.path,
          ),
        ],
      );

      final pathWaypoints = mission.pathWaypointsOnly;
      expect(pathWaypoints.length, 2);
      expect(pathWaypoints.every((w) => w.type == WaypointType.path), true);
    });

    test('should get POI waypoints only', () {
      final mission = WaypointMission(
        missionName: 'Test',
        description: 'Test',
        location: 'Test',
        createdDate: '2024-01-01',
        totalWaypoints: 3,
        pathWaypoints: 2,
        poiWaypoints: 1,
        defaultAltitude: 100.0,
        poiAltitude: 120.0,
        coordinateSystem: 'WGS84',
        waypoints: [
          Waypoint(
            name: 'WP1',
            longitude: 107.6107,
            latitude: -6.8825,
            altitude: 100.0,
            heading: 90.0,
            type: WaypointType.path,
          ),
          Waypoint(
            name: 'WP2',
            longitude: 107.6108,
            latitude: -6.8826,
            altitude: 100.0,
            heading: 90.0,
            type: WaypointType.poi,
          ),
        ],
      );

      final poiWaypoints = mission.poiWaypointsOnly;
      expect(poiWaypoints.length, 1);
      expect(poiWaypoints.every((w) => w.type == WaypointType.poi), true);
    });
  });
}
