import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'widgets/map_view.dart';
import 'widgets/heading_hud.dart';
import 'widgets/search_bar_widget.dart';
import 'widgets/loading_indicator.dart';
import 'widgets/in_app_notification_widget.dart';
import 'widgets/center_on_car_button.dart';
import 'utils/geojson_parser.dart';
import '../../../model/location.dart';
import '../../../data/locations_data.dart';
import '../../../services/ros_service.dart';
import '../../../services/service_locator.dart';
import '../../../services/navigation/external_manager.dart';
import '../../../services/navigation/getroute_manager.dart';
import '../../../services/navigation/internal_manager.dart';
import '../../../services/notification_service.dart';
import '../../../services/route_data_service.dart';
import '../../../services/navigation_distance_service.dart';

/// Complete NavigationWidget with all functionality from the god widget
class NavigationWidget extends StatefulWidget {
  final double destinationLat;
  final double destinationLng;
  final Function(bool) onMinimizedChanged;
  final void Function(String name, double distanceKm, String eta)? onRouteInfo;
  final VoidCallback? onClearRouteInfo;
  final VoidCallback? onRouteCompleted;
  final bool simulateGps;

  const NavigationWidget({
    super.key,
    required this.destinationLat,
    required this.destinationLng,
    required this.onMinimizedChanged,
    this.onRouteInfo,
    this.onClearRouteInfo,
    this.onRouteCompleted,
    this.simulateGps = false,
  });

  @override
  State<NavigationWidget> createState() => NavigationWidgetState();
}

/// State class for NavigationWidget - made public to allow external access via GlobalKey
class NavigationWidgetState extends State<NavigationWidget> {
  final InternalRouteManager _internalRouteManager = InternalRouteManager();
  final ExternalRouteManager _externalRouteManager = ExternalRouteManager();
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  final GeoJsonRouteManager _geoJsonRouteManager = GeoJsonRouteManager();
  final RosService rosService = RosService();
  final NotificationService _notificationService = NotificationService();
  final RouteDataService _routeDataService = RouteDataService();
  final NavigationDistanceService _distanceService =
      NavigationDistanceService();

  StreamSubscription<InAppNotification>? _inAppSubscription;
  StreamSubscription<double>? _rosLatSubscription;
  StreamSubscription<double>? _rosLngSubscription;
  StreamSubscription<double>? _rosSpeedSubscription;

  // State management
  bool _isLoading = false;
  LatLng? _currentPosition;
  LatLng? _destinationLocation;
  List<LatLng> _polylinePoints = [];
  List<Location> _geoJsonLocations = [];
  final List<LatLng> _lineStringPoints = [];

  double _rotation = 0.0;
  Offset? _startOffset;
  double _startRotation = 0.0;

  Timer? _locationUpdateTimer;
  Timer? _gpsSimulatorTimer;
  int _simIndex = 0;

  // In-app notification state
  bool _showInAppNotification = false;
  String _inAppNotificationTitle = '';
  String _inAppNotificationBody = '';
  NotificationKind _inAppNotificationKind = NotificationKind.info;
  Timer? _inAppNotificationTimer;

  // simple flags to avoid spamming same notification repeatedly
  bool _arrivalNotified = false;
  // Fixed placeholder location used when GPS is unavailable. Computed once.
  LatLng? _placeholderLocation;

  @override
  void initState() {
    super.initState();
    _loadGeoJsonData();

    // Set initial placeholder but don't force static mode
    _placeholderLocation = LatLng(widget.destinationLat, widget.destinationLng);
    _currentPosition = _placeholderLocation; // Start with placeholder

    _geoJsonLocations = GeoJsonParser.parseGeoJson(geoJsonData);
    _setupRosStreams(); // Setup ROS first
    _setupNotifications();

    // Only use GPS simulator if explicitly requested
    if (widget.simulateGps) {
      _startGpsSimulator();
    }
  }

