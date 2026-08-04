import 'package:flutter/material.dart';
import '../../models/metric_model.dart';

class MetricCard extends StatelessWidget {
  final MetricData metric;
  final bool hovered;

  const MetricCard({super.key, required this.metric, this.hovered = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(6),
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
                    color: metric.color.withValues(alpha: 0.12),
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
                  style: TextStyle(color: Colors.black87, fontSize: 10),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      metric.value,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      metric.unit,
                      style: TextStyle(color: Colors.black54, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
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
