import 'package:flutter/material.dart';
import '../../models/metric_model.dart';
import '../../../../../core/theme/colors.dart';

class MetricCard extends StatelessWidget {
  final MetricData metric;
  final bool hovered;

  const MetricCard({super.key, required this.metric, this.hovered = false});

  @override
  Widget build(BuildContext context) {
    // Blue-black glass card — dark navy fill + neon blue border, replacing
    // the old plain white Material Card so it matches the rest of the
    // cockpit dashboard theme.
    return Container(
      width: 140,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.glassNavyTint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.glassBlueBorder.withValues(alpha: 0.55),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: metric.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(metric.icon, color: metric.color, size: 16),
              ),
              _buildTrendIndicator(metric.trend),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                metric.label,
                style: TextStyle(
                  color: AppColors.glassTextSecondary,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    metric.value,
                    style: TextStyle(
                      color: AppColors.glassTextPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    metric.unit,
                    style: TextStyle(
                      color: AppColors.glassTextSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendIndicator(TrendDirection trend) {
    IconData icon;
    Color color;

    switch (trend) {
      case TrendDirection.up:
        icon = Icons.trending_up;
        color = Colors.green;
        break;
      case TrendDirection.down:
        icon = Icons.trending_down;
        color = Colors.red;
        break;
      case TrendDirection.stable:
        icon = Icons.remove;
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Icon(icon, color: color, size: 14),
    );
  }
}
