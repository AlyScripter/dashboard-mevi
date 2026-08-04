import 'package:flutter_test/flutter_test.dart';
// import 'package:dashboardmevi/model/latlng.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('LatLng - Extended Tests', () {
    test('should create LatLng with valid coordinates', () {
      final latLng = LatLng(-6.8825, 107.6107);

      expect(latLng.latitude, -6.8825);
      expect(latLng.longitude, 107.6107);
    });

    test('should handle BRIN coordinates', () {
      final latLng = LatLng(-6.882577704450938, 107.6107211528497);

      expect(latLng.latitude, -6.882577704450938);
      expect(latLng.longitude, 107.6107211528497);
    });

    test('should handle zero coordinates', () {
      final latLng = LatLng(0.0, 0.0);

      expect(latLng.latitude, 0.0);
      expect(latLng.longitude, 0.0);
    });

    test('should handle extreme coordinates', () {
      final north = LatLng(90.0, 0.0);
      final south = LatLng(-90.0, 0.0);
      final east = LatLng(0.0, 180.0);
      final west = LatLng(0.0, -180.0);

      expect(north.latitude, 90.0);
      expect(south.latitude, -90.0);
      expect(east.longitude, 180.0);
      expect(west.longitude, -180.0);
    });

    test('should compare LatLng instances (different objects)', () {
      final latLng1 = LatLng(-6.8825, 107.6107);
      final latLng2 = LatLng(-6.8825, 107.6107);

      // Since LatLng doesn't override ==, these are different instances
      expect(identical(latLng1, latLng2), false);
    });

    test('should have consistent properties for same coordinates', () {
      final latLng1 = LatLng(-6.8825, 107.6107);
      final latLng2 = LatLng(-6.8825, 107.6107);

      expect(latLng1.latitude, latLng2.latitude);
      expect(latLng1.longitude, latLng2.longitude);
    });

    test('should have different properties for different coordinates', () {
      final latLng1 = LatLng(-6.8825, 107.6107);
      final latLng2 = LatLng(-6.8826, 107.6108);

      expect(latLng1.latitude != latLng2.latitude, true);
      expect(latLng1.longitude != latLng2.longitude, true);
    });

    test('should have proper default toString representation', () {
      final latLng = LatLng(-6.8825, 107.6107);
      final str = latLng.toString();

      // Default Object toString shows Instance of 'LatLng'
      expect(str, contains('LatLng'));
    });

    test('should handle high precision coordinates', () {
      final latLng = LatLng(
        -6.882577704450938123456789,
        107.610721152849712345678,
      );

      expect(latLng.latitude, closeTo(-6.882577704450938, 0.000000001));
      expect(latLng.longitude, closeTo(107.6107211528497, 0.000000001));
    });

    test('should create multiple distinct instances', () {
      final waypoints = [
        LatLng(-6.8825, 107.6107),
        LatLng(-6.8826, 107.6108),
        LatLng(-6.8827, 107.6109),
      ];

      expect(waypoints.length, 3);
      expect(waypoints[0] != waypoints[1], true);
      expect(waypoints[1] != waypoints[2], true);
    });
  });
}
