import 'package:flutter_test/flutter_test.dart';
import 'package:dashboardmevi/model/location.dart';

void main() {
  group('Location', () {
    test('should create Location', () {
      final location = Location(
        latitude: -6.8825,
        longitude: 107.6107,
        name: 'Test Location',
      );

      expect(location.latitude, -6.8825);
      expect(location.longitude, 107.6107);
      expect(location.name, 'Test Location');
    });

    test('should create Location from json', () {
      final json = {
        'geometry': {
          'coordinates': [107.6107, -6.8825],
        },
        'place_name': 'Test Location',
      };

      final location = Location.fromJson(json);

      expect(location.latitude, -6.8825);
      expect(location.longitude, 107.6107);
      expect(location.name, 'Test Location');
    });

    test('should handle missing place_name in json', () {
      final json = {
        'geometry': {
          'coordinates': [107.6107, -6.8825],
        },
      };

      final location = Location.fromJson(json);

      expect(location.name, 'Unknown Location');
    });

    test('should convert Location to json', () {
      final location = Location(
        latitude: -6.8825,
        longitude: 107.6107,
        name: 'Test Location',
      );

      final json = location.toJson();

      expect(json['name'], 'Test Location');
      expect(json['latitude'], -6.8825);
      expect(json['longitude'], 107.6107);
    });

    test('should return correct toString', () {
      final location = Location(
        latitude: -6.8825,
        longitude: 107.6107,
        name: 'Test Location',
      );

      final str = location.toString();

      expect(str, contains('Test Location'));
      expect(str, contains('-6.8825'));
      expect(str, contains('107.6107'));
    });

    test('should copy with new values', () {
      final location = Location(
        latitude: -6.8825,
        longitude: 107.6107,
        name: 'Test Location',
      );

      final newLocation = location.copyWith(name: 'New Location');

      expect(newLocation.name, 'New Location');
      expect(newLocation.latitude, -6.8825);
      expect(newLocation.longitude, 107.6107);
    });

    test('should copy with same values when no parameters provided', () {
      final location = Location(
        latitude: -6.8825,
        longitude: 107.6107,
        name: 'Test Location',
      );

      final newLocation = location.copyWith();

      expect(newLocation.name, 'Test Location');
      expect(newLocation.latitude, -6.8825);
      expect(newLocation.longitude, 107.6107);
    });
  });
}
