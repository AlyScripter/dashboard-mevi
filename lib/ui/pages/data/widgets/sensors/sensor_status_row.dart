import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../models/metric_model.dart';
import '../status/metric_card.dart';

class SensorStatusRow extends StatelessWidget {
  final double currentSpeed;
  final double frontDistance;
  final double nearestObstacle;
  final double imuYaw;
  final double batterySoc;

  const SensorStatusRow({
    super.key,
    required this.currentSpeed,
    required this.frontDistance,
    required this.nearestObstacle,
    required this.imuYaw,
    required this.batterySoc,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = [
      MetricData(
        icon: LucideIcons.gauge,
        label: 'Speed',
        value: currentSpeed.toStringAsFixed(1),
        unit: 'km/h',
        color: const Color(0xFF2563EB),
        badgeBg: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF2563EB),
        trend: TrendDirection.stable,
      ),
      MetricData(
        icon: LucideIcons.radar,
        label: 'Distance',
        value: frontDistance.toStringAsFixed(2),
        unit: 'm',
        color: const Color(0xFF0D9488),
        badgeBg: const Color(0xFFF0FDFA),
        iconColor: const Color(0xFF0D9488),
        trend: TrendDirection.stable,
      ),
      MetricData(
        icon: LucideIcons.triangleAlert,
        label: 'Nearest',
        value: nearestObstacle.toStringAsFixed(2),
        unit: 'm',
        color: const Color(0xFFD97706),
        badgeBg: const Color(0xFFFFFBEB),
        iconColor: const Color(0xFFD97706),
        trend: TrendDirection.stable,
      ),
      MetricData(
        icon: LucideIcons.compass,
        label: 'IMU Yaw',
        value: imuYaw.toStringAsFixed(1),
        unit: '°',
        color: const Color(0xFF4F46E5),
        badgeBg: const Color(0xFFEEF2FF),
        iconColor: const Color(0xFF4F46E5),
        trend: TrendDirection.stable,
      ),
      MetricData(
        icon: LucideIcons.batteryCharging,
        label: 'Battery',
        value: batterySoc.toInt().toString(),
        unit: '%',
        color: const Color(0xFF059669),
        badgeBg: const Color(0xFFECFDF5),
        iconColor: const Color(0xFF059669),
        trend: TrendDirection.stable,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Layar sempit: scroll horizontal
        if (constraints.maxWidth < 650) {
          return SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: metrics.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return MetricCard(metric: metrics[index]);
              },
            ),
          );
        }

        // Layar lebar / Full HD: distribusikan kartu merata
        return SizedBox(
          height: 110,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: metrics
                .map(
                  (m) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5.0),
                      child: MetricCard(metric: m),
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}