  @override
  void dispose() {
    _inAppSubscription?.cancel();
    _rosLatSubscription?.cancel();
    _rosLngSubscription?.cancel();
    _rosSpeedSubscription?.cancel();
    _locationUpdateTimer?.cancel(); // Cancel if exists
    _gpsSimulatorTimer?.cancel();
    debugPrint('🛑 NavigationWidget disposed');
    super.dispose();
  }

  void _startGpsSimulator() {
    // Simple loop of sample coordinates around Bandung area for testing
    final samplePath = <LatLng>[
      LatLng(-6.8815, 107.6115),
      LatLng(-6.8820, 107.6117),
      LatLng(-6.8825, 107.6120),
      LatLng(-6.8830, 107.6123),
      LatLng(-6.8835, 107.6126),
      LatLng(-6.8840, 107.6129),
    ];

    // Set an immediate initial position so selection won't show 'location not found'
    setState(() {
      _simIndex = 0;
      _currentPosition = samplePath.first;
      _simIndex = 1;
    });

    _gpsSimulatorTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      setState(() {
        _currentPosition = samplePath[_simIndex % samplePath.length];
        _simIndex++;
      });

      // Update route data service dengan posisi simulator
      if (_currentPosition != null) {
        _routeDataService.updateCurrentPosition(_currentPosition!);
      }
    });
  }

  void _setupRosStreams() {
    // Listen to ROS GPS latitude updates
    _rosLatSubscription = rosService.gpsStream
        .map((gps) => gps["lat"]!)
        .listen(
          (lat) {
            // The stream keeps emitting for as long as RosService is
            // alive (it's a global singleton), independent of whether
            // this widget is still on screen. Bail out if we've already
            // been disposed (e.g. user navigated away to another page)
            // so we never call setState() on a defunct State.
            if (!mounted) return;
            if (_currentPosition != null) {
              setState(() {
                _currentPosition = LatLng(lat, _currentPosition!.longitude);
              });
              debugPrint('🗺️ Updated latitude from ROS: $lat');
            } else {
              final placeholder = _getPlaceholderLocation();
              setState(() {
                _currentPosition = LatLng(lat, placeholder.longitude);
              });
              debugPrint('🗺️ Initial latitude from ROS: $lat');
            }

            // Update route data service
            if (_currentPosition != null) {
              _routeDataService.updateCurrentPosition(_currentPosition!);
              // Update distance service for real-time distance calculation
              _distanceService.updateCurrentPosition(_currentPosition!);
            }

            _checkArrival();
          },
          onError: (error) {
            debugPrint('❌ ROS Latitude stream error: $error');
          },
        );

    // Listen to ROS GPS longitude updates
    _rosLngSubscription = rosService.gpsStream
        .map((gps) => gps["lng"]!)
        .listen(
          (lon) {
            if (!mounted) return;
            if (_currentPosition != null) {
              setState(() {
                _currentPosition = LatLng(_currentPosition!.latitude, lon);
              });
              debugPrint('🗺️ Updated longitude from ROS: $lon');
            } else {
              final placeholder = _getPlaceholderLocation();
              setState(() {
                _currentPosition = LatLng(placeholder.latitude, lon);
              });
              debugPrint('🗺️ Initial longitude from ROS: $lon');
            }

            // Update route data service
            if (_currentPosition != null) {
              _routeDataService.updateCurrentPosition(_currentPosition!);
              // Update distance service for real-time distance calculation
              _distanceService.updateCurrentPosition(_currentPosition!);
            }

            _checkArrival();
          },
          onError: (error) {
            debugPrint('❌ ROS Longitude stream error: $error');
          },
        );

    // Optional: Listen to ROS speed for debugging
    _rosSpeedSubscription = rosService.speedometerRosStream.listen(
      (speed) {
        if (!mounted) return;
        debugPrint(
          '🚗 Current speed from ROS: ${speed.toStringAsFixed(1)} km/h',
        );
      },
      onError: (error) {
        debugPrint('❌ ROS Speed stream error: $error');
      },
    );
  }

  void _setupNotifications() {
    // Subscribe to global in-app notifications
    _inAppSubscription = _notificationService.inAppStream.listen((notif) {
      if (!mounted) return;
      _displayInAppNotification(
        notif.title,
        notif.body,
        seconds: notif.seconds,
      );
    });
  }

  void _displayInAppNotification(
    String title,
    String body, {
    int seconds = 5,
    NotificationKind kind = NotificationKind.info,
  }) {
    setState(() {
      _showInAppNotification = true;
      _inAppNotificationTitle = title;
      _inAppNotificationBody = body;
      _inAppNotificationKind = kind;
    });

    Timer(Duration(seconds: seconds), () {
      if (mounted) {
        setState(() {
          _showInAppNotification = false;
        });
      }
    });
  }

  void _onLocationSelected(Location location) async {
    // Check if user selected the same destination again - clear route if so
    if (_destinationLocation != null &&
        (_destinationLocation!.latitude - location.latitude).abs() < 0.0001 &&
        (_destinationLocation!.longitude - location.longitude).abs() < 0.0001) {
      _displayInAppNotification(
        'Route Cleared',
        'Navigation to ${location.name} has been cleared',
        kind: NotificationKind.info,
      );
      _clearRouteInfo();
      return;
    }

    setState(() {
      _destinationLocation = LatLng(location.latitude, location.longitude);
    });

    // Check if this is Pos Satpam - trigger ROS journey
    if (location.name.contains("Pos Satpam") ||
        location.name.contains("Gerbang Keluar")) {
      try {
        debugPrint(
          '🎯 Sending destination to ROS: ${location.latitude}, ${location.longitude}',
        );

        rosService.publishDestinationCoordinates(
          location.latitude,
          location.longitude,
        );

        _displayInAppNotification(
          'ROS Journey Started',
          'Vehicle moving to ${location.name}',
          kind: NotificationKind.success,
        );
      } catch (e) {
        debugPrint('❌ Error sending destination to ROS: $e');
        _displayInAppNotification(
          'ROS Error',
          'Failed to start ROS journey: $e',
          kind: NotificationKind.error,
        );
      }
    }

    if (_currentPosition != null) {
      final destLatLng = LatLng(location.latitude, location.longitude);
      try {
        await _getRoute(_currentPosition!, destLatLng);
        _showNavigationStartedAlert(location.name);
      } catch (e) {
        _showErrorAlert('Gagal menghitung rute ke ${location.name}');
      }
    } else {
      _showErrorAlert('Lokasi saat ini tidak ditemukan. Periksa koneksi ROS.');
    }
  }

  void _showNavigationStartedAlert(String destinationName) {
    _displayInAppNotification(
      'Navigasi Dimulai',
      'Menuju ke $destinationName',
      kind: NotificationKind.success,
    );
  }

  void _showErrorAlert(String message) {
    _displayInAppNotification('Error', message, kind: NotificationKind.error);
  }

  Future<void> _loadGeoJsonData() async {
    try {
      String geoJsonString = geoJsonData;
      await _geoJsonRouteManager.loadGeoJsonData(geoJsonString);
      if (!mounted) return;
      setState(() {
        _geoJsonLocations = GeoJsonParser.parseGeoJson(geoJsonString);

        final Map<String, dynamic> data = jsonDecode(geoJsonString);
        for (var feature in data['features']) {
          if (feature['geometry']['type'] == 'LineString') {
            List<dynamic> coordinates = feature['geometry']['coordinates'];
            _lineStringPoints.addAll(
              coordinates.map((coord) => LatLng(coord[1], coord[0])).toList(),
            );
          }
        }
        // If placeholder not yet chosen, prefer geojson POI or line string first point.
        if (_placeholderLocation == null) {
          if (_geoJsonLocations.isNotEmpty) {
            final first = _geoJsonLocations.first;
            _placeholderLocation = LatLng(first.latitude, first.longitude);
          } else if (_lineStringPoints.isNotEmpty) {
            _placeholderLocation = _lineStringPoints.first;
          }
        }
      });
    } catch (e) {
      debugPrint('Error loading GeoJSON data: $e');
    }
  }

  Future<void> _getRoute(LatLng start, LatLng end) async {
    _setLoadingState(true);

    try {
      List<LatLng> routePoints = await _fetchRoutePoints(start, end);
      List<LatLng> fullRoute = _createRouteAlongLineString(start, end);

      List<LatLng> finalRoute;
      if (fullRoute.length > routePoints.length && fullRoute.length > 2) {
        finalRoute = fullRoute;
      } else if (routePoints.isNotEmpty) {
        finalRoute = routePoints;
      } else {
        finalRoute = [start, end];
      }

      _updateRouteInfo(finalRoute);
      _fitMapBounds();
    } catch (e) {
      List<LatLng> fallbackRoute = [start, end];
      _updateRouteInfo(fallbackRoute);
      _fitMapBounds();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Route error: $e")));
      }
    } finally {
      _setLoadingState(false);
    }
  }

  Future<List<LatLng>> _fetchRoutePoints(LatLng start, LatLng end) async {
    try {
      if (_internalRouteManager.isPointOnInternalRoad(start) &&
          _internalRouteManager.isPointOnInternalRoad(end)) {
        final internalRoute = _internalRouteManager.getInternalRoute();
        return internalRoute;
      } else {
        final externalRoute = await _externalRouteManager.getExternalRoute(
          start,
          end,
        );
        if (externalRoute.isEmpty) {
          return [start, end];
        }
        return externalRoute;
      }
    } catch (e) {
      return [start, end];
    }
  }

  List<LatLng> _createRouteAlongLineString(LatLng start, LatLng end) {
    if (_lineStringPoints.isEmpty) {
      return [start, end];
    }

    List<LatLng> route = [];
    LatLng closestStart = _findClosestPoint(start, _lineStringPoints);
    LatLng closestEnd = _findClosestPoint(end, _lineStringPoints);

    int startIndex = -1;
    int endIndex = -1;

    for (int i = 0; i < _lineStringPoints.length; i++) {
      if (_calculateDistance(_lineStringPoints[i], closestStart) < 0.001) {
        startIndex = i;
      }
      if (_calculateDistance(_lineStringPoints[i], closestEnd) < 0.001) {
        endIndex = i;
      }
    }

    if (startIndex != -1 && endIndex != -1) {
      route.add(start);
      if (startIndex <= endIndex) {
        route.addAll(_lineStringPoints.sublist(startIndex, endIndex + 1));
      } else {
        route.addAll(
          _lineStringPoints.sublist(endIndex, startIndex + 1).reversed,
        );
      }
      route.add(end);
    } else {
      route = [start, end];
    }

    return route;
  }

  LatLng _findClosestPoint(LatLng point, List<LatLng> linePoints) {
    double minDistance = double.infinity;
    LatLng closestPoint = linePoints.first;

    for (var linePoint in linePoints) {
      double distance = _calculateDistance(point, linePoint);
      if (distance < minDistance) {
        minDistance = distance;
        closestPoint = linePoint;
      }
    }

    return closestPoint;
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371;
    final double dLat = _degreesToRadians(end.latitude - start.latitude);
    final double dLng = _degreesToRadians(end.longitude - start.longitude);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(start.latitude)) *
            cos(_degreesToRadians(end.latitude)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  void _updateRouteInfo(List<LatLng> routePoints) {
    double totalDistance = _calculateTotalDistance(routePoints);
    String formattedTime = _formatTravelTime(totalDistance / 30);

    setState(() {
      _polylinePoints = routePoints;
    });

    // Update RouteDataService untuk videostream
    _routeDataService.updateRoute(
      routePoints: routePoints,
      currentPosition: _currentPosition,
      destinationPosition: _destinationLocation,
    );

    // Update NavigationDistanceService for real-time distance calculation
    if (_destinationLocation != null) {
      _distanceService.updateRoute(
        routePoints: routePoints,
        destination: _destinationLocation!,
        currentPosition: _currentPosition,
      );
    }

    if (widget.onRouteInfo != null && _destinationLocation != null) {
      _getDestinationName(_destinationLocation!).then((destinationName) {
        widget.onRouteInfo!(destinationName, totalDistance, formattedTime);
      });
    }
  }

  Future<String> _getDestinationName(LatLng destination) async {
    for (var location in LocationsData.destinations) {
      if ((location.latitude - destination.latitude).abs() < 0.0001 &&
          (location.longitude - destination.longitude).abs() < 0.0001) {
        return location.name;
      }
    }

    for (var location in _geoJsonLocations) {
      if ((location.latitude - destination.latitude).abs() < 0.0001 &&
          (location.longitude - destination.longitude).abs() < 0.0001) {
        return location.name;
      }
    }

    try {
      String coordinates = '${destination.latitude}, ${destination.longitude}';
      final results = await _locationService.fetchLocationsFromNominatim(
        coordinates,
      );
      if (results.isNotEmpty) {
        return results.first.name;
      }
    } catch (e) {
      debugPrint('Error fetching location from Nominatim: $e');
    }

    return "Unknown Location";
  }

  double _calculateTotalDistance(List<LatLng> points) {
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += _calculateDistance(points[i], points[i + 1]);
    }
    return total;
  }

  String _formatTravelTime(double hours) {
    int totalMinutes = (hours * 60).toInt();
    int hoursPart = totalMinutes ~/ 60;
    int minutesPart = totalMinutes % 60;

    if (hoursPart > 0) {
      return '$hoursPart hour${hoursPart > 1 ? 's' : ''} and $minutesPart minute${minutesPart > 1 ? 's' : ''}';
    } else {
      return '$minutesPart minute${minutesPart > 1 ? 's' : ''}';
    }
  }

  void _setLoadingState(bool isLoading) {
    if (!mounted) return;
    setState(() {
      _isLoading = isLoading;
    });
  }

  void _fitMapBounds() {
    if (_polylinePoints.isNotEmpty) {
      double minLat = _polylinePoints
          .map((point) => point.latitude)
          .reduce(min);
      double maxLat = _polylinePoints
          .map((point) => point.latitude)
          .reduce(max);
      double minLng = _polylinePoints
          .map((point) => point.longitude)
          .reduce(min);
      double maxLng = _polylinePoints
          .map((point) => point.longitude)
          .reduce(max);

      LatLng center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);

      // Calculate the maximum difference to determine if route is very short
      double latDiff = maxLat - minLat;
      double lngDiff = maxLng - minLng;
      double maxDiff = max(latDiff, lngDiff);

      // For very short routes (within 500 meters), just center without changing zoom
      if (maxDiff < 0.005) {
        _mapController.move(center, _mapController.camera.zoom);
        return;
      }

      double calculatedZoom = _calculateZoom(minLat, maxLat, minLng, maxLng);
      double currentZoom = _mapController.camera.zoom;

      // Only zoom out if really necessary - prefer maintaining current zoom
      // or only zoom out slightly if the calculated zoom is much smaller
      double targetZoom;
      if (calculatedZoom < currentZoom) {
        // Don't zoom out too dramatically - limit the zoom out to 2 levels max
        targetZoom = max(calculatedZoom, currentZoom - 2.0);
      } else {
        // Can zoom in normally
        targetZoom = calculatedZoom;
      }

      _mapController.move(center, targetZoom);
    }
  }

  void _checkArrival() {
    if (_destinationLocation == null || _currentPosition == null) return;

    // simple haversine check (in km) using existing helper
    double dist = _calculateDistance(_currentPosition!, _destinationLocation!);
    // Require closer distance (10 meters = 0.01 km) to consider arrived
    // This prevents premature completion when just approaching destination
    if (dist <= 0.01 && !_arrivalNotified) {
      _arrivalNotified = true;
      _displayInAppNotification(
        'Sampai Tujuan',
        'Anda telah sampai di tujuan (${(dist * 1000).toStringAsFixed(1)}m)',
        kind: NotificationKind.success,
      );

      // Notify parent that route is completed (NOT cleared!)
      if (widget.onRouteCompleted != null) {
        widget.onRouteCompleted!();
      }

      // Clear route info after showing completion for 10 seconds
      Timer(const Duration(seconds: 10), () {
        if (mounted) {
          _clearRouteInfo();
        }
      });
    }
  }

  void _clearRouteInfo() {
    setState(() {
      _polylinePoints.clear();
      _destinationLocation = null;
      _arrivalNotified = false;
    });

    // Clear route data service
    _routeDataService.clearRoute();

    // Clear distance service
    _distanceService.clearNavigation();

    // Notify parent to clear route info display
    if (widget.onClearRouteInfo != null) {
      widget.onClearRouteInfo!();
    } else if (widget.onRouteInfo != null) {
      // Fallback for backward compatibility
      widget.onRouteInfo!('KST Samaun Samadikun', 0.0, '0 minutes');
    }
  }

  LatLng _getPlaceholderLocation() {
    // If we've already determined a fixed placeholder, return it.
    if (_placeholderLocation != null) return _placeholderLocation!;

    // Otherwise compute once using available data and remember it.
    if (_geoJsonLocations.isNotEmpty) {
      final first = _geoJsonLocations.first;
      _placeholderLocation = LatLng(first.latitude, first.longitude);
      return _placeholderLocation!;
    }

    if (_lineStringPoints.isNotEmpty) {
      _placeholderLocation = _lineStringPoints.first;
      return _placeholderLocation!;
    }

    // Last-resort hardcoded central point (KST area)
    _placeholderLocation = const LatLng(-6.881377969504214, 107.61154761359956);
    return _placeholderLocation!;
  }

  // Public helper to center map on current position (callable from outside via GlobalKey)
  void centerOnCurrentPosition() {
    if (_currentPosition != null) {
      debugPrint(
        '🎯 Centering map on: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}',
      );
      _mapController.move(_currentPosition!, 19.0);
    } else {
      final fallback = _getPlaceholderLocation();
      debugPrint(
        '🎯 Centering map on placeholder: ${fallback.latitude}, ${fallback.longitude}',
      );
      _mapController.move(fallback, 19.0);
    }
  }

  /// Public method to clear navigation/route (callable from outside via GlobalKey)
  void clearNavigation() {
    debugPrint('🛑 Clearing navigation route from external call');
    _clearRouteInfo();
  }

  double _calculateZoom(
    double minLat,
    double maxLat,
    double minLng,
    double maxLng,
  ) {
    double latDiff = maxLat - minLat;
    double lngDiff = maxLng - minLng;
    double maxDiff = max(latDiff, lngDiff);

    // Improved zoom calculation to prevent excessive zoom out
    // For very short distances, maintain high zoom level
    if (maxDiff < 0.005) {
      return 17.0; // Very close points - keep very high zoom
    } else if (maxDiff < 0.01) {
      return 16.0; // Close points - maintain high zoom
    } else if (maxDiff < 0.02) {
      return 15.0; // Medium close
    } else if (maxDiff < 0.05) {
      return 14.0;
    } else if (maxDiff < 0.1) {
      return 13.0; // Increased from 12.0
    } else if (maxDiff < 0.5) {
      return 11.0; // Increased from 10.0
    } else if (maxDiff < 1.0) {
      return 9.0; // Increased from 8.0
    } else {
      return 7.0; // Increased from 6.0
    }
  }

  void _onPanStart(DragStartDetails details) {
    _startOffset = details.localPosition;
    _startRotation = _rotation;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_startOffset == null) return;

    final double dx = details.localPosition.dx - _startOffset!.dx;
    final double dy = details.localPosition.dy - _startOffset!.dy;
    final double angle = atan2(dy, dx);

    setState(() {
      _rotation = _startRotation + angle * (180 / pi);
      if (_rotation < 0) {
        _rotation += 360;
      } else if (_rotation >= 360) {
        _rotation -= 360;
      }
    });

    _mapController.rotate(_rotation);
  }

  String get geoJsonData {
    return '''
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "name": "Pos Satpam [Gerbang Keluar]"
      },
      "geometry": {
        "coordinates": [
          107.61128566453931,
          -6.88282548140144
        ],
        "type": "Point"
      }
    }
  ]
}
''';
  }

  @override
  Widget build(BuildContext context) {
    // === Responsiveness based on physical size ===
    final data = MediaQuery.of(context);
    final screenWidth = data.size.width;
    final screenHeight = data.size.height;

    // Calculate diagonal to detect device type (laptop vs tablet)
    final diagonal =
        sqrt(screenWidth * screenWidth + screenHeight * screenHeight) /
        data.devicePixelRatio;
    final isLargeScreen = diagonal >= 700; // ~13 inches threshold

    // Spacing & sizing tuned based on screen physical size
    final searchBarTop = isLargeScreen ? 36.0 : 16.0;
    final searchBarLeft = isLargeScreen ? 48.0 : 16.0;
    final searchBarMaxWidth = isLargeScreen ? 720.0 : 480.0;

    // REVISI: tombol "pusatkan ke mobil" diturunkan dan disejajarkan
    // dengan pill "Tentukan destinasi Anda" (bottom pill di
    // dashboard_layout.dart pakai bottomPadding 40/24 & tinggi 72/62),
    // bukan lagi mengambang di tengah layar menumpuk area logo peta.
    // Offset dihitung supaya titik tengah tombol sejajar dengan titik
    // tengah pill tersebut.
    final centerBtnRight = isLargeScreen ? 48.0 : 35.0;
    final centerBtnSize = isLargeScreen ? 56.0 : 48.0;
    const routePillBottomPadding = {'large': 40.0, 'small': 24.0};
    const routePillHeight = {'large': 72.0, 'small': 62.0};
    final centerBtnBottom = isLargeScreen
        ? routePillBottomPadding['large']! +
              (routePillHeight['large']! - centerBtnSize) / 2
        : routePillBottomPadding['small']! +
              (routePillHeight['small']! - centerBtnSize) / 2;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Map view with all markers and polylines inside
            MapView(
              center: _currentPosition ?? _getPlaceholderLocation(),
              zoom: 19.0,
              rotation: _rotation,
              mapController: _mapController,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              currentPosition: _currentPosition,
              destinationLocation: _destinationLocation,
              polylinePoints: _polylinePoints,
              placeholderPosition: _getPlaceholderLocation(),
            ),

            // Heading HUD (kept as-is; assumed responsive internally)
            const HeadingHUD(),

            // Search bar with results — with larger padding and width on Full HD
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: searchBarTop,
                    left: searchBarLeft,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: searchBarMaxWidth),
                    child: SearchBarWidget(
                      onLocationSelected: _onLocationSelected,
                    ),
                  ),
                ),
              ),
            ),

            // Loading indicator
            LoadingIndicator(isLoading: _isLoading),

            // Center on car button — position tuned for Full HD
            Positioned(
              right: centerBtnRight,
              bottom: centerBtnBottom,
              child: CenterOnCarButton(
                size: centerBtnSize,
                onPressed: () {
                  try {
                    centerOnCurrentPosition();
                  } catch (_) {}
                },
              ),
            ),

            // In-app notification (kept as-is; uses its own layout)
            InAppNotificationWidget(
              showNotification: _showInAppNotification,
              title: _inAppNotificationTitle,
              body: _inAppNotificationBody,
              kind: _inAppNotificationKind,
              onDismiss: () {
                setState(() {
                  _showInAppNotification = false;
                  _inAppNotificationTimer?.cancel();
                });
              },
            ),
          ],
        );
      },
    );
  }
}