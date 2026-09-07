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
    context.read<NavigationCubit>().ensureSensorsHooked();

    final isLight = Theme.of(context).brightness == Brightness.light;

    // --- THEME-AWARE COLORS ---
    final bgColor = isLight ? Colors.white : AppColors.glassNavyTint;
    final borderColor = isLight
        ? AppColors.primary.withValues(alpha: 0.35)
        : AppColors.glassBlueBorder.withValues(alpha: 0.85);
    final shadowColor = isLight
        ? Colors.black.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.35);
    final textPrimary = isLight
        ? const Color(0xFF1A1A2E)
        : AppColors.glassTextPrimary;
    final textSecondary = isLight
        ? const Color(0xFF555577)
        : AppColors.glassTextSecondary;
    final iconColor = isLight ? AppColors.primary : const Color(0xFF7DB4FF);

    final data = MediaQuery.of(context);
    final screenWidth = data.size.width;
    final screenHeight = data.size.height;

    final diagonal =
        math.sqrt(screenWidth * screenWidth + screenHeight * screenHeight) /
        data.devicePixelRatio;

    final isLaptop = diagonal >= 700;
    final isTablet = diagonal >= 500 && diagonal < 700;

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
            // THEME-AWARE: putih bersih di light mode, navy gelap di dark mode
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(borderRadiusValue),
              border: Border.all(color: borderColor, width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
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
                    color: iconColor,
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
                        color: textPrimary,
                        fontSize: fontSizeHeading,
                      ),
                    ),
                    Text(
                      _headingToCardinal(heading),
                      style: TextStyle(
                        color: textSecondary,
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
