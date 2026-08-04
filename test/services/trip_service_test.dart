import 'dart:io';
import 'package:dashboardmevi/data/locations_data.dart';
import 'package:dashboardmevi/model/location.dart';
import 'package:dashboardmevi/services/trip_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TripService', () {
    // Clean up temp files before and after tests
    setUp(() async {
      await _cleanupTempFiles();
    });

    tearDown(() async {
      await _cleanupTempFiles();
    });

    group('startTrip', () {
      test('should return true when starting a valid trip', () async {
        // Act
        final result = await TripService.startTrip('Gedung 10 BRIN');

        // Assert
        expect(result, isTrue);
      });

      test('should return false when trip name is not found', () async {
        // Act
        final result = await TripService.startTrip('NonExistentTrip');

        // Assert
        expect(result, isFalse);
      });

      test('should write destination coordinates to file', () async {
        // Act
        await TripService.startTrip('Lab Autonomous BRIN');

        // Assert
        final file = File('/tmp/flutter_destination.txt');
        expect(await file.exists(), isTrue);

        final content = await file.readAsString();
        expect(content, isNotEmpty);
        expect(content, contains(',')); // Should contain lat,lng,z format
      });

      test('should handle invalid trip name', () async {
        // Act
        final result = await TripService.startTrip('Invalid Trip Name XXX');

        // Assert
        expect(result, isFalse);
      });

      test('should handle empty trip name', () async {
        // Act
        final result = await TripService.startTrip('');

        // Assert
        expect(result, isFalse);
      });
    });

    group('stopTrip', () {
      test('should return true when stopping trip', () async {
        // Act
        final result = await TripService.stopTrip();

        // Assert
        expect(result, isTrue);
      });

      test('should write stop command to file', () async {
        // Act
        await TripService.stopTrip();

        // Assert
        final file = File('/tmp/flutter_ros_command.txt');
        expect(await file.exists(), isTrue);

        final content = await file.readAsString();
        expect(content, contains('/journey_control'));
        expect(content, contains('stop'));
      });

      test('should write timestamp with stop command', () async {
        // Act
        await TripService.stopTrip();

        // Assert
        final file = File('/tmp/flutter_ros_command.txt');
        final content = await file.readAsString();

        // Check for ISO8601 timestamp format
        expect(content, contains('T'));
        expect(
          content,
          matches(RegExp(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}')),
        );
      });
    });

    group('sendDestinationToROS', () {
      test('should send destination coordinates successfully', () async {
        // Arrange
        final destination = Location(
          name: 'Test Location',
          latitude: -6.9175,
          longitude: 107.6191,
        );

        // Act
        final result = await TripService.sendDestinationToROS(destination);

        // Assert
        expect(result, isTrue);
      });

      test('should write destination to correct file', () async {
        // Arrange
        final destination = Location(
          name: 'Bandung City',
          latitude: -6.9175,
          longitude: 107.6191,
        );

        // Act
        await TripService.sendDestinationToROS(destination);

        // Assert
        final file = File('/tmp/flutter_destination.txt');
        expect(await file.exists(), isTrue);

        final content = await file.readAsString();
        expect(content, contains('-6.9175'));
        expect(content, contains('107.6191'));
      });

      test('should include z-coordinate as 0.0', () async {
        // Arrange
        final destination = Location(
          name: 'Test',
          latitude: 1.0,
          longitude: 2.0,
        );

        // Act
        await TripService.sendDestinationToROS(destination);

        // Assert
        final file = File('/tmp/flutter_destination.txt');
        final content = await file.readAsString();
        expect(content, contains(',0.0'));
      });

      test('should handle negative coordinates', () async {
        // Arrange
        final destination = Location(
          name: 'Negative Test',
          latitude: -6.9175,
          longitude: -107.6191,
        );

        // Act
        final result = await TripService.sendDestinationToROS(destination);

        // Assert
        expect(result, isTrue);
      });

      test('should include timestamp in destination file', () async {
        // Arrange
        final destination = Location(
          name: 'Timestamp Test',
          latitude: 0.0,
          longitude: 0.0,
        );

        // Act
        await TripService.sendDestinationToROS(destination);

        // Assert
        final file = File('/tmp/flutter_destination.txt');
        final content = await file.readAsString();
        expect(content, contains('T')); // ISO8601 timestamp
      });
    });

    group('Integration scenarios', () {
      test('should handle start and stop trip sequence', () async {
        // Act
        final startResult = await TripService.startTrip('Gedung 80 BRIN');
        final stopResult = await TripService.stopTrip();

        // Assert
        expect(startResult, isTrue);
        expect(stopResult, isTrue);
      });

      test('should handle multiple destination sends', () async {
        // Arrange
        final destination1 = Location(
          name: 'Dest1',
          latitude: 1.0,
          longitude: 2.0,
        );
        final destination2 = Location(
          name: 'Dest2',
          latitude: 3.0,
          longitude: 4.0,
        );

        // Act
        final result1 = await TripService.sendDestinationToROS(destination1);
        final result2 = await TripService.sendDestinationToROS(destination2);

        // Assert
        expect(result1, isTrue);
        expect(result2, isTrue);

        // Latest destination should be in the file
        final file = File('/tmp/flutter_destination.txt');
        final content = await file.readAsString();
        expect(content, contains('3.0'));
        expect(content, contains('4.0'));
      });
    });

    // Keep original LocationsData tests
    test('findTripByDestination returns null for invalid trip', () {
      final trip = LocationsData.findTripByDestination('Invalid Trip Name XXX');
      expect(trip, isNull);
    });

    test('predefinedTrips is not empty', () {
      final trips = LocationsData.predefinedTrips;
      expect(trips, isNotEmpty);
      expect(trips.length, greaterThanOrEqualTo(1));
    });

    test('first trip has valid structure', () {
      final trip = LocationsData.predefinedTrips.first;
      expect(trip.name, isNotEmpty);
      expect(trip.description, isNotEmpty);
      expect(trip.destination, isNotNull);
      expect(trip.waypoints, isNotEmpty);
      expect(trip.estimatedDuration, greaterThan(0));
    });

    test('trip has valid waypoints with coordinates', () {
      final trip = LocationsData.predefinedTrips.first;
      expect(trip.waypoints, isNotEmpty);

      final firstWaypoint = trip.waypoints.first;
      expect(firstWaypoint.latitude, isNotNull);
      expect(firstWaypoint.longitude, isNotNull);
      expect(firstWaypoint.name, isNotEmpty);

      expect(firstWaypoint.latitude, inInclusiveRange(-90, 90));
      expect(firstWaypoint.longitude, inInclusiveRange(-180, 180));
    });

    test('waypoints can be serialized to ROS format', () {
      final trip = LocationsData.predefinedTrips.first;
      final waypointsArray = trip.waypoints
          .map(
            (wp) => {
              'name': wp.name,
              'latitude': wp.latitude,
              'longitude': wp.longitude,
              'altitude': 10.0,
              'heading': 0.0,
              'type': 'waypoint',
            },
          )
          .toList();

      expect(waypointsArray, isNotEmpty);
      expect(waypointsArray.first.containsKey('name'), isTrue);
      expect(waypointsArray.first.containsKey('latitude'), isTrue);
      expect(waypointsArray.first.containsKey('longitude'), isTrue);
      expect(waypointsArray.first['altitude'], 10.0);
      expect(waypointsArray.first['type'], 'waypoint');
    });

    test('destination coordinates are valid', () {
      final trip = LocationsData.predefinedTrips.first;
      expect(trip.destination.latitude, isNotNull);
      expect(trip.destination.longitude, isNotNull);

      expect(trip.destination.latitude, inInclusiveRange(-7.0, -6.5));
      expect(trip.destination.longitude, inInclusiveRange(107.0, 108.0));
    });
  });
}

/// Helper function to clean up temp files
Future<void> _cleanupTempFiles() async {
  final files = [
    '/tmp/flutter_ros_command.txt',
    '/tmp/flutter_destination.txt',
    '/tmp/flutter_reload_signal.txt',
  ];

  for (final path in files) {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
