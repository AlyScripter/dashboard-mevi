import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:dashboardmevi/services/ros_service.dart';
import 'package:dashboardmevi/core/theme/dimensions.dart';
import 'package:dashboardmevi/core/theme/glass_container.dart';
import 'package:dashboardmevi/core/theme/colors.dart';

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
                    color: Colors.white,
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

    // Blue glass tint to match the reference dashboard's top metric cards
    // (was a neutral white/dark tint before).
    // REVISI: border biru neon (disamakan dengan search bar/navigasi)
    // menggantikan border putih tipis sebelumnya.
    return GlassContainer(
      height: 64,
      borderRadius: AppDimensions.radiusM,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      tint: const Color(0xFF2196F3),
      tintOpacity: 0.18,
      borderColor: AppColors.glassBlueBorder,
      borderOpacity: 0.85,
      borderWidth: 1.4,
      blurSigma: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Flexible(
            child: valueText != null
                ? Text(
                    valueText,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  )
                : DefaultTextStyle(
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    child: inner!,
                  ),
          ),
        ],
      ),
    );
  }
}
