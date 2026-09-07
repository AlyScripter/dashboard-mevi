import 'package:flutter/material.dart';
import '../../models/metric_model.dart';
import '../../../../../core/theme/colors.dart';

class MetricCard extends StatelessWidget {
  final MetricData metric;
  final bool hovered;

  const MetricCard({super.key, required this.metric, this.hovered = false});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    // REVISI: light mode → gradient biru nav rail (0xFF1565C0 → 0xFF1976D2),
    // border 0xFF1E88E5, icon & semua teks putih.
    // Dark mode → navy gelap + neon blue border seperti semula.
    final cardGradient = isLight
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
          )
        : null;
    final cardColor = isLight ? null : AppColors.glassNavyTint;
    final cardBorderColor = isLight
        ? const Color(0xFF1E88E5)
        : AppColors.glassBlueBorder.withValues(alpha: 0.55);
    final cardShadowColor = isLight
        ? const Color(0xFF1565C0).withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.35);

    // Icon & teks: putih di light mode, warna bawaan di dark mode
    final iconBg = isLight
        ? Colors.white.withValues(alpha: 0.18)
        : metric.color.withValues(alpha: 0.16);
    final iconClr = isLight ? Colors.white : metric.color;
    final labelClr = isLight ? Colors.white70 : AppColors.glassTextSecondary;
    final valueClr = isLight ? Colors.white : AppColors.glassTextPrimary;
    final unitClr = isLight ? Colors.white70 : AppColors.glassTextSecondary;

    return Container(
      width: 140,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cardColor,
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cardBorderColor, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: cardShadowColor,
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
                  color: iconBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(metric.icon, color: iconClr, size: 16),
              ),
              _buildTrendIndicator(metric.trend, isLight),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                metric.label,
                style: TextStyle(color: labelClr, fontSize: 10),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    metric.value,
                    style: TextStyle(
                      color: valueClr,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    metric.unit,
                    style: TextStyle(color: unitClr, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendIndicator(TrendDirection trend, bool isLight) {
    IconData icon;
    Color color;

    switch (trend) {
      case TrendDirection.up:
        icon = Icons.trending_up;
        color = isLight ? Colors.white : Colors.green;
        break;
      case TrendDirection.down:
        icon = Icons.trending_down;
        color = isLight ? Colors.white : Colors.red;
        break;
      case TrendDirection.stable:
        icon = Icons.remove;
        color = isLight ? Colors.white70 : Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isLight ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Icon(icon, color: color, size: 14),
    );
  }
}
