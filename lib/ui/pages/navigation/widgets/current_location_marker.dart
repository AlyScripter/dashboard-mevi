import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../services/ros_service.dart';
import '../bloc/navigation_cubit.dart';

class CurrentLocationMarker extends StatelessWidget {
  final LatLng? currentPosition;

  const CurrentLocationMarker({super.key, this.currentPosition});

  @override
  Widget build(BuildContext context) {
    // Use fallback position if currentPosition is null for testing
    final position =
        currentPosition ?? const LatLng(-6.881377969504214, 107.61154761359956);

    return StreamBuilder<Map<String, double>>(
      stream: RosService().imuStream,
      builder: (context, snapshot) {
        // Get heading from IMU stream or fallback from navigation cubit
        double heading = context.select(
          (NavigationCubit c) => c.state.fallbackHeadingDeg,
        );

        final imu = snapshot.data;
        if (imu != null && imu['yaw'] != null) {
          heading = imu['yaw']!;
        }

        // Convert heading to radians for rotation
        final headingRadians = heading * (3.14159 / 180);

        return MarkerLayer(
          markers: [
            Marker(
              width: 50,
              height: 50,
              point: position,
              child: Transform.rotate(
                angle: headingRadians,
                child: Image.asset(
                  'assets/images/mevicar.png',
                  width: 48,
                  height: 48,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
