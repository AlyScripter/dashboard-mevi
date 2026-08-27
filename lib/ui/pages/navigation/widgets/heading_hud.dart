import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dashboardmevi/ui/pages/navigation/bloc/navigation_cubit.dart';
import 'package:dashboardmevi/services/ros_service.dart';
import 'package:dashboardmevi/core/theme/colors.dart';

class HeadingHUD extends StatelessWidget {
  const HeadingHUD({super.key});

  String _headingToCardinal(double heading) {
    const dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
    final idx = ((heading % 360) / 45).round() % 8;
    return dirs[idx];
  }

  @override
  Widget build(BuildContext context) {
    // Optional: initialize IMU stream hookup from RosService into Cubit once.
    context.read<NavigationCubit>().ensureSensorsHooked();

    final data = MediaQuery.of(context);
    final screenWidth = data.size.width;
    final screenHeight = data.size.height;

    // Calculate diagonal to detect device type (laptop vs tablet)
    // Tablet 11" Infinix XPAD: 1920x1200 @ 208 PPI = ~11.0 inches diagonal
    // Laptop 15": 1920x1080 @ ~141 PPI = ~15.6 inches diagonal
    final diagonal =
        math.sqrt(screenWidth * screenWidth + screenHeight * screenHeight) /
        data.devicePixelRatio;

    // Device type detection:
    // - isLaptop: diagonal >= 700 logical pixels (~13+ inches, laptop/desktop)
    // - isTablet: diagonal >= 500 && < 700 (~10-13 inches, tablets like Infinix XPAD)
    // - isCompact: diagonal < 500 (smaller phones)
    final isLaptop = diagonal >= 700;
    final isTablet = diagonal >= 500 && diagonal < 700;

    // Responsive values based on device type
    final double rightPos = isLaptop ? 55.0 : (isTablet ? 40.0 : 25.0);
    final double topPos = isLaptop ? 120.0 : (isTablet ? 105.0 : 110.0);
    final double iconSize = isLaptop ? 28.0 : (isTablet ? 24.0 : 18.0);
    final double horizontalPadding = isLaptop ? 16.0 : (isTablet ? 14.0 : 10.0);
    final double verticalPadding = isLaptop ? 12.0 : (isTablet ? 10.0 : 8.0);
    final double containerWidth = isLaptop ? 120.0 : (isTablet ? 105.0 : 85.0);
    final double fontSizeHeading = isLaptop ? 22.0 : (isTablet ? 18.0 : 14.0);
    final double fontSizeCardinal = isLaptop ? 16.0 : (isTablet ? 14.0 : 11.0);
    final double spacing = isLaptop ? 12.0 : (isTablet ? 10.0 : 8.0);
    final double borderRadiusValue = isLaptop ? 20.0 : (isTablet ? 18.0 : 16.0);

    return Positioned(
      right: rightPos,
      top: topPos,
      child: StreamBuilder<Map<String, double>>(
        stream: RosService().imuStream,
        builder: (context, snapshot) {
          double heading = context.select(
            (NavigationCubit c) => c.state.fallbackHeadingDeg,
          );
          final imu = snapshot.data;
          if (imu != null && imu['yaw'] != null) heading = imu['yaw']!;

          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            width: containerWidth,
            // REVISI: solid hitam + border biru neon, tanpa blur,
            // disamakan dengan search bar / destination bar / panel kiri
            // (sebelumnya kotak putih polos, beda sendiri dari widget
            // lain di dashboard).
            decoration: BoxDecoration(
              color: AppColors.glassNavyTint,
              borderRadius: BorderRadius.circular(borderRadiusValue),
              border: Border.all(
                color: AppColors.glassBlueBorder.withValues(alpha: 0.85),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.rotate(
                  angle: heading * (math.pi / 180),
                  child: Icon(
                    Icons.navigation,
                    size: iconSize,
                    color: const Color(0xFF7DB4FF),
                  ),
                ),
                SizedBox(width: spacing),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${heading.toStringAsFixed(0)}°',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.glassTextPrimary,
                        fontSize: fontSizeHeading,
                      ),
                    ),
                    Text(
                      _headingToCardinal(heading),
                      style: TextStyle(
                        color: AppColors.glassTextSecondary,
                        fontSize: fontSizeCardinal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
