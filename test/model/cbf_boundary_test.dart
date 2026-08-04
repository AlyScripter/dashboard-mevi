import 'package:flutter_test/flutter_test.dart';
import 'package:dashboardmevi/model/waypoint.dart';

void main() {
  group('CBFBoundary', () {
    test('fromNavigationData creates valid boundary', () {
      final boundary = CBFBoundary.fromNavigationData();

      expect(boundary.leftBoundary, isNotEmpty);
      expect(boundary.rightBoundary, isNotEmpty);
    });

    test('leftBoundary has valid coordinates', () {
      final boundary = CBFBoundary.fromNavigationData();

      for (final point in boundary.leftBoundary) {
        expect(point.latitude, inInclusiveRange(-90, 90));
        expect(point.longitude, inInclusiveRange(-180, 180));
      }
    });

    test('rightBoundary has valid coordinates', () {
      final boundary = CBFBoundary.fromNavigationData();

      for (final point in boundary.rightBoundary) {
        expect(point.latitude, inInclusiveRange(-90, 90));
        expect(point.longitude, inInclusiveRange(-180, 180));
      }
    });

    test('toJson returns valid map', () {
      final boundary = CBFBoundary.fromNavigationData();
      final json = boundary.toJson();

      expect(json, isA<Map<String, dynamic>>());
      expect(json['left_boundary'], isA<List>());
      expect(json['right_boundary'], isA<List>());
    });

    test('constructor creates boundary with given points', () {
      final leftPoints = [
        BoundaryPoint(latitude: -6.88, longitude: 107.61),
        BoundaryPoint(latitude: -6.89, longitude: 107.62),
      ];
      final rightPoints = [
        BoundaryPoint(latitude: -6.88, longitude: 107.62),
        BoundaryPoint(latitude: -6.89, longitude: 107.63),
      ];

      final boundary = CBFBoundary(
        leftBoundary: leftPoints,
        rightBoundary: rightPoints,
      );

      expect(boundary.leftBoundary.length, 2);
      expect(boundary.rightBoundary.length, 2);
    });
  });

  group('BoundaryPoint', () {
    test('constructor creates valid point', () {
      final point = BoundaryPoint(latitude: -6.88, longitude: 107.61);

      expect(point.latitude, -6.88);
      expect(point.longitude, 107.61);
    });

    test('fromCoordinates creates point from lon/lat order', () {
      final point = BoundaryPoint.fromCoordinates(107.61, -6.88);

      expect(point.longitude, 107.61);
      expect(point.latitude, -6.88);
    });

    test('toJson returns correct format', () {
      final point = BoundaryPoint(latitude: -6.88, longitude: 107.61);
      final json = point.toJson();

      expect(json['latitude'], -6.88);
      expect(json['longitude'], 107.61);
    });

    test('toString returns readable string', () {
      final point = BoundaryPoint(latitude: -6.88, longitude: 107.61);
      final str = point.toString();

      expect(str, contains('-6.88'));
      expect(str, contains('107.61'));
    });
  });

  group('Waypoint equality', () {
    test('two waypoints with same values are equal', () {
      final wp1 = Waypoint(
        name: 'WP1',
        longitude: 107.61,
        latitude: -6.88,
        altitude: 100,
        heading: 0,
        type: WaypointType.path,
      );
      final wp2 = Waypoint(
        name: 'WP1',
        longitude: 107.61,
        latitude: -6.88,
        altitude: 100,
        heading: 0,
        type: WaypointType.path,
      );

      expect(wp1, equals(wp2));
      expect(wp1.hashCode, equals(wp2.hashCode));
    });

    test('two waypoints with different values are not equal', () {
      final wp1 = Waypoint(
        name: 'WP1',
        longitude: 107.61,
        latitude: -6.88,
        altitude: 100,
        heading: 0,
        type: WaypointType.path,
      );
      final wp2 = Waypoint(
        name: 'WP2',
        longitude: 107.62,
        latitude: -6.89,
        altitude: 100,
        heading: 0,
        type: WaypointType.path,
      );

      expect(wp1, isNot(equals(wp2)));
    });
  });

  group('WaypointMission cbfBoundary', () {
    test('mission has cbfBoundary', () {
      final mission = WaypointMission(
        missionName: 'Test',
        description: 'Test',
        location: 'Test',
        createdDate: '2024-01-01',
        totalWaypoints: 1,
        pathWaypoints: 1,
        poiWaypoints: 0,
        defaultAltitude: 100,
        poiAltitude: 100,
        coordinateSystem: 'WGS84',
        waypoints: [
          Waypoint(
            name: 'WP1',
            longitude: 107.61,
            latitude: -6.88,
            altitude: 100,
            heading: 0,
            type: WaypointType.path,
          ),
        ],
        cbfBoundary: CBFBoundary.fromNavigationData(),
      );

      expect(mission.cbfBoundary, isNotNull);
      expect(mission.cbfBoundary!.leftBoundary, isNotEmpty);
      expect(mission.cbfBoundary!.rightBoundary, isNotEmpty);
    });
  });
}
