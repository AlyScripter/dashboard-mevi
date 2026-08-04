import 'package:flutter_test/flutter_test.dart';
import 'package:dashboardmevi/services/route_data_service.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('RouteDataService', () {
    late RouteDataService service;

    setUp(() {
      service = RouteDataService();
      service.clearRoute(); // Reset state before each test
    });

    test('is singleton', () {
      final service1 = RouteDataService();
      final service2 = RouteDataService();
      expect(identical(service1, service2), isTrue);
    });

    test('initial state is empty', () {
      // Reset to ensure clean state
      service.clearRoute();

      expect(service.routePoints, isEmpty);
      expect(service.currentPosition, isNull);
      expect(service.destinationPosition, isNull);
      expect(service.nextWaypoint, isNull);
      expect(service.isNavigationActive, isFalse);
    });

    test('updateRoute sets route data correctly', () {
      // Arrange
      final route = [
        LatLng(-6.88, 107.61),
        LatLng(-6.89, 107.62),
        LatLng(-6.90, 107.63),
      ];
      final current = LatLng(-6.88, 107.61);
      final destination = LatLng(-6.90, 107.63);

      // Act
      service.updateRoute(
        routePoints: route,
        currentPosition: current,
        destinationPosition: destination,
      );

      // Assert
      expect(service.routePoints.length, 3);
      expect(service.currentPosition, current);
      expect(service.destinationPosition, destination);
      expect(service.isNavigationActive, isTrue);
    });

    test('updateCurrentPosition updates position', () {
      // Arrange
      service.loadSampleRoute();
      final newPosition = LatLng(-6.8820, 107.6117);

      // Act
      service.updateCurrentPosition(newPosition);

      // Assert
      expect(service.currentPosition, newPosition);
    });

    test('clearRoute resets all data', () {
      // Arrange
      service.loadSampleRoute();
      expect(service.isNavigationActive, isTrue);

      // Act
      service.clearRoute();

      // Assert
      expect(service.routePoints, isEmpty);
      expect(service.currentPosition, isNull);
      expect(service.destinationPosition, isNull);
      expect(service.nextWaypoint, isNull);
      expect(service.isNavigationActive, isFalse);
    });

    test('loadSampleRoute creates valid route', () {
      // Act
      service.loadSampleRoute();

      // Assert
      expect(service.routePoints.length, 6);
      expect(service.currentPosition, isNotNull);
      expect(service.destinationPosition, isNotNull);
      expect(service.isNavigationActive, isTrue);

      // Check first and last points
      final firstPoint = service.routePoints.first;
      final lastPoint = service.routePoints.last;
      expect(firstPoint.latitude, closeTo(-6.8815, 0.0001));
      expect(firstPoint.longitude, closeTo(107.6115, 0.0001));
      expect(lastPoint.latitude, closeTo(-6.8840, 0.0001));
      expect(lastPoint.longitude, closeTo(107.6129, 0.0001));
    });

    test('routePoints returns unmodifiable list', () {
      // Arrange
      service.loadSampleRoute();
      final points = service.routePoints;

      // Act & Assert
      expect(() => points.add(LatLng(0, 0)), throwsUnsupportedError);
    });

    test('updateRoute with empty list sets isNavigationActive to false', () {
      // Act
      service.updateRoute(
        routePoints: [],
        currentPosition: null,
        destinationPosition: null,
      );

      // Assert
      expect(service.isNavigationActive, isFalse);
    });

    test('notifyListeners is called on updateRoute', () {
      // Arrange
      var listenerCalled = false;
      service.addListener(() {
        listenerCalled = true;
      });

      // Act
      service.updateRoute(
        routePoints: [LatLng(-6.88, 107.61)],
        currentPosition: LatLng(-6.88, 107.61),
        destinationPosition: LatLng(-6.89, 107.62),
      );

      // Assert
      expect(listenerCalled, isTrue);
    });

    test('notifyListeners is called on updateCurrentPosition', () {
      // Arrange
      service.loadSampleRoute();
      var listenerCalled = false;
      service.addListener(() {
        listenerCalled = true;
      });

      // Act
      service.updateCurrentPosition(LatLng(-6.88, 107.61));

      // Assert
      expect(listenerCalled, isTrue);
    });

    test('notifyListeners is called on clearRoute', () {
      // Arrange
      service.loadSampleRoute();
      var listenerCalled = false;
      service.addListener(() {
        listenerCalled = true;
      });

      // Act
      service.clearRoute();

      // Assert
      expect(listenerCalled, isTrue);
    });
  });
}
