import 'package:flutter_test/flutter_test.dart';
import 'package:dashboardmevi/data/waypoints.dart';

void main() {
  group('Waypoints', () {
    test('start waypoint has correct coordinates', () {
      expect(Waypoints.start.name, 'WP 01 - Start');
      expect(Waypoints.start.latitude, closeTo(-6.8825, 0.001));
      expect(Waypoints.start.longitude, closeTo(107.6107, 0.001));
    });

    test('all waypoints are defined in allWaypoints list', () {
      expect(Waypoints.allWaypoints.length, 33);
      expect(Waypoints.allWaypoints.first.name, 'WP 01 - Start');
      expect(Waypoints.allWaypoints.last.name, 'WP 33 - Finish');
    });

    test('waypoints form a valid route', () {
      final waypoints = Waypoints.allWaypoints;

      // All waypoints should have valid coordinates
      for (final waypoint in waypoints) {
        expect(waypoint.latitude, inInclusiveRange(-90, 90));
        expect(waypoint.longitude, inInclusiveRange(-180, 180));
        expect(waypoint.name, isNotEmpty);
      }
    });

    test('waypoints are in BRIN area', () {
      // BRIN Bandung coordinates approximately
      const minLat = -7.0;
      const maxLat = -6.5;
      const minLng = 107.0;
      const maxLng = 108.0;

      final waypoints = [
        Waypoints.start,
        Waypoints.wp10,
        Waypoints.wp20,
        Waypoints.finalPoint,
      ];

      for (final waypoint in waypoints) {
        expect(waypoint.latitude, inInclusiveRange(minLat, maxLat));
        expect(waypoint.longitude, inInclusiveRange(minLng, maxLng));
      }
    });

    test('consecutive waypoints are close together', () {
      final waypoints = [Waypoints.wp01, Waypoints.wp02, Waypoints.wp03];

      for (int i = 0; i < waypoints.length - 1; i++) {
        final latDiff = (waypoints[i].latitude - waypoints[i + 1].latitude)
            .abs();
        final lngDiff = (waypoints[i].longitude - waypoints[i + 1].longitude)
            .abs();

        // Waypoints should be close (within ~0.01 degrees ~1km)
        expect(latDiff, lessThan(0.01));
        expect(lngDiff, lessThan(0.01));
      }
    });

    test('waypoints are const', () {
      final wp1 = Waypoints.start;
      final wp2 = Waypoints.start;
      expect(identical(wp1, wp2), isTrue);
    });

    test('finalPoint is different from start', () {
      expect(
        Waypoints.finalPoint.latitude,
        isNot(equals(Waypoints.start.latitude)),
      );
      expect(
        Waypoints.finalPoint.longitude,
        isNot(equals(Waypoints.start.longitude)),
      );
    });

    test('POI destinations are defined', () {
      expect(Waypoints.gedung10.name, 'Gedung 10 - BRIN');
      expect(Waypoints.labAutonomous.name, 'Lab Autonomous - BRIN');
      expect(Waypoints.gedung80.name, 'Gedung 80 - BRIN');
      expect(Waypoints.tamanBRIN.name, 'Taman - BRIN');
      expect(Waypoints.posSatpam.name, 'Finish - BRIN');
    });

    test('route waypoint lists are valid', () {
      expect(Waypoints.toGedung10.isNotEmpty, isTrue);
      expect(Waypoints.toLabAutonomous.isNotEmpty, isTrue);
      expect(Waypoints.toGedung80.isNotEmpty, isTrue);
      expect(Waypoints.toTamanBRIN.isNotEmpty, isTrue);
      expect(Waypoints.toPosSatpam.isNotEmpty, isTrue);
    });
  });
}
