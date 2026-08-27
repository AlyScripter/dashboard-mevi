import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../models/metric_model.dart';
import '../status/metric_card.dart';
import '../../../../../core/theme/colors.dart';

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
    // Blue-black glass theme: icon accent is now the same neon blue used
    // everywhere else on the dashboard (was plain white before, which
    // barely showed on the old white card background).
    final metrics = [
      MetricData(
        icon: LucideIcons.gauge,
        label: 'Speed',
        value: currentSpeed.toStringAsFixed(1),
        unit: 'km/h',
        color: AppColors.glassBlueBorder,
        trend: TrendDirection.stable,
      ),
      MetricData(
        icon: LucideIcons.radar,
        label: 'Distance',
        value: frontDistance.toStringAsFixed(2),
        unit: 'm',
        color: AppColors.glassBlueBorder,
        trend: TrendDirection.stable,
      ),
      MetricData(
        icon: Icons.warning,
        label: 'Nearest',
        value: nearestObstacle.toStringAsFixed(2),
        unit: 'm',
        color: AppColors.glassBlueBorder,
        trend: TrendDirection.stable,
      ),
      MetricData(
        icon: LucideIcons.compass,
        label: 'IMU Yaw',
        value: imuYaw.toStringAsFixed(1),
        unit: '°',
        color: AppColors.glassBlueBorder,
        trend: TrendDirection.stable,
      ),
      MetricData(
        icon: LucideIcons.battery,
        label: 'Battery',
        value: batterySoc.toInt().toString(),
        unit: '%',
        color: AppColors.glassBlueBorder,
        trend: TrendDirection.stable,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // On narrow screens keep a horizontal scrollable list.
        if (constraints.maxWidth < 600) {
          return SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: metrics.length,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                return MetricCard(metric: metrics[index]);
              },
            ),
          );
        }

        // On wider screens distribute cards evenly across the row.
        return SizedBox(
          height: 100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: metrics
                .map(
                  (m) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
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
