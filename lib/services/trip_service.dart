import 'dart:io';
import 'package:flutter/foundation.dart';
import '../data/locations_data.dart';
import '../model/location.dart';
import '../services/ros_service.dart';

class TripService {
  /// Send trip waypoints directly to ROS navigation node (No Firebase!)
  /// The waypoints are sent via rosbridge to cbf_navigation_ros.py
  static Future<bool> startTrip(String tripName) async {
    try {
      final trip = LocationsData.findTripByDestination(tripName);
      if (trip == null) {
        debugPrint('⚠️ Trip not found: $tripName');
        return false;
      }

      debugPrint('=' * 60);
      debugPrint('🚗 STARTING TRIP: $tripName');
      debugPrint('📍 Destination: ${trip.destination.name}');
      debugPrint('🗺️  Waypoints: ${trip.waypoints.length}');
      debugPrint('⏱️  Estimated duration: ${trip.estimatedDuration} minutes');
      debugPrint('=' * 60);

      // Get ROS service instance
      final rosService = RosService();

      // Check if connected to ROS
      if (!rosService.isConnected) {
        debugPrint(
          '⚠️ Not connected to ROS Bridge, attempting to initialize...',
        );
        // Try to initialize if not already connected
        await rosService.initialize();

        // Wait a bit for connection
        await Future.delayed(const Duration(milliseconds: 500));

        if (!rosService.isConnected) {
          debugPrint('❌ Failed to connect to ROS Bridge');
          return false;
        }
      }

      // Prepare waypoints array for ROS (format expected by cbf_navigation_ros.py)
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

      // Convert trip to JSON format for complete trip data
      final tripJson = LocationsData.getTripAsJson(tripName);

      // Verify connection before sending
      if (!rosService.isConnected) {
        debugPrint('❌ Still not connected to ROS after initialization');
        return false;
      }

      debugPrint('✅ ROS Connected - Sending navigation data...');

      // Send waypoints array to ROS
      debugPrint('📤 [1/4] Sending waypoints to ROS...');
      rosService.publishWaypoints(waypointsArray);
      await Future.delayed(const Duration(milliseconds: 100));

      // Send complete trip data to ROS
      debugPrint('📤 [2/4] Sending trip data to ROS...');
      rosService.publishTripData(tripJson);
      await Future.delayed(const Duration(milliseconds: 100));

      // Send destination coordinates
      debugPrint('📤 [3/4] Sending destination coordinates to ROS...');
      rosService.publishDestinationCoordinates(
        trip.destination.latitude,
        trip.destination.longitude,
      );
      await Future.delayed(const Duration(milliseconds: 100));

      // Send start navigation command
      debugPrint('📤 [4/4] Sending START command to ROS...');
      rosService.publishNavigationCommand('start');

      // Also write to file for backup/compatibility
      await _publishToROSTopic('/destination_coordinate', {
        'x': trip.destination.latitude,
        'y': trip.destination.longitude,
        'z': 0.0,
      });

      debugPrint('✅ Trip started successfully - All data sent to vehicle');
      debugPrint('🚗 Vehicle should now navigate to: ${trip.destination.name}');
      debugPrint('📍 Waypoints sent: ${waypointsArray.length}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to start trip: $e');
      return false;
    }
  }

  /// Stop current trip
  static Future<bool> stopTrip() async {
    try {
      final rosService = RosService();

      // Send stop command via ROS
      rosService.publishNavigationCommand('stop');

      // Also send via file system for compatibility
      await _sendTripControl('stop');

      debugPrint('🛑 Trip stopped');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to stop trip: $e');
      return false;
    }
  }

  /// Pause current trip
  static Future<bool> pauseTrip() async {
    try {
      final rosService = RosService();
      rosService.publishNavigationCommand('pause');
      debugPrint('⏸️ Trip paused');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to pause trip: $e');
      return false;
    }
  }

  /// Resume current trip
  static Future<bool> resumeTrip() async {
    try {
      final rosService = RosService();
      rosService.publishNavigationCommand('resume');
      debugPrint('▶️ Trip resumed');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to resume trip: $e');
      return false;
    }
  }

  /// Send trip control commands to ROS
  static Future<void> _sendTripControl(String command) async {
    try {
      await _publishToROSTopic('/journey_control', {'data': command});
    } catch (e) {
      debugPrint('⚠️ Could not send ROS command: $e');
      rethrow;
    }
  }

  /// Publish message to ROS topic via file communication
  static Future<void> _publishToROSTopic(
    String topic,
    Map<String, dynamic> message,
  ) async {
    try {
      // Use file-based communication
      if (topic == '/journey_control') {
        final file = File('/tmp/flutter_ros_command.txt');
        await file.writeAsString(
          '$topic:${message['data']}\n${DateTime.now().toIso8601String()}',
        );
        debugPrint('✅ Command written to file: $topic = ${message['data']}');
      } else if (topic == '/destination_coordinate') {
        final file = File('/tmp/flutter_destination.txt');
        await file.writeAsString(
          '${message['x']},${message['y']},${message['z']}\n${DateTime.now().toIso8601String()}',
        );
        debugPrint(
          '✅ Destination written to file: ${message['x']}, ${message['y']}',
        );
      } else if (topic == '/reload_waypoints') {
        final file = File('/tmp/flutter_reload_signal.txt');
        await file.writeAsString(
          '${message['data']}\n${DateTime.now().toIso8601String()}',
        );
        debugPrint('✅ Reload signal written to file');
      }
    } catch (e) {
      debugPrint('❌ Failed to write command file: $e');
      rethrow;
    }
  }

  /// Send destination coordinates to ROS
  static Future<bool> sendDestinationToROS(Location destination) async {
    try {
      // Send via file system (for compatibility)
      await _publishToROSTopic('/destination_coordinate', {
        'x': destination.latitude,
        'y': destination.longitude,
        'z': 0.0,
      });

      // Also send via ROS service
      final rosService = RosService();
      rosService.publishDestinationCoordinates(
        destination.latitude,
        destination.longitude,
      );

      debugPrint('📍 Sent destination to ROS: ${destination.name}');
      debugPrint(
        '🗺️  Coordinates: (${destination.latitude}, ${destination.longitude})',
      );

      return true;
    } catch (e) {
      debugPrint('❌ Failed to send destination to ROS: $e');
      return false;
    }
  }
}
