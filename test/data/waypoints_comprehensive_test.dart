import 'package:flutter_test/flutter_test.dart';
import 'package:dashboardmevi/data/waypoints.dart';

void main() {
  group('Waypoints', () {
    group('Individual Waypoints', () {
      test('wp01 is start waypoint', () {
        expect(Waypoints.wp01.name, 'WP 01 - Start');
        expect(Waypoints.wp01.latitude, closeTo(-6.8825, 0.001));
        expect(Waypoints.wp01.longitude, closeTo(107.6107, 0.001));
      });

      test('wp33 is finish waypoint', () {
        expect(Waypoints.wp33.name, 'WP 33 - Finish');
        expect(Waypoints.wp33.latitude, closeTo(-6.8824, 0.001));
        expect(Waypoints.wp33.longitude, closeTo(107.6116, 0.001));
      });

      test('wp10 exists with valid coordinates', () {
        expect(Waypoints.wp10.latitude, inInclusiveRange(-90, 90));
        expect(Waypoints.wp10.longitude, inInclusiveRange(-180, 180));
      });

      test('wp20 exists with valid coordinates', () {
        expect(Waypoints.wp20.latitude, inInclusiveRange(-90, 90));
        expect(Waypoints.wp20.longitude, inInclusiveRange(-180, 180));
      });
    });

    group('allWaypoints', () {
      test('contains 33 waypoints', () {
        expect(Waypoints.allWaypoints.length, 33);
      });

      test('first is wp01', () {
        expect(Waypoints.allWaypoints.first, Waypoints.wp01);
      });

      test('last is wp33', () {
        expect(Waypoints.allWaypoints.last, Waypoints.wp33);
      });

      test('all waypoints have valid coordinates', () {
        for (final wp in Waypoints.allWaypoints) {
          expect(wp.latitude, inInclusiveRange(-90, 90));
          expect(wp.longitude, inInclusiveRange(-180, 180));
          expect(wp.name, isNotEmpty);
        }
      });
    });

    group('Route Waypoints', () {
      test('toGedung10 is not empty', () {
        expect(Waypoints.toGedung10, isNotEmpty);
        expect(Waypoints.toGedung10.first, Waypoints.wp01);
      });

      test('toLabAutonomous is not empty', () {
        expect(Waypoints.toLabAutonomous, isNotEmpty);
        expect(Waypoints.toLabAutonomous.first, Waypoints.wp01);
      });

      test('toGedung80 is not empty', () {
        expect(Waypoints.toGedung80, isNotEmpty);
        expect(Waypoints.toGedung80.first, Waypoints.wp01);
      });

      test('toTamanBRIN is not empty', () {
        expect(Waypoints.toTamanBRIN, isNotEmpty);
        expect(Waypoints.toTamanBRIN.first, Waypoints.wp01);
      });

      test('toPosSatpam equals allWaypoints', () {
        expect(Waypoints.toPosSatpam, Waypoints.allWaypoints);
      });
    });

    group('POI Destinations', () {
      test('gedung10 has correct name', () {
        expect(Waypoints.gedung10.name, 'Gedung 10 - BRIN');
      });

      test('labAutonomous has correct name', () {
        expect(Waypoints.labAutonomous.name, 'Lab Autonomous - BRIN');
      });

      test('gedung80 has correct name', () {
        expect(Waypoints.gedung80.name, 'Gedung 80 - BRIN');
      });

      test('tamanBRIN has correct name', () {
        expect(Waypoints.tamanBRIN.name, 'Taman - BRIN');
      });

      test('posSatpam has correct name', () {
        expect(Waypoints.posSatpam.name, 'Finish - BRIN');
      });

      test('all POI have valid coordinates', () {
        final pois = [
          Waypoints.gedung10,
          Waypoints.labAutonomous,
          Waypoints.gedung80,
          Waypoints.tamanBRIN,
          Waypoints.posSatpam,
        ];

        for (final poi in pois) {
          expect(poi.latitude, inInclusiveRange(-7.0, -6.5));
          expect(poi.longitude, inInclusiveRange(107.0, 108.0));
        }
      });
    });

    group('Legacy Aliases', () {
      test('start equals wp01', () {
        expect(Waypoints.start, Waypoints.wp01);
      });

      test('finalPoint equals wp33', () {
        expect(Waypoints.finalPoint, Waypoints.wp33);
      });
    });

    group('Coordinate Validation', () {
      test('all waypoints are in BRIN area', () {
        const minLat = -6.89;
        const maxLat = -6.88;
        const minLng = 107.61;
        const maxLng = 107.62;

        for (final wp in Waypoints.allWaypoints) {
          expect(wp.latitude, inInclusiveRange(minLat, maxLat),
              reason: '${wp.name} latitude out of range');
          expect(wp.longitude, inInclusiveRange(minLng, maxLng),
              reason: '${wp.name} longitude out of range');
        }
      });

      test('consecutive waypoints are relatively close', () {
        for (int i = 0; i < Waypoints.allWaypoints.length - 1; i++) {
          final current = Waypoints.allWaypoints[i];
          final next = Waypoints.allWaypoints[i + 1];

          final latDiff = (current.latitude - next.latitude).abs();
          final lngDiff = (current.longitude - next.longitude).abs();

          // Waypoints should be within ~100m of each other
          expect(latDiff, lessThan(0.001),
              reason: 'Large lat gap between ${current.name} and ${next.name}');
          expect(lngDiff, lessThan(0.001),
              reason: 'Large lng gap between ${current.name} and ${next.name}');
        }
      });
    });
  });
}
