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

    // ── Edaca / Modern Autonomous Dashboard Style ──
    final cardColor = isLight ? Colors.white : AppColors.glassNavyTint;
    final cardBorderColor = isLight
        ? const Color(0xFFE2E8F0)
        : AppColors.glassBlueBorder.withValues(alpha: 0.65);
    final cardShadowColor = isLight
        ? const Color(0x0A0F172A)
        : Colors.black.withValues(alpha: 0.35);

    final iconBg = isLight
        ? (metric.badgeBg ?? const Color(0xFFEFF6FF))
        : (metric.color.withValues(alpha: 0.16));
    final iconClr = isLight
        ? (metric.iconColor ?? metric.color)
        : (metric.iconColor ?? AppColors.glassBlueBorder);

    final labelClr = isLight
        ? const Color(0xFF64748B)
        : AppColors.glassTextSecondary;
    final valueClr = isLight
        ? const Color(0xFF0F172A)
        : AppColors.glassTextPrimary;
    final unitClr = isLight
        ? const Color(0xFF94A3B8)
        : AppColors.glassTextSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: cardShadowColor,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(metric.icon, color: iconClr, size: 16),
              ),
              _buildLiveIndicator(isLight),
            ],
          ),
          const SizedBox(height: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                metric.label,
                style: TextStyle(
                  color: labelClr,
                  fontSize: 11.0,
                  height: 1.1,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                      fontSize: 20,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    metric.unit,
                    style: TextStyle(
                      color: unitClr,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
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

  Widget _buildLiveIndicator(bool isLight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFF0FDF4) : const Color(0x1A10B981),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isLight ? const Color(0xFFDCFCE7) : const Color(0x3310B981),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'LIVE',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: isLight ? const Color(0xFF16A34A) : const Color(0xFF34D399),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
