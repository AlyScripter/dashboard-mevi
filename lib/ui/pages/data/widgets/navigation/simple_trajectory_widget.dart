import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:async';
import '../../../../../services/ros_service.dart';
import '../../../../../services/waypoint_service.dart';
import '../../../../../model/waypoint.dart';
import '../../../../../data/locations_data.dart';

// Map dependencies (using existing resources)
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../config/map_config.dart';
import '../../../../shared/fallback_tile_layer.dart';

/// MPC Trajectory Point dengan metadata lengkap
class MPCTrajectoryPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double speed; // km/h
  final double heading; // degrees
  final double pathDeviation; // meters from reference
  final double curvature; // path curvature
  final bool isSafe; // CBF safety status
  final double leftBoundaryDistance; // distance to left boundary
  final double rightBoundaryDistance; // distance to right boundary

  MPCTrajectoryPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.speed,
    required this.heading,
    required this.pathDeviation,
    this.curvature = 0.0,
    this.isSafe = true,
    this.leftBoundaryDistance = double.infinity,
    this.rightBoundaryDistance = double.infinity,
  });

  /// Convert to Location for compatibility
  Location toLocation() {
    return Location(
      name: 'mpc_${timestamp.millisecondsSinceEpoch}',
      latitude: latitude,
      longitude: longitude,
    );
  }
}

/// CBF Violation Point untuk tracking keamanan
class CBFViolationPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double violationDistance; // how close to boundary
  final String boundaryType; // 'left' or 'right'
  final double severity; // 0.0 (safe) to 1.0 (critical)

  CBFViolationPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.violationDistance,
    required this.boundaryType,
    required this.severity,
  });
}

/// ROS 1 Integration Trajectory Widget
/// Uses data from dummy_sensor_publishers.py and BRIN waypoint mission
class ROSTrajectoryWidget extends StatefulWidget {
  const ROSTrajectoryWidget({super.key});

  @override
  State<ROSTrajectoryWidget> createState() => _ROSTrajectoryWidgetState();
}

