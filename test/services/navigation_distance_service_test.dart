import 'package:flutter_test/flutter_test.dart';
import 'package:dashboardmevi/services/navigation_distance_service.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('NavigationDistanceService', () {
    late NavigationDistanceService service;

    setUp(() {
      service = NavigationDistanceService();
      service.clearNavigation(); // Reset state
    });

    test('is singleton', () {
      final service1 = NavigationDistanceService();
      final service2 = NavigationDistanceService();
      expect(identical(service1, service2), isTrue);
    });

    test('initial state is empty', () {
      service.clearNavigation();

      expect(service.remainingDistance, isNull);
      expect(service.totalDistance, isNull);
      expect(service.progressPercentage, isNull);
    });

    test('updateRoute calculates total distance', () {
      // Arrange
      final route = [
        LatLng(-6.88, 107.61),
        LatLng(-6.89, 107.62),
        LatLng(-6.90, 107.63),
      ];
      final destination = LatLng(-6.90, 107.63);

      // Act
      service.updateRoute(
        routePoints: route,
        destination: destination,
        currentPosition: route.first,
      );

      // Assert
      expect(service.totalDistance, isNotNull);
      expect(service.totalDistance, greaterThan(0));
    });

    test('updateCurrentPosition updates remaining distance', () {
      // Arrange
      final route = [
        LatLng(-6.88, 107.61),
        LatLng(-6.89, 107.62),
        LatLng(-6.90, 107.63),
      ];
      service.updateRoute(
        routePoints: route,
        destination: route.last,
        currentPosition: route.first,
      );
      final initialDistance = service.remainingDistance;

      // Act
      service.updateCurrentPosition(route[1]);

      // Assert
      expect(service.remainingDistance, isNotNull);
      expect(service.remainingDistance, lessThan(initialDistance!));
    });

    test('progressPercentage calculates correctly', () {
      // Arrange
      final route = [
        LatLng(-6.88, 107.61),
        LatLng(-6.89, 107.62),
        LatLng(-6.90, 107.63),
      ];
      service.updateRoute(
        routePoints: route,
        destination: route.last,
        currentPosition: route.first,
      );

      // Act - move to middle
      service.updateCurrentPosition(route[1]);

      // Assert
      expect(service.progressPercentage, isNotNull);
      expect(service.progressPercentage, greaterThan(0));
      expect(service.progressPercentage, lessThan(100));
    });

    test('progressPercentage is null when no route', () {
      expect(service.progressPercentage, isNull);
    });

    test('clearNavigation resets all data', () {
      // Arrange
      final route = [LatLng(-6.88, 107.61), LatLng(-6.89, 107.62)];
      service.updateRoute(
        routePoints: route,
        destination: route.last,
        currentPosition: route.first,
      );

      // Act
      service.clearNavigation();

      // Assert
      expect(service.remainingDistance, isNull);
      expect(service.totalDistance, isNull);
      expect(service.progressPercentage, isNull);
    });

    test('onDistanceUpdate callback is triggered', () {
      // Arrange
      double? callbackDistance;
      service.onDistanceUpdate = (distance) {
        callbackDistance = distance;
      };

      final route = [LatLng(-6.88, 107.61), LatLng(-6.89, 107.62)];

      // Act
      service.updateRoute(
        routePoints: route,
        destination: route.last,
        currentPosition: route.first,
      );

      // Assert
      expect(callbackDistance, isNotNull);
      expect(callbackDistance, greaterThan(0));
    });

    test('updateCurrentPosition triggers callback', () {
      // Arrange
      final route = [LatLng(-6.88, 107.61), LatLng(-6.89, 107.62)];
      service.updateRoute(
        routePoints: route,
        destination: route.last,
        currentPosition: route.first,
      );

      double? callbackDistance;
      service.onDistanceUpdate = (distance) {
        callbackDistance = distance;
      };

      // Act
      service.updateCurrentPosition(LatLng(-6.885, 107.615));

      // Assert
      expect(callbackDistance, isNotNull);
    });

    test('notifyListeners is called on updateRoute', () {
      // Arrange
      var listenerCalled = false;
      service.addListener(() {
        listenerCalled = true;
      });

      final route = [LatLng(-6.88, 107.61), LatLng(-6.89, 107.62)];

      // Act
      service.updateRoute(
        routePoints: route,
        destination: route.last,
        currentPosition: route.first,
      );

      // Assert
      expect(listenerCalled, isTrue);
    });

    test('notifyListeners is called on updateCurrentPosition', () {
      // Arrange
      final route = [LatLng(-6.88, 107.61), LatLng(-6.89, 107.62)];
      service.updateRoute(
        routePoints: route,
        destination: route.last,
        currentPosition: route.first,
      );

      var listenerCalled = false;
      service.addListener(() {
        listenerCalled = true;
      });

      // Act
      service.updateCurrentPosition(LatLng(-6.885, 107.615));

      // Assert
      expect(listenerCalled, isTrue);
    });

    test('notifyListeners is called on clearNavigation', () {
      // Arrange
      var listenerCalled = false;
      service.addListener(() {
        listenerCalled = true;
      });

      // Act
      service.clearNavigation();

      // Assert
      expect(listenerCalled, isTrue);
    });

    test('calculates direct distance when no route points', () {
      // Arrange
      final start = LatLng(-6.88, 107.61);
      final destination = LatLng(-6.89, 107.62);

      // Act
      service.updateRoute(
        routePoints: [],
        destination: destination,
        currentPosition: start,
      );

      // Assert
      expect(service.remainingDistance, isNotNull);
      expect(service.remainingDistance, greaterThan(0));
    });

    test('remaining distance decreases as moving along route', () {
      // Arrange
      final route = [
        LatLng(-6.880, 107.610),
        LatLng(-6.885, 107.615),
        LatLng(-6.890, 107.620),
        LatLng(-6.895, 107.625),
      ];

      service.updateRoute(
        routePoints: route,
        destination: route.last,
        currentPosition: route[0],
      );
      final distance1 = service.remainingDistance!;

      // Act & Assert - Move to point 1
      service.updateCurrentPosition(route[1]);
      final distance2 = service.remainingDistance!;
      expect(distance2, lessThan(distance1));

      // Act & Assert - Move to point 2
      service.updateCurrentPosition(route[2]);
      final distance3 = service.remainingDistance!;
      expect(distance3, lessThan(distance2));
    });

    test('handles null current position gracefully', () {
      // Arrange
      final route = [LatLng(-6.88, 107.61), LatLng(-6.89, 107.62)];

      // Act
      service.updateRoute(
        routePoints: route,
        destination: route.last,
        currentPosition: null,
      );

      // Assert
      expect(service.remainingDistance, isNull);
    });

    test('progressPercentage approaches 100 near destination', () {
      // Arrange
      final route = [
        LatLng(-6.880, 107.610),
        LatLng(-6.885, 107.615),
        LatLng(-6.890, 107.620),
      ];

      service.updateRoute(
        routePoints: route,
        destination: route.last,
        currentPosition: route.first,
      );

      // Act - Move very close to destination
      service.updateCurrentPosition(LatLng(-6.8899, 107.6199));

      // Assert
      expect(service.progressPercentage, greaterThan(90));
    });

    test('totalDistance is sum of all route segments', () {
      // Arrange
      final route = [
        LatLng(-6.88, 107.61),
        LatLng(-6.89, 107.62),
        LatLng(-6.90, 107.63),
      ];

      // Act
      service.updateRoute(
        routePoints: route,
        destination: route.last,
        currentPosition: route.first,
      );

      // Assert
      expect(service.totalDistance, isNotNull);
      expect(service.totalDistance, greaterThan(0));
      // Total should be greater than any single segment
      expect(service.totalDistance, greaterThan(1)); // ~1km+ for this route
    });

    test('remaining distance equals total at start', () {
      // Arrange
      final route = [
        LatLng(-6.88, 107.61),
        LatLng(-6.89, 107.62),
        LatLng(-6.90, 107.63),
      ];

      // Act
      service.updateRoute(
        routePoints: route,
        destination: route.last,
        currentPosition: route.first,
      );

      // Assert
      expect(service.remainingDistance, isNotNull);
      expect(service.totalDistance, isNotNull);
      // Should be approximately equal (within tolerance for route calculation)
      final difference = (service.totalDistance! - service.remainingDistance!)
          .abs();
      expect(difference, lessThan(0.5)); // Within 500m
    });
  });
}
