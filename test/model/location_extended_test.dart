import 'package:flutter_test/flutter_test.dart';
import 'package:dashboardmevi/model/location.dart';

void main() {
  group('Location - Extended Tests', () {
    test('should create Location with all fields', () {
      final location = Location(
        name: 'Test Location',
        latitude: -6.8825,
        longitude: 107.6107,
      );

      expect(location.name, 'Test Location');
      expect(location.latitude, -6.8825);
      expect(location.longitude, 107.6107);
    });

    test('should handle BRIN locations', () {
      final location = Location(
        name: 'BRIN Main Gate',
        latitude: -6.882577704450938,
        longitude: 107.6107211528497,
      );

      expect(location.name, 'BRIN Main Gate');
      expect(location.latitude, -6.882577704450938);
      expect(location.longitude, 107.6107211528497);
    });

    test('should create Location with empty name', () {
      final location = Location(
        name: '',
        latitude: -6.8825,
        longitude: 107.6107,
      );

      expect(location.name, '');
      expect(location.latitude, -6.8825);
    });

    test('should create Location with long descriptive name', () {
      final location = Location(
        name: 'Gedung Riset dan Teknologi BRIN Bandung - Pos Satpam Gerbang Utama',
        latitude: -6.8825,
        longitude: 107.6107,
      );

      expect(location.name.length, greaterThan(50));
    });

    test('should handle special characters in name', () {
      final location = Location(
        name: 'Point @ #1 (Test)',
        latitude: -6.8825,
        longitude: 107.6107,
      );

      expect(location.name, contains('@'));
      expect(location.name, contains('#'));
      expect(location.name, contains('('));
    });

    test('should compare Location instances (different objects)', () {
      final loc1 = Location(
        name: 'Test',
        latitude: -6.8825,
        longitude: 107.6107,
      );

      final loc2 = Location(
        name: 'Test',
        latitude: -6.8825,
        longitude: 107.6107,
      );

      // Since Location doesn't override ==, these are different instances
      expect(identical(loc1, loc2), false);
    });

    test('same properties should have matching values', () {
      final loc1 = Location(
        name: 'Test',
        latitude: -6.8825,
        longitude: 107.6107,
      );

      final loc2 = Location(
        name: 'Test',
        latitude: -6.8825,
        longitude: 107.6107,
      );

      expect(loc1.name, loc2.name);
      expect(loc1.latitude, loc2.latitude);
      expect(loc1.longitude, loc2.longitude);
    });

    test('different names should have different property values', () {
      final loc1 = Location(
        name: 'Location A',
        latitude: -6.8825,
        longitude: 107.6107,
      );

      final loc2 = Location(
        name: 'Location B',
        latitude: -6.8825,
        longitude: 107.6107,
      );

      expect(loc1.name != loc2.name, true);
    });

    test('different coordinates should have different property values', () {
      final loc1 = Location(
        name: 'Test',
        latitude: -6.8825,
        longitude: 107.6107,
      );

      final loc2 = Location(
        name: 'Test',
        latitude: -6.8826,
        longitude: 107.6108,
      );

      expect(loc1.latitude != loc2.latitude, true);
      expect(loc1.longitude != loc2.longitude, true);
    });

    test('should have consistent properties', () {
      final loc1 = Location(
        name: 'Test',
        latitude: -6.8825,
        longitude: 107.6107,
      );

      final loc2 = Location(
        name: 'Test',
        latitude: -6.8825,
        longitude: 107.6107,
      );

      expect(loc1.name, loc2.name);
      expect(loc1.latitude, loc2.latitude);
      expect(loc1.longitude, loc2.longitude);
    });

    test('should have proper toString representation', () {
      final location = Location(
        name: 'BRIN',
        latitude: -6.8825,
        longitude: 107.6107,
      );

      final str = location.toString();
      expect(str, contains('BRIN'));
      expect(str, contains('-6.8825'));
      expect(str, contains('107.6107'));
    });

    test('should handle zero coordinates', () {
      final location = Location(
        name: 'Equator Prime Meridian',
        latitude: 0.0,
        longitude: 0.0,
      );

      expect(location.latitude, 0.0);
      expect(location.longitude, 0.0);
    });

    test('should handle negative coordinates', () {
      final location = Location(
        name: 'Southern Hemisphere',
        latitude: -45.0,
        longitude: -90.0,
      );

      expect(location.latitude, -45.0);
      expect(location.longitude, -90.0);
    });

    test('should handle positive coordinates', () {
      final location = Location(
        name: 'Northern Hemisphere',
        latitude: 45.0,
        longitude: 90.0,
      );

      expect(location.latitude, 45.0);
      expect(location.longitude, 90.0);
    });

    test('should create list of unique Locations', () {
      final locations = [
        Location(name: 'A', latitude: -6.882, longitude: 107.610),
        Location(name: 'B', latitude: -6.883, longitude: 107.611),
        Location(name: 'C', latitude: -6.884, longitude: 107.612),
      ];

      expect(locations.length, 3);
      expect(locations.toSet().length, 3); // All unique
    });

    test('should handle const Locations', () {
      const location1 = Location(
        name: 'Const Location',
        latitude: -6.8825,
        longitude: 107.6107,
      );

      const location2 = Location(
        name: 'Const Location',
        latitude: -6.8825,
        longitude: 107.6107,
      );

      expect(identical(location1, location2), true);
    });
  });
}