class _ROSTrajectoryWidgetState extends State<ROSTrajectoryWidget>
    with TickerProviderStateMixin {
  final RosService _rosService = RosService();
  late AnimationController _animationController;
  late AnimationController _pulseController;

  // Stream subscriptions untuk ROS topics
  StreamSubscription? _gpsSubscription;
  StreamSubscription? _speedSubscription;
  StreamSubscription? _ultrasonicSubscription;

  // Vehicle state dari ROS topics
  double _currentLat = -6.881270131388471;
  double _currentLon = 107.6113890776042;
  double _currentSpeed = 0.0;
  double _ultrasonicDistance = 0.0;
  double _safetyLevel = 1.0;

  // MPC Trajectory History - STATIC agar persist saat pindah halaman
  static final List<MPCTrajectoryPoint> _trajectoryHistory = [];
  final List<Location> _referencePath = [];
  static const int _maxHistoryPoints = 200; // Increased buffer

  // CBF Safety Analysis - STATIC agar persist
  static final List<CBFViolationPoint> _cbfViolations = [];

  // Path tracking metrics
  double _cumulativePathError = 0.0;
  int _pathErrorSamples = 0;
  double _averagePathError = 0.0;

  // Waypoint mission data
  WaypointMission? _waypointMission;
  List<Location> _defaultWaypoints = [];
  CBFBoundary? _cbfBoundary;

  // Status
  bool _isJourneyActive = false;

  // Trip tracking
  bool _tripInProgress = false;
  int _currentWaypointIndex = 0;
  final List<Location> _currentTripPath = [];
  final List<List<Location>> _completedTrips = []; // Store completed trips only
  double _pathDeviation = 0.0; // Distance from reference path in meters

  // Visualization mode
  bool _useMapView = false;
  final bool _realtimeUpdate = true;
  Timer? _realtimeTimer;

  // Zoom and pan controls for custom view
  double _zoomLevel = 1.0;
  Offset _panOffset = Offset.zero;
  static const double _minZoom = 0.1;
  static const double _maxZoom = 5.0;
  double _lastScale = 1.0;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupROSListeners();
    _loadWaypointMission();
    _startRealtimeUpdates();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _realtimeTimer?.cancel();
    _gpsSubscription?.cancel();
    _speedSubscription?.cancel();
    _ultrasonicSubscription?.cancel();
    super.dispose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  void _setupROSListeners() {
    // Listen to GPS data from /latitude and /longitude topics
    _gpsSubscription = _rosService.gpsStream.listen((gpsData) {
      if (mounted) {
        setState(() {
          _currentLat = gpsData['lat'] ?? _currentLat;
          _currentLon = gpsData['lng'] ?? _currentLon;

          // Create new MPC trajectory point dengan metadata lengkap
          final newTrajectoryPoint = _createTrajectoryPoint();

          // Add to trajectory history dengan buffer management
          _addToTrajectoryHistory(newTrajectoryPoint);

          // Track current trip if vehicle is moving
          if (_isJourneyActive) {
            _currentTripPath.add(newTrajectoryPoint.toLocation());
            _checkWaypointProgress();
          }
        });
      }
    });

    // Listen to speed data from /speedometer topic (already in km/h)
    _speedSubscription = _rosService.speedometerRosStream.listen((speed) {
      if (mounted) {
        setState(() {
          _currentSpeed = speed;
          bool wasActive = _isJourneyActive;
          _isJourneyActive = speed > 1.0; // Consider moving if speed > 1 km/h

          // Trip start detection
          if (!wasActive && _isJourneyActive) {
            _startNewTrip();
          }

          // Trip end detection (stopped for a while)
          if (wasActive && !_isJourneyActive) {
            _endCurrentTrip();
          }
        });
      }
    });

    // Listen to ultrasonic data from /ultrasonic_data topic
    _ultrasonicSubscription = _rosService.ultrasonicStream.listen((distance) {
      if (mounted) {
        setState(() {
          _ultrasonicDistance = distance;
          // Calculate safety level based on ultrasonic distance
          _safetyLevel = (_ultrasonicDistance / 5.0).clamp(0.2, 1.0);
        });
      }
    });
  }

  /// Create comprehensive trajectory point dengan semua metadata MPC
  MPCTrajectoryPoint _createTrajectoryPoint() {
    final currentPos = Location(
      name: 'current',
      latitude: _currentLat,
      longitude: _currentLon,
    );

    // Calculate path deviation
    final pathDeviation = _calculatePathDeviation(currentPos);

    // Calculate boundary distances
    final boundaryDistances = _calculateBoundaryDistances(currentPos);

    // Determine safety status
    final isSafe = !_isApproachingBoundary(boundaryDistances);

    // Update cumulative path error untuk analisis
    _cumulativePathError += pathDeviation;
    _pathErrorSamples++;
    _averagePathError = _cumulativePathError / _pathErrorSamples;

    // Check for CBF violations
    if (!isSafe) {
      _recordCBFViolation(boundaryDistances);
    }

    return MPCTrajectoryPoint(
      latitude: _currentLat,
      longitude: _currentLon,
      timestamp: DateTime.now(),
      speed: _currentSpeed,
      heading: 0.0, // TODO: Get from IMU/compass
      pathDeviation: pathDeviation,
      curvature: _calculatePathCurvature(),
      isSafe: isSafe,
      leftBoundaryDistance: boundaryDistances['left']!,
      rightBoundaryDistance: boundaryDistances['right']!,
    );
  }

  /// Add trajectory point dengan intelligent buffer management
  void _addToTrajectoryHistory(MPCTrajectoryPoint point) {
    _trajectoryHistory.add(point);

    // Intelligent buffer management - keep important points
    if (_trajectoryHistory.length > _maxHistoryPoints) {
      // Remove oldest points but keep:
      // 1. Points with high path deviation
      // 2. Points with CBF violations
      // 3. Points at regular intervals untuk smoothness

      final pointsToRemove = <int>[];

      for (int i = 0; i < _trajectoryHistory.length - _maxHistoryPoints; i++) {
        final point = _trajectoryHistory[i];

        // Keep important points
        if (point.pathDeviation > 2.0 || !point.isSafe || i % 5 == 0) {
          continue;
        }

        pointsToRemove.add(i);
      }

      // Remove less important points
      for (int i = pointsToRemove.length - 1; i >= 0; i--) {
        _trajectoryHistory.removeAt(pointsToRemove[i]);
      }
    }
  }

  /// Record CBF violation untuk analysis
  void _recordCBFViolation(Map<String, double> boundaryDistances) {
    final leftDistance = boundaryDistances['left']!;
    final rightDistance = boundaryDistances['right']!;

    String boundaryType;
    double violationDistance;
    double severity;

    if (leftDistance < rightDistance) {
      boundaryType = 'left';
      violationDistance = leftDistance;
      severity = (15.0 - leftDistance) / 15.0; // Max severity at 0m
    } else {
      boundaryType = 'right';
      violationDistance = rightDistance;
      severity = (15.0 - rightDistance) / 15.0;
    }

    final violation = CBFViolationPoint(
      latitude: _currentLat,
      longitude: _currentLon,
      timestamp: DateTime.now(),
      violationDistance: violationDistance,
      boundaryType: boundaryType,
      severity: severity.clamp(0.0, 1.0),
    );

    _cbfViolations.add(violation);

    // Keep only recent violations (last 50)
    if (_cbfViolations.length > 50) {
      _cbfViolations.removeAt(0);
    }
  }

  /// Calculate path curvature for MPC analysis
  double _calculatePathCurvature() {
    if (_trajectoryHistory.length < 3) return 0.0;

    // Simple curvature calculation using last 3 points
    final p1 = _trajectoryHistory[_trajectoryHistory.length - 3];
    final p2 = _trajectoryHistory[_trajectoryHistory.length - 2];
    final p3 = _trajectoryHistory[_trajectoryHistory.length - 1];

    // Calculate angles
    final angle1 = math.atan2(
      p2.latitude - p1.latitude,
      p2.longitude - p1.longitude,
    );
    final angle2 = math.atan2(
      p3.latitude - p2.latitude,
      p3.longitude - p2.longitude,
    );

    // Curvature is change in angle over distance
    final angleChange = (angle2 - angle1).abs();
    final distance = _calculateDistance(p2.toLocation(), p3.toLocation());

    return distance > 0 ? angleChange / distance : 0.0;
  }

  Future<void> _loadWaypointMission() async {
    try {
      _waypointMission = await WaypointService.loadFromAssets();

      // Use trip data for waypoints instead of waypoint mission
      if (LocationsData.predefinedTrips.isNotEmpty) {
        final trip = LocationsData.predefinedTrips.first;
        setState(() {
          // Convert trip waypoints to Location format for consistency
          _defaultWaypoints = trip.waypoints
              .map(
                (waypoint) => Location(
                  name: waypoint.name,
                  latitude: waypoint.latitude,
                  longitude: waypoint.longitude,
                ),
              )
              .toList();
          _cbfBoundary = _waypointMission!.cbfBoundary;
        });
      } else {
        // Fallback to original waypoint service if no trip data
        setState(() {
          _defaultWaypoints = WaypointService.waypointsToLocations(
            _waypointMission!.waypoints,
          );
          _cbfBoundary = _waypointMission!.cbfBoundary;
        });
      }

      _generateReferencePath();

      if (_cbfBoundary != null) {
        print(
          'Loaded CBF boundary with ${_cbfBoundary!.leftBoundary.length} left points and ${_cbfBoundary!.rightBoundary.length} right points',
        );
      }
    } catch (e) {
      print('Error loading waypoint mission: $e');
      // Use fallback waypoints
      _waypointMission = WaypointService.getDefaultMission();

      // Use trip data for fallback as well
      if (LocationsData.predefinedTrips.isNotEmpty) {
        final trip = LocationsData.predefinedTrips.first;
        setState(() {
          _defaultWaypoints = trip.waypoints
              .map(
                (waypoint) => Location(
                  name: waypoint.name,
                  latitude: waypoint.latitude,
                  longitude: waypoint.longitude,
                ),
              )
              .toList();
          _cbfBoundary = _waypointMission!.cbfBoundary;
        });
      } else {
        setState(() {
          _defaultWaypoints = WaypointService.waypointsToLocations(
            _waypointMission!.waypoints,
          );
          _cbfBoundary = _waypointMission!.cbfBoundary;
        });
      }
      _generateReferencePath();
    }
  }

  void _startNewTrip() {
    print('Starting new trip...');
    _tripInProgress = true;
    _currentWaypointIndex = 0;
    _currentTripPath.clear();
  }

  void _endCurrentTrip() {
    if (_tripInProgress && _currentTripPath.isNotEmpty) {
      print('Ending trip with ${_currentTripPath.length} points');

      // Only save trip if it reached significant waypoints
      if (_currentWaypointIndex > 0 || _currentTripPath.length > 20) {
        _completedTrips.add(List.from(_currentTripPath));

        print('Trip saved! Total completed trips: ${_completedTrips.length}');
      }

      _tripInProgress = false;
      _currentTripPath.clear();
      _currentWaypointIndex = 0;
    }
  }

  void _checkWaypointProgress() {
    if (!_tripInProgress || _defaultWaypoints.isEmpty) return;

    final currentPos = Location(
      name: 'current',
      latitude: _currentLat,
      longitude: _currentLon,
    );

    // Calculate deviation from reference path
    _pathDeviation = _calculatePathDeviation(currentPos);

    // Monitor CBF boundary distances for safety
    final boundaryDistances = _calculateBoundaryDistances(currentPos);
    if (_isApproachingBoundary(boundaryDistances)) {
      // Trigger boundary warning (can be expanded to show visual alerts)
      print(
        'WARNING: Approaching boundary! Left: ${boundaryDistances['left']!.toStringAsFixed(1)}m, Right: ${boundaryDistances['right']!.toStringAsFixed(1)}m',
      );
    }

    // Check if we're near the next waypoint (not the last one)
    if (_currentWaypointIndex < _defaultWaypoints.length - 1) {
      final targetWaypoint = _defaultWaypoints[_currentWaypointIndex];
      final distance = _calculateDistance(currentPos, targetWaypoint);

      // If within 15 meters of intermediate waypoint, consider it reached
      if (distance < 15.0) {
        _currentWaypointIndex++;
        print(
          'Reached waypoint $_currentWaypointIndex/${_defaultWaypoints.length} (${distance.toStringAsFixed(2)}m)',
        );
      }
    }
    // Only check final waypoint if we're at the last index
    else if (_currentWaypointIndex == _defaultWaypoints.length - 1) {
      final finalWaypoint = _defaultWaypoints.last;
      final distance = _calculateDistance(currentPos, finalWaypoint);

      // Require closer distance (5 meters) for final waypoint to avoid premature completion
      if (distance < 5.0) {
        _currentWaypointIndex++;
        print(
          'Trip completed! Reached final waypoint (${distance.toStringAsFixed(2)}m).',
        );
        _endCurrentTrip();
      }
    }
  }

  double _calculatePathDeviation(Location currentPos) {
    if (_referencePath.isEmpty) return 0.0;

    // Find the closest point on reference path
    double minDistance = double.infinity;

    for (final refPoint in _referencePath) {
      final distance = _calculateDistance(currentPos, refPoint);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    return minDistance;
  }

  double _calculateDistance(Location pos1, Location pos2) {
    // Simple distance calculation in meters (approximate)
    const double earthRadius = 6371000; // meters
    final double dLat = (pos2.latitude - pos1.latitude) * (math.pi / 180);
    final double dLon = (pos2.longitude - pos1.longitude) * (math.pi / 180);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(pos1.latitude * (math.pi / 180)) *
            math.cos(pos2.latitude * (math.pi / 180)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  /// Calculate minimum distance to CBF boundaries for safety monitoring
  Map<String, double> _calculateBoundaryDistances(Location currentPos) {
    if (_cbfBoundary == null) {
      return {'left': double.infinity, 'right': double.infinity};
    }

    double minLeftDistance = double.infinity;
    double minRightDistance = double.infinity;

    // Calculate distance to left boundary (jalur 2)
    for (final boundaryPoint in _cbfBoundary!.leftBoundary) {
      final boundaryLocation = Location(
        name: 'left_boundary',
        latitude: boundaryPoint.latitude,
        longitude: boundaryPoint.longitude,
      );
      final distance = _calculateDistance(currentPos, boundaryLocation);
      if (distance < minLeftDistance) {
        minLeftDistance = distance;
      }
    }

    // Calculate distance to right boundary (jalur 3)
    for (final boundaryPoint in _cbfBoundary!.rightBoundary) {
      final boundaryLocation = Location(
        name: 'right_boundary',
        latitude: boundaryPoint.latitude,
        longitude: boundaryPoint.longitude,
      );
      final distance = _calculateDistance(currentPos, boundaryLocation);
      if (distance < minRightDistance) {
        minRightDistance = distance;
      }
    }

    return {'left': minLeftDistance, 'right': minRightDistance};
  }

  /// Check if vehicle is approaching boundary limits
  bool _isApproachingBoundary(Map<String, double> boundaryDistances) {
    const double warningDistance = 15.0; // meters
    return boundaryDistances['left']! < warningDistance ||
        boundaryDistances['right']! < warningDistance;
  }

  void _generateReferencePath() {
    // Generate reference path from predefined trip data
    _referencePath.clear();

    // Use the first predefined trip as reference path
    if (LocationsData.predefinedTrips.isEmpty) return;

    final trip = LocationsData.predefinedTrips.first;

    // Convert trip waypoints to the Location type expected by the widget
    for (final waypoint in trip.waypoints) {
      _referencePath.add(
        Location(
          name: waypoint.name,
          latitude: waypoint.latitude,
          longitude: waypoint.longitude,
        ),
      );
    }
  }

  void _startRealtimeUpdates() {
    if (_realtimeUpdate) {
      _realtimeTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        // Simulate smooth trajectory updates
        _updateTrajectorySmoothing();

        if (mounted) {
          setState(() {
            // Trigger rebuild for smooth animation
          });
        }
      });
    }
  }

  void _updateTrajectorySmoothing() {
    // Apply smoothing to trajectory history for better visualization
    if (_trajectoryHistory.length > 3) {
      final smoothedPoints = <MPCTrajectoryPoint>[];

      for (int i = 1; i < _trajectoryHistory.length - 1; i++) {
        final prev = _trajectoryHistory[i - 1];
        final current = _trajectoryHistory[i];
        final next = _trajectoryHistory[i + 1];

        // Simple smoothing using moving average
        final smoothLat =
            (prev.latitude + current.latitude + next.latitude) / 3;
        final smoothLon =
            (prev.longitude + current.longitude + next.longitude) / 3;

        // Create smoothed point preserving other data
        final smoothedPoint = MPCTrajectoryPoint(
          latitude: smoothLat,
          longitude: smoothLon,
          timestamp: current.timestamp,
          speed: current.speed,
          heading: current.heading,
          pathDeviation: current.pathDeviation,
          curvature: current.curvature,
          isSafe: current.isSafe,
          leftBoundaryDistance: current.leftBoundaryDistance,
          rightBoundaryDistance: current.rightBoundaryDistance,
        );

        smoothedPoints.add(smoothedPoint);
      }

      // Replace middle portion with smoothed data
      if (smoothedPoints.isNotEmpty && _trajectoryHistory.length > 4) {
        _trajectoryHistory.replaceRange(
          1,
          _trajectoryHistory.length - 1,
          smoothedPoints,
        );
      }
    }
  }

  void _toggleMapView() {
    setState(() {
      _useMapView = !_useMapView;
    });
  }

  void _zoomIn() {
    setState(() {
      _zoomLevel = (_zoomLevel * 1.5).clamp(_minZoom, _maxZoom);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomLevel = (_zoomLevel / 1.5).clamp(_minZoom, _maxZoom);
    });
  }

  void _resetZoom() {
    setState(() {
      _zoomLevel = 1.0;
      _panOffset = Offset.zero;
    });
  }

  Widget _buildMapView() {
    // Real map implementation using existing FlutterMap resources
    final currentPosition = LatLng(_currentLat, _currentLon);

    // Convert trajectory history to LatLng points
    final trajectoryPoints = _trajectoryHistory
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();

    final referencePoints = _referencePath
        .map((loc) => LatLng(loc.latitude, loc.longitude))
        .toList();

    final waypointPoints = _defaultWaypoints
        .map((loc) => LatLng(loc.latitude, loc.longitude))
        .toList();

    return FlutterMap(
      options: MapOptions(
        initialCenter: currentPosition,
        initialZoom: 18.0,
        maxZoom: MapConfig.maxZoom,
        minZoom: MapConfig.minZoom,
        onTap: (tapPosition, point) {
          // Allow tap to set destination
          // _rosService.publishDestination(point.latitude, point.longitude);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Destination set: ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
      children: [
        // Base map layer
        const FallbackTileLayer(),

        // Reference path polyline (green)
        if (referencePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: referencePoints,
                strokeWidth: 4.0,
                color: Colors.green.withAlpha(204),
                // pattern: StrokePattern.dotted(spacingFactor: 2),  // Removed for flutter_map 6.x compatibility
              ),
            ],
          ),

        // CBF Boundary visualization (safety corridor)
        if (_cbfBoundary != null) ...[
          // Left boundary (jalur 2) - red
          PolylineLayer(
            polylines: [
              Polyline(
                points: _cbfBoundary!.leftBoundary
                    .map((bp) => LatLng(bp.latitude, bp.longitude))
                    .toList(),
                strokeWidth: 3.0,
                color: Colors.red.withAlpha(179),
                // pattern: StrokePattern.dashed(segments: [10, 5]),  // Removed for flutter_map 6.x compatibility
              ),
            ],
          ),
          // Right boundary (jalur 3) - orange
          PolylineLayer(
            polylines: [
              Polyline(
                points: _cbfBoundary!.rightBoundary
                    .map((bp) => LatLng(bp.latitude, bp.longitude))
                    .toList(),
                strokeWidth: 3.0,
                color: Colors.orange.withAlpha(179),
                // pattern: StrokePattern.dashed(segments: [10, 5]),  // Removed for flutter_map 6.x compatibility
              ),
            ],
          ),
          // Boundary markers for visibility
          MarkerLayer(
            markers: [
              // Left boundary start marker
              if (_cbfBoundary!.leftBoundary.isNotEmpty)
                Marker(
                  width: 24,
                  height: 24,
                  point: LatLng(
                    _cbfBoundary!.leftBoundary.first.latitude,
                    _cbfBoundary!.leftBoundary.first.longitude,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.security,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              // Right boundary start marker
              if (_cbfBoundary!.rightBoundary.isNotEmpty)
                Marker(
                  width: 24,
                  height: 24,
                  point: LatLng(
                    _cbfBoundary!.rightBoundary.first.latitude,
                    _cbfBoundary!.rightBoundary.first.longitude,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.security,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ],

        // MPC trajectory path dengan color coding berdasarkan safety dan deviation
        if (trajectoryPoints.isNotEmpty) ...[
          // Safe trajectory segments (blue)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _getSafeTrajectoryPoints(),
                strokeWidth: 3.0,
                color: Colors.blue.withAlpha(204),
              ),
            ],
          ),
          // Unsafe trajectory segments (red)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _getUnsafeTrajectoryPoints(),
                strokeWidth: 4.0,
                color: Colors.red.withAlpha(230),
              ),
            ],
          ),
          // High deviation segments (yellow)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _getHighDeviationTrajectoryPoints(),
                strokeWidth: 3.0,
                color: Colors.yellow.withAlpha(204),
              ),
            ],
          ),
        ],

        // CBF violation markers
        if (_cbfViolations.isNotEmpty)
          MarkerLayer(
            markers: _cbfViolations
                .map(
                  (violation) => Marker(
                    width: 16,
                    height: 16,
                    point: LatLng(violation.latitude, violation.longitude),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(
                          (violation.severity * 255).round(),
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: const Icon(
                        Icons.warning,
                        size: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),

        // Waypoint markers with different styles for path and POI
        MarkerLayer(markers: _buildWaypointMarkers(waypointPoints)),

        // Current vehicle position with heading
        MarkerLayer(
          markers: [
            Marker(
              width: 50,
              height: 50,
              point: currentPosition,
              child: StreamBuilder<Map<String, double>>(
                stream: _rosService.imuStream,
                builder: (context, snapshot) {
                  double heading = 0.0;
                  final imu = snapshot.data;
                  if (imu != null && imu['yaw'] != null) {
                    heading = imu['yaw']!;
                  }
                  final headingRadians = heading * (math.pi / 180);

                  return Transform.rotate(
                    angle: headingRadians,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Path deviation warning
                        if (_pathDeviation > 5.0)
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.yellow.withAlpha(77),
                              shape: BoxShape.circle,
                            ),
                          ),
                        // Safety glow based on safety level
                        if (_safetyLevel < 0.5)
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.red.withAlpha(77),
                              shape: BoxShape.circle,
                            ),
                          ),
                        // Vehicle background
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _isJourneyActive
                                ? Colors.blue.shade600
                                : Colors.grey.shade600,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(77),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                        // Vehicle icon or image
                        Image.asset(
                          'assets/images/mevicar.png',
                          width: 36,
                          height: 36,
                          color: Colors.white,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.directions_car,
                              size: 30,
                              color: Colors.white,
                            );
                          },
                        ),
                        // Speed indicator ring
                        if (_currentSpeed > 0)
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.cyan.withAlpha(204),
                                width: 3,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        // Attribution
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              '© CARTO',
              onTap: () =>
                  launchUrl(Uri.parse('https://carto.com/attributions')),
            ),
            TextSourceAttribution(
              '© OpenStreetMap contributors',
              onTap: () => launchUrl(
                Uri.parse('https://www.openstreetmap.org/copyright'),
              ),
            ),
          ],
          popupBackgroundColor: Colors.white.withAlpha(204),
        ),
      ],
    );
  }

  /// Get safe trajectory points for blue line
  List<LatLng> _getSafeTrajectoryPoints() {
    return _trajectoryHistory
        .where((point) => point.isSafe && point.pathDeviation <= 3.0)
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
  }

  /// Get unsafe trajectory points for red line
  List<LatLng> _getUnsafeTrajectoryPoints() {
    return _trajectoryHistory
        .where((point) => !point.isSafe)
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
  }

  /// Get high deviation trajectory points for yellow line
  List<LatLng> _getHighDeviationTrajectoryPoints() {
    return _trajectoryHistory
        .where((point) => point.isSafe && point.pathDeviation > 3.0)
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
  }

  List<Marker> _buildWaypointMarkers(List<LatLng> waypointPoints) {
    final markers = <Marker>[];

    if (_waypointMission == null) return markers;

    for (int i = 0;
        i < _waypointMission!.waypoints.length && i < waypointPoints.length;
        i++) {
      final waypoint = _waypointMission!.waypoints[i];
      final point = waypointPoints[i];

      // Smaller, cleaner markers focused on path tracking
      final isPathWaypoint = waypoint.type == WaypointType.path;

      markers.add(
        Marker(
          width: 16,
          height: 16,
          point: point,
          child: Container(
            decoration: BoxDecoration(
              color: isPathWaypoint ? Colors.blue : Colors.orange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(51),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: isPathWaypoint
                  ? Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 8,
                      ),
                    )
                  : Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildCustomView() {
    return GestureDetector(
      onScaleStart: (details) {
        // Store initial scale when gesture starts
        _lastScale = _zoomLevel;
      },
      onScaleUpdate: (details) {
        setState(() {
          // Handle zoom with pinch gesture (more responsive)
          if (details.scale != 1.0) {
            _zoomLevel = (_lastScale * details.scale).clamp(_minZoom, _maxZoom);
          }

          // Handle pan gesture
          _panOffset += details.focalPointDelta;
        });
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_animationController, _pulseController]),
        builder: (context, child) {
          return CustomPaint(
            size: Size.infinite,
            painter: ROSTrajectoryPainter(
              currentLat: _currentLat,
              currentLon: _currentLon,
              currentSpeed: _currentSpeed,
              trajectoryHistory: _trajectoryHistory,
              referencePath: _referencePath,
              defaultWaypoints: _defaultWaypoints,
              cbfBoundary: _cbfBoundary,
              cbfViolations: _cbfViolations,
              ultrasonicDistance: _ultrasonicDistance,
              safetyLevel: _safetyLevel,
              isJourneyActive: _isJourneyActive,
              animationValue: _animationController.value,
              pulseValue: _pulseController.value,
              pathDeviation: _pathDeviation,
              averagePathError: _averagePathError,
              zoomLevel: _zoomLevel,
              panOffset: _panOffset,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Main visualization
          Expanded(
            child: Stack(
              children: [
                // Canvas untuk trajectory
                _useMapView ? _buildMapView() : _buildCustomView(),
                // Status panels
                Positioned(bottom: 16, left: 16, child: _buildControlPanel()),
                Positioned(bottom: 16, right: 16, child: _buildLegend()),
                // Zoom controls for custom view only - positioned at bottom center
                if (!_useMapView)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: _buildZoomControls(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return GestureDetector(
      onTap: _toggleMapView,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _useMapView ? LucideIcons.radar : LucideIcons.map,
              size: 18,
              color: const Color(0xFF007AFF),
            ),
            const SizedBox(width: 8),
            Text(
              _useMapView ? 'Custom View' : 'Map View',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reference Path
          _buildLegendItem('Reference', const Color(0xFF34C759)),
          const SizedBox(height: 6),
          // Actual Path
          _buildLegendItem('Actual', const Color(0xFF007AFF)),
          const SizedBox(height: 6),
          // Deviation
          _buildLegendItem('Deviation', const Color(0xFFFF9500)),
          const SizedBox(height: 6),
          // Vehicle
          _buildLegendItem('Vehicle', Colors.grey.shade700),
        ],
      ),
    );
  }

  Widget _buildZoomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildZoomButton(LucideIcons.minus, _zoomOut),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${_zoomLevel.toStringAsFixed(1)}x',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _buildZoomButton(LucideIcons.plus, _zoomIn),
          const SizedBox(width: 8),
          Container(width: 1, height: 20, color: Colors.grey.shade300),
          const SizedBox(width: 8),
          _buildZoomButton(LucideIcons.maximize2, _resetZoom),
        ],
      ),
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: Colors.grey.shade700),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Custom Painter untuk MPC Trajectory Visualization dengan CBF Safety Analysis
class ROSTrajectoryPainter extends CustomPainter {
  final double currentLat;
  final double currentLon;
  final double currentSpeed;
  final List<MPCTrajectoryPoint> trajectoryHistory;
  final List<Location> referencePath;
  final List<Location> defaultWaypoints;
  final CBFBoundary? cbfBoundary;
  final List<CBFViolationPoint> cbfViolations;
  final double ultrasonicDistance;
  final double safetyLevel;
  final bool isJourneyActive;
  final double animationValue;
  final double pulseValue;
  final double pathDeviation;
  final double averagePathError;
  final double zoomLevel;
  final Offset panOffset;

  // Coordinate transformation
  late double _scale;
  late Offset _center;
  late Size _canvasSize;

  ROSTrajectoryPainter({
    required this.currentLat,
    required this.currentLon,
    required this.currentSpeed,
    required this.trajectoryHistory,
    required this.referencePath,
    required this.defaultWaypoints,
    required this.cbfBoundary,
    required this.cbfViolations,
    required this.ultrasonicDistance,
    required this.safetyLevel,
    required this.isJourneyActive,
    required this.animationValue,
    required this.pulseValue,
    required this.pathDeviation,
    required this.averagePathError,
    required this.zoomLevel,
    required this.panOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _canvasSize = size;
    _center = Offset(size.width / 2, size.height / 2) + panOffset;
    _scale = math.min(size.width, size.height) *
        8.0 *
        zoomLevel; // Apply zoom to scale

    // Draw layers in correct order
    _drawBackground(canvas);
    _drawGrid(canvas);
    _drawReferencePath(canvas);
    _drawCBFBoundaries(canvas);
    _drawWaypoints(canvas);
    _drawMPCTrajectory(canvas);
    _drawCBFViolations(canvas);
    _drawVehicle(canvas);
    _drawMPCMetrics(canvas);
    // _drawLegendOnCanvas(canvas); // Removed - using widget legend instead
  }

  void _drawBackground(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.grey.shade50
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, _canvasSize.width, _canvasSize.height),
      paint,
    );
  }

  void _drawGrid(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.5;

    const int gridLines = 10;
    for (int i = 0; i <= gridLines; i++) {
      double x = (_canvasSize.width / gridLines) * i;
      double y = (_canvasSize.height / gridLines) * i;

      canvas.drawLine(Offset(x, 0), Offset(x, _canvasSize.height), paint);
      canvas.drawLine(Offset(0, y), Offset(_canvasSize.width, y), paint);
    }
  }

  void _drawReferencePath(Canvas canvas) {
    if (referencePath.isEmpty) return;

    final pathPaint = Paint()
      ..color = Colors.green.withAlpha(204)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final path = ui.Path();
    final points = referencePath
        .map((loc) => _gpsToCanvas(loc.latitude, loc.longitude))
        .toList();

    if (points.isNotEmpty) {
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, pathPaint);
    }
  }

  void _drawCBFBoundaries(Canvas canvas) {
    if (cbfBoundary == null) return;

    // Draw left boundary (jalur 2) - red dashed
    final leftBoundaryPaint = Paint()
      ..color = Colors.red.withAlpha(179)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final leftPath = ui.Path();
    final leftPoints = cbfBoundary!.leftBoundary
        .map((bp) => _gpsToCanvas(bp.latitude, bp.longitude))
        .toList();

    if (leftPoints.isNotEmpty) {
      leftPath.moveTo(leftPoints.first.dx, leftPoints.first.dy);
      for (int i = 1; i < leftPoints.length; i++) {
        leftPath.lineTo(leftPoints[i].dx, leftPoints[i].dy);
      }
      canvas.drawPath(leftPath, leftBoundaryPaint);

      // Draw dashed pattern manually for custom view
      for (int i = 0; i < leftPoints.length - 1; i += 2) {
        if (i + 1 < leftPoints.length) {
          canvas.drawLine(leftPoints[i], leftPoints[i + 1], leftBoundaryPaint);
        }
      }
    }

    // Draw right boundary (jalur 3) - orange dashed
    final rightBoundaryPaint = Paint()
      ..color = Colors.orange.withAlpha(179)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rightPath = ui.Path();
    final rightPoints = cbfBoundary!.rightBoundary
        .map((bp) => _gpsToCanvas(bp.latitude, bp.longitude))
        .toList();

    if (rightPoints.isNotEmpty) {
      rightPath.moveTo(rightPoints.first.dx, rightPoints.first.dy);
      for (int i = 1; i < rightPoints.length; i++) {
        rightPath.lineTo(rightPoints[i].dx, rightPoints[i].dy);
      }
      canvas.drawPath(rightPath, rightBoundaryPaint);

      // Draw dashed pattern manually for custom view
      for (int i = 0; i < rightPoints.length - 1; i += 2) {
        if (i + 1 < rightPoints.length) {
          canvas.drawLine(
            rightPoints[i],
            rightPoints[i + 1],
            rightBoundaryPaint,
          );
        }
      }
    }

    // Draw boundary start markers
    final markerPaint = Paint()..style = PaintingStyle.fill;

    // Left boundary start marker (red)
    if (leftPoints.isNotEmpty) {
      markerPaint.color = Colors.red;
      canvas.drawCircle(leftPoints.first, 4, markerPaint);

      // Border
      final borderPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(leftPoints.first, 4, borderPaint);
    }

    // Right boundary start marker (orange)
    if (rightPoints.isNotEmpty) {
      markerPaint.color = Colors.orange;
      canvas.drawCircle(rightPoints.first, 4, markerPaint);

      // Border
      final borderPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(rightPoints.first, 4, borderPaint);
    }
  }

  /// Draw MPC trajectory dengan color coding berdasarkan safety dan path deviation
  void _drawMPCTrajectory(Canvas canvas) {
    if (trajectoryHistory.length < 2) return;

    // Group trajectory points by safety status dan path deviation
    final safePoints = <Offset>[];
    final unsafePoints = <Offset>[];
    final highDeviationPoints = <Offset>[];

    for (final point in trajectoryHistory) {
      final canvasPos = _gpsToCanvas(point.latitude, point.longitude);

      if (!point.isSafe) {
        unsafePoints.add(canvasPos);
      } else if (point.pathDeviation > 3.0) {
        highDeviationPoints.add(canvasPos);
      } else {
        safePoints.add(canvasPos);
      }
    }

    // Draw safe trajectory (blue) - simple clean line
    if (safePoints.length > 1) {
      final safePaint = Paint()
        ..color = Colors.blue.withAlpha(204)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;

      final safePath = ui.Path();
      safePath.moveTo(safePoints.first.dx, safePoints.first.dy);
      for (int i = 1; i < safePoints.length; i++) {
        safePath.lineTo(safePoints[i].dx, safePoints[i].dy);
      }
      canvas.drawPath(safePath, safePaint);
    }

    // Draw high deviation trajectory (yellow) - simple clean line
    if (highDeviationPoints.length > 1) {
      final deviationPaint = Paint()
        ..color = Colors.yellow.withAlpha(230)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;

      final deviationPath = ui.Path();
      deviationPath.moveTo(
        highDeviationPoints.first.dx,
        highDeviationPoints.first.dy,
      );
      for (int i = 1; i < highDeviationPoints.length; i++) {
        deviationPath.lineTo(
          highDeviationPoints[i].dx,
          highDeviationPoints[i].dy,
        );
      }
      canvas.drawPath(deviationPath, deviationPaint);
    }

    // Draw unsafe trajectory (red) - simple clean line
    if (unsafePoints.length > 1) {
      final unsafePaint = Paint()
        ..color = Colors.red.withAlpha(230)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;

      final unsafePath = ui.Path();
      unsafePath.moveTo(unsafePoints.first.dx, unsafePoints.first.dy);
      for (int i = 1; i < unsafePoints.length; i++) {
        unsafePath.lineTo(unsafePoints[i].dx, unsafePoints[i].dy);
      }
      canvas.drawPath(unsafePath, unsafePaint);
    }

    // Draw trajectory points hanya pada interval tertentu untuk mengurangi clutter
    // Kommentar bagian ini jika tidak ingin ada points sama sekali
    /*
    final pointPaint = Paint()..style = PaintingStyle.fill;

    // Only draw points at intervals to reduce visual clutter
    for (int i = 0; i < trajectoryHistory.length; i += 5) { // Every 5th point
      final point = trajectoryHistory[i];
      final canvasPos = _gpsToCanvas(point.latitude, point.longitude);

      if (!point.isSafe) {
        pointPaint.color = Colors.red.shade800;
        canvas.drawCircle(canvasPos, 2, pointPaint);
      } else if (point.pathDeviation > 3.0) {
        pointPaint.color = Colors.yellow.shade800;
        canvas.drawCircle(canvasPos, 1.5, pointPaint);
      } else {
        pointPaint.color = Colors.blue.shade800;
        canvas.drawCircle(canvasPos, 1, pointPaint);
      }
    }
    */
  }

  /// Draw CBF violations sebagai warning indicators
  void _drawCBFViolations(Canvas canvas) {
    final violationPaint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (final violation in cbfViolations) {
      final pos = _gpsToCanvas(violation.latitude, violation.longitude);

      // Color berdasarkan severity
      violationPaint.color = Colors.red.withAlpha(
        (violation.severity * 255).round(),
      );

      final radius = 4.0 + (violation.severity * 4.0); // Size based on severity
      canvas.drawCircle(pos, radius, violationPaint);
      canvas.drawCircle(pos, radius, borderPaint);

      // Warning icon for high severity violations
      if (violation.severity > 0.7) {
        final textPainter = TextPainter(
          text: const TextSpan(
            text: '⚠',
            style: TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );

        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            pos.dx - textPainter.width / 2,
            pos.dy - textPainter.height / 2,
          ),
        );
      }
    }
  }

  /// Draw MPC performance metrics
  void _drawMPCMetrics(Canvas canvas) {
    final metricsBg = Paint()
      ..color = Colors.black.withAlpha(204)
      ..style = PaintingStyle.fill;

    // Position at top-left to avoid collision with bottom widgets
    final metricsRect = Rect.fromLTWH(10, 10, 180, 100);
    canvas.drawRRect(
      RRect.fromRectAndRadius(metricsRect, const Radius.circular(8)),
      metricsBg,
    );

    final textStyle = const TextStyle(
      color: Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );

    final headerStyle = const TextStyle(
      color: Colors.cyan,
      fontSize: 11,
      fontWeight: FontWeight.bold,
    );

    // Header
    final headerPainter = TextPainter(
      text: TextSpan(text: 'MPC Analytics', style: headerStyle),
      textDirection: TextDirection.ltr,
    );
    headerPainter.layout();
    headerPainter.paint(canvas, Offset(20, 20));

    // Metrics - compact version
    final metrics = [
      'Avg Error: ${averagePathError.toStringAsFixed(1)}m',
      'Current Dev: ${pathDeviation.toStringAsFixed(1)}m',
      'Violations: ${cbfViolations.length}',
      'Safety: ${(safetyLevel * 100).round()}%',
      'Points: ${trajectoryHistory.length}',
    ];

    for (int i = 0; i < metrics.length; i++) {
      final textPainter = TextPainter(
        text: TextSpan(text: metrics[i], style: textStyle),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(canvas, Offset(20, 40 + i * 12));
    }
  }

  void _drawWaypoints(Canvas canvas) {
    for (int i = 0; i < defaultWaypoints.length; i++) {
      final waypoint = defaultWaypoints[i];
      final pos = _gpsToCanvas(waypoint.latitude, waypoint.longitude);

      // Smaller waypoint markers - determine if path or POI
      bool isPathWaypoint =
          i < 12; // First 12 are path waypoints based on our data

      final waypointPaint = Paint()
        ..color = isPathWaypoint ? Colors.blue : Colors.orange
        ..style = PaintingStyle.fill;

      final borderPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;

      // Smaller circles
      final radius = isPathWaypoint ? 4.0 : 5.0;
      canvas.drawCircle(pos, radius, waypointPaint);
      canvas.drawCircle(pos, radius, borderPaint);

      // Smaller text for path waypoints only
      if (isPathWaypoint) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${i + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );

        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            pos.dx - textPainter.width / 2,
            pos.dy - textPainter.height / 2,
          ),
        );
      }
    }
  }

  void _drawVehicle(Canvas canvas) {
    final vehiclePos = _gpsToCanvas(currentLat, currentLon);

    // Vehicle body dengan pulsing effect
    final baseRadius = 8.0;
    final pulseRadius = baseRadius + 3 * pulseValue;

    // Path deviation warning (yellow glow if off-path)
    if (pathDeviation > 5.0) {
      final deviationPaint = Paint()
        ..color = Colors.yellow.withAlpha(102)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(vehiclePos, pulseRadius + 12, deviationPaint);
    }

    // Safety glow berdasarkan safety level
    if (safetyLevel < 0.5) {
      final glowPaint = Paint()
        ..color = Colors.red.withAlpha(102)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(vehiclePos, pulseRadius + 8, glowPaint);
    }

    // Main vehicle body
    final vehiclePaint = Paint()
      ..color = isJourneyActive ? Colors.blue.shade600 : Colors.grey.shade600
      ..style = PaintingStyle.fill;

    canvas.drawCircle(vehiclePos, pulseRadius, vehiclePaint);

    // Vehicle border
    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(vehiclePos, pulseRadius, borderPaint);

    // Speed indicator ring
    if (currentSpeed > 0) {
      final speedPaint = Paint()
        ..color = Colors.cyan.withAlpha(153)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(vehiclePos, pulseRadius + 6, speedPaint);
    }

    // Draw current trajectory direction arrow
    if (trajectoryHistory.length > 1) {
      final currentPoint = trajectoryHistory.last;
      final prevPoint = trajectoryHistory[trajectoryHistory.length - 2];

      final direction = math.atan2(
        currentPoint.latitude - prevPoint.latitude,
        currentPoint.longitude - prevPoint.longitude,
      );

      _drawDirectionArrow(canvas, vehiclePos, direction + math.pi / 2);
    }
  }

  void _drawDirectionArrow(Canvas canvas, Offset position, double direction) {
    final arrowPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final arrowLength = 12.0;
    final arrowEnd = Offset(
      position.dx + arrowLength * math.cos(direction),
      position.dy + arrowLength * math.sin(direction),
    );

    // Main arrow line
    canvas.drawLine(position, arrowEnd, arrowPaint);

    // Arrow head
    final headLength = 4.0;
    final headAngle = 0.5;

    final leftWing = Offset(
      arrowEnd.dx - headLength * math.cos(direction - headAngle),
      arrowEnd.dy - headLength * math.sin(direction - headAngle),
    );

    final rightWing = Offset(
      arrowEnd.dx - headLength * math.cos(direction + headAngle),
      arrowEnd.dy - headLength * math.sin(direction + headAngle),
    );

    canvas.drawLine(arrowEnd, leftWing, arrowPaint);
    canvas.drawLine(arrowEnd, rightWing, arrowPaint);
  }

  Offset _gpsToCanvas(double lat, double lon) {
    // Simple coordinate transformation
    final deltaLat = (lat - currentLat) * _scale * 1000;
    final deltaLon = (lon - currentLon) * _scale * 1000;

    return Offset(
      _center.dx + deltaLon,
      _center.dy - deltaLat, // Flip Y-axis for proper map orientation
    );
  }

  @override
  bool shouldRepaint(covariant ROSTrajectoryPainter oldDelegate) {
    return oldDelegate.currentLat != currentLat ||
        oldDelegate.currentLon != currentLon ||
        oldDelegate.currentSpeed != currentSpeed ||
        oldDelegate.trajectoryHistory.length != trajectoryHistory.length ||
        oldDelegate.cbfViolations.length != cbfViolations.length ||
        oldDelegate.referencePath.length != referencePath.length ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.pathDeviation != pathDeviation ||
        oldDelegate.averagePathError != averagePathError ||
        oldDelegate.zoomLevel != zoomLevel ||
        oldDelegate.panOffset != panOffset;
  }
}

/// MPC Trajectory Overlay Painter untuk Map View
class TrajectoryOverlayPainter extends CustomPainter {
  final List<MPCTrajectoryPoint> trajectoryHistory;
  final double currentLat;
  final double currentLon;
  final List<Location> referencePath;
  final bool isJourneyActive;

  TrajectoryOverlayPainter({
    required this.trajectoryHistory,
    required this.currentLat,
    required this.currentLon,
    required this.referencePath,
    required this.isJourneyActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Enhanced overlay untuk map view dengan MPC trajectory analysis
    final center = Offset(size.width / 2, size.height / 2);

    // Draw current position dengan status indicator
    final vehiclePaint = Paint()
      ..color = isJourneyActive ? Colors.blue : Colors.grey
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 8, vehiclePaint);

    // Draw reference path preview
    if (referencePath.length > 1) {
      final pathPaint = Paint()
        ..color = Colors.green.withAlpha(179)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;

      final path = ui.Path();
      path.moveTo(center.dx - 100, center.dy);
      path.quadraticBezierTo(
        center.dx,
        center.dy - 50,
        center.dx + 100,
        center.dy,
      );

      canvas.drawPath(path, pathPaint);
    }

    // Draw MPC trajectory preview dengan color coding
    if (trajectoryHistory.length > 1) {
      // Safe trajectory (blue)
      final safeTrajPaint = Paint()
        ..color = Colors.blue.withAlpha(204)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      final safePath = ui.Path();
      safePath.moveTo(center.dx - 80, center.dy + 10);
      safePath.lineTo(center.dx, center.dy);

      canvas.drawPath(safePath, safeTrajPaint);

      // Unsafe segments (red) - if any violations exist
      bool hasUnsafeSegments = trajectoryHistory.any((point) => !point.isSafe);
      if (hasUnsafeSegments) {
        final unsafeTrajPaint = Paint()
          ..color = Colors.red.withAlpha(230)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;

        final unsafePath = ui.Path();
        unsafePath.moveTo(center.dx - 60, center.dy + 5);
        unsafePath.lineTo(center.dx - 20, center.dy);

        canvas.drawPath(unsafePath, unsafeTrajPaint);
      }
    }

    // Draw safety indicator ring
    if (trajectoryHistory.isNotEmpty) {
      final lastPoint = trajectoryHistory.last;
      final safetyColor = lastPoint.isSafe ? Colors.green : Colors.red;

      final safetyPaint = Paint()
        ..color = safetyColor.withAlpha(128)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(center, 12, safetyPaint);
    }
  }

  @override
  bool shouldRepaint(covariant TrajectoryOverlayPainter oldDelegate) {
    return oldDelegate.trajectoryHistory.length != trajectoryHistory.length ||
        oldDelegate.currentLat != currentLat ||
        oldDelegate.currentLon != currentLon;
  }
}
