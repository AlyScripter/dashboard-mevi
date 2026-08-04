import 'package:flutter_test/flutter_test.dart';
import 'package:dashboardmevi/model/waypoint.dart';

void main() {
  group('Waypoint - Extended Tests', () {
    test('should create Waypoint from JSON', () {
      final json = {
        'name': 'Test Waypoint',
        'display_name': 'Test Display',
        'longitude': 107.6107,
        'latitude': -6.8825,
        'altitude': 10.0,
        'heading': 90.0,
        'type': 'path',
      };

      final waypoint = Waypoint.fromJson(json);

      expect(waypoint.name, 'Test Waypoint');
      expect(waypoint.displayName, 'Test Display');
      expect(waypoint.longitude, 107.6107);
      expect(waypoint.latitude, -6.8825);
      expect(waypoint.altitude, 10.0);
      expect(waypoint.heading, 90.0);
      expect(waypoint.type, WaypointType.path);
    });

    test('should create Waypoint from JSON without displayName', () {
      final json = {
        'name': 'Test',
        'longitude': 107.6107,
        'latitude': -6.8825,
        'altitude': 10.0,
        'heading': 0.0,
        'type': 'poi',
      };

      final waypoint = Waypoint.fromJson(json);

      expect(waypoint.displayName, isNull);
      expect(waypoint.type, WaypointType.poi);
    });

    test('should convert Waypoint to JSON', () {
      const waypoint = Waypoint(
        name: 'Test',
        displayName: 'Display',
        longitude: 107.6107,
        latitude: -6.8825,
        altitude: 10.0,
        heading: 45.0,
        type: WaypointType.path,
      );

      final json = waypoint.toJson();

      expect(json['name'], 'Test');
      expect(json['display_name'], 'Display');
      expect(json['longitude'], 107.6107);
      expect(json['latitude'], -6.8825);
      expect(json['altitude'], 10.0);
      expect(json['heading'], 45.0);
      expect(json['type'], 'path');
    });

    test('should convert Waypoint to JSON without displayName', () {
      const waypoint = Waypoint(
        name: 'Test',
        longitude: 107.6107,
        latitude: -6.8825,
        altitude: 10.0,
        heading: 0.0,
        type: WaypointType.poi,
      );

      final json = waypoint.toJson();

      expect(json.containsKey('display_name'), false);
    });

    test('should compare Waypoints with == operator', () {
      const waypoint1 = Waypoint(
        name: 'Test',
        longitude: 107.6107,
        latitude: -6.8825,
        altitude: 10.0,
        heading: 0.0,
        type: WaypointType.path,
      );

      const waypoint2 = Waypoint(
        name: 'Test',
        longitude: 107.6107,
        latitude: -6.8825,
        altitude: 10.0,
        heading: 0.0,
        type: WaypointType.path,
      );

      expect(waypoint1 == waypoint2, true);
    });

    test('should have different hashCodes for different waypoints', () {
      const waypoint1 = Waypoint(
        name: 'Test1',
        longitude: 107.6107,
        latitude: -6.8825,
        altitude: 10.0,
        heading: 0.0,
        type: WaypointType.path,
      );

      const waypoint2 = Waypoint(
        name: 'Test2',
        longitude: 107.6108,
        latitude: -6.8826,
        altitude: 10.0,
        heading: 0.0,
        type: WaypointType.path,
      );

      expect(waypoint1.hashCode != waypoint2.hashCode, true);
    });

    test('should have correct toString representation', () {
      const waypoint = Waypoint(
        name: 'Test',
        longitude: 107.6107,
        latitude: -6.8825,
        altitude: 10.0,
        heading: 0.0,
        type: WaypointType.path,
      );

      final str = waypoint.toString();
      expect(str, contains('Test'));
      expect(str, contains('-6.8825'));
      expect(str, contains('107.6107'));
    });
  });

  group('BoundaryPoint', () {
    test('should create BoundaryPoint', () {
      const point = BoundaryPoint(longitude: 107.6107, latitude: -6.8825);

      expect(point.longitude, 107.6107);
      expect(point.latitude, -6.8825);
    });

    test('should create BoundaryPoint from coordinates', () {
      final point = BoundaryPoint.fromCoordinates(107.6107, -6.8825);

      expect(point.longitude, 107.6107);
      expect(point.latitude, -6.8825);
    });

    test('should convert BoundaryPoint to JSON', () {
      const point = BoundaryPoint(longitude: 107.6107, latitude: -6.8825);
      final json = point.toJson();

      expect(json['longitude'], 107.6107);
      expect(json['latitude'], -6.8825);
    });

    test('should have correct toString', () {
      const point = BoundaryPoint(longitude: 107.6107, latitude: -6.8825);
      final str = point.toString();

      expect(str, contains('107.6107'));
      expect(str, contains('-6.8825'));
    });
  });

  group('CBFBoundary', () {
    test('should create CBFBoundary from navigation data', () {
      final boundary = CBFBoundary.fromNavigationData();

      expect(boundary.leftBoundary, isNotEmpty);
      expect(boundary.rightBoundary, isNotEmpty);
      expect(boundary.leftBoundary.length, greaterThan(30));
      expect(boundary.rightBoundary.length, greaterThan(30));
    });

    test('boundary points should have valid coordinates', () {
      final boundary = CBFBoundary.fromNavigationData();

      for (final point in boundary.leftBoundary) {
        expect(point.longitude, greaterThan(107.0));
        expect(point.longitude, lessThan(108.0));
        expect(point.latitude, lessThan(-6.0));
        expect(point.latitude, greaterThan(-7.0));
      }

      for (final point in boundary.rightBoundary) {
        expect(point.longitude, greaterThan(107.0));
        expect(point.longitude, lessThan(108.0));
        expect(point.latitude, lessThan(-6.0));
        expect(point.latitude, greaterThan(-7.0));
      }
    });

    test('should convert CBFBoundary to JSON', () {
      final boundary = CBFBoundary.fromNavigationData();
      final json = boundary.toJson();

      expect(json['left_boundary'], isList);
      expect(json['right_boundary'], isList);
      expect(json['left_boundary'].length, boundary.leftBoundary.length);
      expect(json['right_boundary'].length, boundary.rightBoundary.length);
    });

    test('left and right boundaries should have similar lengths', () {
      final boundary = CBFBoundary.fromNavigationData();

      expect(
        (boundary.leftBoundary.length - boundary.rightBoundary.length).abs(),
        lessThan(5),
      );
    });
  });

  group('WaypointType', () {
    test('should convert from string to enum', () {
      expect(WaypointType.fromString('path'), WaypointType.path);
      expect(WaypointType.fromString('poi'), WaypointType.poi);
      expect(WaypointType.fromString('PATH'), WaypointType.path);
      expect(WaypointType.fromString('POI'), WaypointType.poi);
    });

    test('should default to path for unknown strings', () {
      expect(WaypointType.fromString('unknown'), WaypointType.path);
      expect(WaypointType.fromString(''), WaypointType.path);
    });

    test('should convert enum to string', () {
      expect(WaypointType.path.toString(), 'path');
      expect(WaypointType.poi.toString(), 'poi');
    });
  });

  group('WaypointMission', () {
    test('should create WaypointMission from JSON', () {
      final json = {
        'mission_name': 'Test Mission',
        'description': 'Test Description',
        'location': 'BRIN, Bandung',
        'created_date': '2025-10-30',
        'total_waypoints': 12,
        'path_waypoints': 10,
        'poi_waypoints': 2,
        'default_altitude': 10.0,
        'poi_altitude': 15.0,
        'coordinate_system': 'WGS84',
        'waypoints': [
          {
            'name': 'WP1',
            'longitude': 107.6107,
            'latitude': -6.8825,
            'altitude': 10.0,
            'heading': 0.0,
            'type': 'path',
          },
          {
            'name': 'POI1',
            'longitude': 107.6108,
            'latitude': -6.8826,
            'altitude': 15.0,
            'heading': 45.0,
            'type': 'poi',
          },
        ],
      };

      final mission = WaypointMission.fromJson(json);

      expect(mission.missionName, 'Test Mission');
      expect(mission.description, 'Test Description');
      expect(mission.location, 'BRIN, Bandung');
      expect(mission.totalWaypoints, 12);
      expect(mission.pathWaypoints, 10);
      expect(mission.poiWaypoints, 2);
      expect(mission.defaultAltitude, 10.0);
      expect(mission.poiAltitude, 15.0);
      expect(mission.coordinateSystem, 'WGS84');
      expect(mission.waypoints.length, 2);
      expect(mission.cbfBoundary, isNotNull);
    });

    test('should convert WaypointMission to JSON', () {
      const mission = WaypointMission(
        missionName: 'Test',
        description: 'Desc',
        location: 'BRIN',
        createdDate: '2025-10-30',
        totalWaypoints: 2,
        pathWaypoints: 1,
        poiWaypoints: 1,
        defaultAltitude: 10.0,
        poiAltitude: 15.0,
        coordinateSystem: 'WGS84',
        waypoints: [
          Waypoint(
            name: 'WP1',
            longitude: 107.6107,
            latitude: -6.8825,
            altitude: 10.0,
            heading: 0.0,
            type: WaypointType.path,
          ),
        ],
      );

      final json = mission.toJson();

      expect(json['mission_name'], 'Test');
      expect(json['total_waypoints'], 2);
      expect(json['waypoints'], isList);
      expect(json.containsKey('cbf_boundary'), false);
    });

    test('should get path waypoints only', () {
      const mission = WaypointMission(
        missionName: 'Test',
        description: 'Desc',
        location: 'BRIN',
        createdDate: '2025-10-30',
        totalWaypoints: 3,
        pathWaypoints: 2,
        poiWaypoints: 1,
        defaultAltitude: 10.0,
        poiAltitude: 15.0,
        coordinateSystem: 'WGS84',
        waypoints: [
          Waypoint(
            name: 'WP1',
            longitude: 107.6107,
            latitude: -6.8825,
            altitude: 10.0,
            heading: 0.0,
            type: WaypointType.path,
          ),
          Waypoint(
            name: 'POI1',
            longitude: 107.6108,
            latitude: -6.8826,
            altitude: 15.0,
            heading: 0.0,
            type: WaypointType.poi,
          ),
          Waypoint(
            name: 'WP2',
            longitude: 107.6109,
            latitude: -6.8827,
            altitude: 10.0,
            heading: 0.0,
            type: WaypointType.path,
          ),
        ],
      );

      final pathWaypoints = mission.pathWaypointsOnly;

      expect(pathWaypoints.length, 2);
      expect(pathWaypoints[0].name, 'WP1');
      expect(pathWaypoints[1].name, 'WP2');
    });

    test('should get POI waypoints only', () {
      const mission = WaypointMission(
        missionName: 'Test',
        description: 'Desc',
        location: 'BRIN',
        createdDate: '2025-10-30',
        totalWaypoints: 3,
        pathWaypoints: 2,
        poiWaypoints: 1,
        defaultAltitude: 10.0,
        poiAltitude: 15.0,
        coordinateSystem: 'WGS84',
        waypoints: [
          Waypoint(
            name: 'WP1',
            longitude: 107.6107,
            latitude: -6.8825,
            altitude: 10.0,
            heading: 0.0,
            type: WaypointType.path,
          ),
          Waypoint(
            name: 'POI1',
            longitude: 107.6108,
            latitude: -6.8826,
            altitude: 15.0,
            heading: 0.0,
            type: WaypointType.poi,
          ),
        ],
      );

      final poiWaypoints = mission.poiWaypointsOnly;

      expect(poiWaypoints.length, 1);
      expect(poiWaypoints[0].name, 'POI1');
      expect(poiWaypoints[0].type, WaypointType.poi);
    });

    test('should include CBF boundary in JSON when present', () {
      final mission = WaypointMission(
        missionName: 'Test',
        description: 'Desc',
        location: 'BRIN',
        createdDate: '2025-10-30',
        totalWaypoints: 1,
        pathWaypoints: 1,
        poiWaypoints: 0,
        defaultAltitude: 10.0,
        poiAltitude: 15.0,
        coordinateSystem: 'WGS84',
        waypoints: const [],
        cbfBoundary: CBFBoundary.fromNavigationData(),
      );

      final json = mission.toJson();

      expect(json.containsKey('cbf_boundary'), true);
      expect(json['cbf_boundary'], isNotNull);
    });
  });
}
