import 'package:flutter_test/flutter_test.dart';
import 'package:dashboardmevi/model/response_route.dart';

void main() {
  group('RouteResponse', () {
    test('should create RouteResponse with all fields', () {
      final coordinates = [
        [107.6107, -6.8825],
        [107.6108, -6.8826],
        [107.6109, -6.8827],
      ];

      final response = RouteResponse(
        coordinates: coordinates,
        distance: '1.5 km',
        duration: '5 minutes',
      );

      expect(response.coordinates.length, 3);
      expect(response.coordinates[0][0], 107.6107);
      expect(response.coordinates[2][1], -6.8827);
      expect(response.distance, '1.5 km');
      expect(response.duration, '5 minutes');
    });

    test('should handle empty coordinates', () {
      final response = RouteResponse(
        coordinates: [],
        distance: '0 km',
        duration: '0 minutes',
      );

      expect(response.coordinates, isEmpty);
      expect(response.distance, '0 km');
      expect(response.duration, '0 minutes');
    });

    test('should handle single coordinate', () {
      final response = RouteResponse(
        coordinates: [
          [107.6107, -6.8825],
        ],
        distance: '0.1 km',
        duration: '1 minute',
      );

      expect(response.coordinates.length, 1);
      expect(response.coordinates[0][0], 107.6107);
      expect(response.coordinates[0][1], -6.8825);
    });

    test('should store numeric distance and duration', () {
      final response = RouteResponse(
        coordinates: [
          [107.6107, -6.8825],
          [107.6108, -6.8826],
        ],
        distance: '0.5',
        duration: '3',
      );

      expect(response.distance, '0.5');
      expect(response.duration, '3');
    });

    test('should handle long route with many coordinates', () {
      final coordinates = List.generate(
        100,
        (i) => [107.6107 + i * 0.0001, -6.8825 - i * 0.0001],
      );

      final response = RouteResponse(
        coordinates: coordinates,
        distance: '15.2 km',
        duration: '25 minutes',
      );

      expect(response.coordinates.length, 100);
      expect(response.coordinates.first[0], 107.6107);
      expect(response.coordinates.last[0], closeTo(107.6206, 0.001));
    });
  });
}
