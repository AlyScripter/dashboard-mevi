import 'package:flutter/material.dart';
// ignore: unused_import -- used below for headingRadians
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
                    width: 50,
                    height: 50,
                    point: currentPosition ?? placeholderPosition ?? center,
                    child: StreamBuilder<Map<String, double>>(
                      stream: RosService().imuStream,
                      builder: (context, snapshot) {
                        // Get heading from IMU stream or fallback
                        // Start with fallback heading; override if IMU provides yaw
                        double heading = fallbackHeading;
                        final imu = snapshot.data;
                        if (imu != null && imu['yaw'] != null) {
                          heading = imu['yaw']!;
                        }
                        final headingRadians = heading * (pi / 180);

                        return Transform.rotate(
                          angle: headingRadians,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Clean light background circle
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white, // White background
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(
                                      0xFF1976D2,
                                    ), // Material blue border
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF1976D2,
                                      ).withValues(alpha: 0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 0),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              // Car icon with clean styling
                              Image.asset(
                                'assets/images/mevicar.png',
                                width: 36,
                                height: 36,
                                color: const Color(
                                  0xFF1976D2,
                                ), // Material blue tint
                                colorBlendMode: BlendMode.modulate,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.directions_car,
                                    size: 30,
                                    color: Color(0xFF1976D2), // Material blue
                                  );
                                },
                              ),
                            ],
                          ),
                        );
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
