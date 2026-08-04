import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:dashboardmevi/services/ros_service.dart';
import 'package:dashboardmevi/core/theme/dimensions.dart';

class DistanceCardsWidget extends StatelessWidget {
  final double batteryPercent;

  const DistanceCardsWidget({super.key, required this.batteryPercent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: LucideIcons.arrowLeftRight,
            valueBuilder: () => StreamBuilder<double>(
              stream: RosService().ultrasonicStream,
              builder: (context, snap) {
                final dist = snap.data ?? 50; // meters
                return Text(
                  '${dist.toStringAsFixed(0)} m',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                );
              },
            ),
          ),
        ),
        SizedBox(width: AppDimensions.spacingM),
        Expanded(
          child: _MetricCard(
            icon: LucideIcons.batteryCharging,
            valueBuilder: () {
              final remainKm = (batteryPercent * 5).toStringAsFixed(1);
              return '$remainKm km';
            },
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final dynamic valueBuilder;

  const _MetricCard({required this.icon, required this.valueBuilder});

  @override
  Widget build(BuildContext context) {
    String? valueText;
    Widget? inner;

    if (valueBuilder is String) {
      valueText = valueBuilder as String;
    } else if (valueBuilder is Widget Function()) {
      inner = valueBuilder();
    } else if (valueBuilder is Widget) {
      inner = valueBuilder as Widget;
    } else if (valueBuilder is String Function()) {
      valueText = (valueBuilder as String Function())();
    }

    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: AppDimensions.iconL, color: Colors.black87),
          const Spacer(),
          if (valueText != null)
            Text(
              valueText,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            )
          else if (inner != null)
            DefaultTextStyle(
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
              child: inner,
            ),
        ],
      ),
    );
  }
}
