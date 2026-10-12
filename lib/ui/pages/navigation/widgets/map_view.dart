import 'package:flutter/material.dart';
// ignore: unused_import -- used below for headingRadians
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../services/ros_service.dart';
import '../../../../config/map_config.dart';
import '../bloc/navigation_cubit.dart';
import '../../../shared/fallback_tile_layer.dart';
import 'route_polyline.dart';

class MapView extends StatelessWidget {
  final Offset? panStart;
  final double zoom;
  final LatLng center;
  final void Function(DragStartDetails)? onPanStart;
  final void Function(DragUpdateDetails)? onPanUpdate;
  final void Function(LatLng)? onMapTap;
  final List<LatLng> route;
  final double rotation;
  final MapController? mapController;

  // Additional props for markers and polylines
  final LatLng? currentPosition;
  final LatLng? destinationLocation;
  final List<LatLng> polylinePoints;
  // Stable placeholder position to prevent marker drift when GPS unavailable
  final LatLng? placeholderPosition;
  // Dynamic vehicle heading aligned with road/travel path
  final double? vehicleHeading;

  const MapView({
    super.key,
    required this.center,
    required this.zoom,
    this.panStart,
    this.onPanStart,
    this.onPanUpdate,
    this.onMapTap,
    this.route = const [],
    this.rotation = 0.0,
    this.mapController,
    this.currentPosition,
    this.destinationLocation,
    this.polylinePoints = const [],
    this.placeholderPosition,
    this.vehicleHeading,
  });

  @override
  Widget build(BuildContext context) {
    // Fallback heading from NavigationCubit (used if IMU yaw not available)
    final fallbackHeading = context.select(
      (NavigationCubit c) => c.state.fallbackHeadingDeg,
    );
    return GestureDetector(
      onPanStart: onPanStart,
      onPanUpdate: onPanUpdate,
      child: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: zoom,
              initialRotation: rotation,
              // Use optimized zoom levels from MapConfig
              maxZoom: MapConfig.maxZoom,
              minZoom: MapConfig.minZoom,
              // Optimize map performance to reduce API calls
              interactionOptions: const InteractionOptions(
                enableMultiFingerGestureRace: true,
                rotationThreshold: 20.0,
              ),
              onMapReady: () {
                if (mapController != null) {
                  // Clamp zoom to maxZoom (never zoom out)
                  final safeZoom = zoom > MapConfig.maxZoom
                      ? MapConfig.maxZoom
                      : zoom;
                  mapController!.move(center, safeZoom);
                }
              },
            ),
            children: [
              const FallbackTileLayer(),
              // Route polyline with progress effect - Clean light style
              if (polylinePoints.isNotEmpty)
                RoutePolyline(
                  points: polylinePoints,
                  currentPosition: currentPosition,
                  color: const Color(0xFF1976D2), // Material blue accent
                  strokeWidth: 5.0,
                  traveledColor: const Color(
                    0xFFBDBDBD,
                  ), // Light gray for traveled
                  traveledStrokeWidth: 3.0,
                ),

              // Current location marker (car) with heading - Clean light style
              MarkerLayer(
                markers: [
                  Marker(
                    width: 56,
                    height: 56,
                    point: currentPosition ?? placeholderPosition ?? center,
                    child: StreamBuilder<Map<String, double>>(
                      stream: RosService().imuStream,
                      builder: (context, snapshot) {
                        double heading = vehicleHeading ?? fallbackHeading;
                        final imu = snapshot.data;
                        // Fallback ke raw IMU hanya jika belum ada heading kalkulasi rute/gerak
                        if (vehicleHeading == null && heading == 0.0 && imu != null && imu['yaw'] != null) {
                          heading = imu['yaw']!;
                        }

                        return VehicleCarMarker(headingDeg: heading);
                      },
                    ),
                  ),
                ],
              ),

              // Destination marker - Clean light style
              if (destinationLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 50,
                      height: 50,
                      point: destinationLocation!,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Light glowing effect
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF1976D2,
                              ).withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                          ),
                          // Main destination pin
                          ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (Rect bounds) =>
                                const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF1976D2), // Material blue
                                    Color(0xFF1565C0), // Darker blue
                                  ],
                                ).createShader(bounds),
                            child: const Icon(
                              Icons.location_on_sharp,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

              // Clean light attribution
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
                popupBackgroundColor: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Marker kendaraan mobil MEVI dengan animasi rotasi kontinu dan pointer arah
class VehicleCarMarker extends StatefulWidget {
  final double headingDeg;

  const VehicleCarMarker({
    super.key,
    required this.headingDeg,
  });

  @override
  State<VehicleCarMarker> createState() => _VehicleCarMarkerState();
}

class _VehicleCarMarkerState extends State<VehicleCarMarker> {
  double _unwrappedDeg = 0.0;
  bool _isFirst = true;

  @override
  void initState() {
    super.initState();
    _unwrappedDeg = widget.headingDeg;
  }

  @override
  void didUpdateWidget(VehicleCarMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isFirst) {
      _unwrappedDeg = widget.headingDeg;
      _isFirst = false;
      return;
    }
    // Shortest angular difference (-180 to 180) agar transisi putaran selalu terpendek
    final diff = ((widget.headingDeg - _unwrappedDeg + 180) % 360) - 180;
    _unwrappedDeg += diff;
  }

  @override
  Widget build(BuildContext context) {
    // 1 turn = 360 degrees
    final turns = _unwrappedDeg / 360.0;

    return AnimatedRotation(
      turns: turns,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Background lingkaran putih bersih dengan shadow & border navigasi
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF1976D2),
                width: 2.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1976D2).withValues(alpha: 0.28),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 1),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),

          // Forward heading pointer di puncak lingkaran (menunjuk lurus ke depan)
          Positioned(
            top: 2,
            child: CustomPaint(
              size: const Size(10, 6),
              painter: _ForwardArrowPainter(color: const Color(0xFF1976D2)),
            ),
          ),

          // Icon mobil MEVI tampak atas dengan orientasi tegak lurus (menghadap ke depan/North)
          Image.asset(
            'assets/images/mevicar.png',
            width: 32,
            height: 38,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                'assets/images/car.png',
                width: 28,
                height: 38,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.navigation,
                    size: 28,
                    color: Color(0xFF1976D2),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ForwardArrowPainter extends CustomPainter {
  final Color color;
  const _ForwardArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ForwardArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}
