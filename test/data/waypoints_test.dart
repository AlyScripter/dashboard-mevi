import 'package:flutter_test/flutter_test.dart';
import 'package:dashboardmevi/data/waypoints.dart';

void main() {
  group('Waypoints', () {
    test('wp01 should have correct properties', () {
      expect(Waypoints.wp01.name, 'WP 01 - Start');
      expect(Waypoints.wp01.latitude, -6.88248358);
      expect(Waypoints.wp01.longitude, 107.61073832);
    });

    test('wp02 should have correct properties', () {
      expect(Waypoints.wp02.name, 'WP 02');
      expect(Waypoints.wp02.latitude, -6.88243801);
      expect(Waypoints.wp02.longitude, 107.61075495);
    });

    test('wp03 should have correct properties', () {
      expect(Waypoints.wp03.name, 'WP 03');
      expect(Waypoints.wp03.latitude, -6.88241414);
      expect(Waypoints.wp03.longitude, 107.61078367);
    });

    test('wp33 should be the final waypoint', () {
      expect(Waypoints.wp33.name, 'WP 33 - Finish');
      expect(Waypoints.wp33.latitude, -6.88240546);
      expect(Waypoints.wp33.longitude, 107.61163629);
    });

    test('all waypoints should contain 33 waypoints', () {
      expect(Waypoints.allWaypoints.length, 33);
    });

    test('all waypoints should be Location objects', () {
      for (final waypoint in Waypoints.allWaypoints) {
        expect(waypoint.name, isNotEmpty);
        expect(waypoint.latitude, isA<double>());
        expect(waypoint.longitude, isA<double>());
      }
    });

    test('all waypoints should be ordered correctly', () {
      expect(Waypoints.allWaypoints.first, Waypoints.wp01);
      expect(Waypoints.allWaypoints.last, Waypoints.wp33);
    });

    test('waypoints should be const', () {
      expect(identical(Waypoints.wp01, Waypoints.wp01), true);
      expect(identical(Waypoints.wp02, Waypoints.wp02), true);
      expect(identical(Waypoints.wp33, Waypoints.wp33), true);
    });
  });
}
