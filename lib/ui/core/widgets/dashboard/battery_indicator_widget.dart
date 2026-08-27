import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Top-of-panel stats row: Battery + Estimated range on battery.
class BatteryIndicatorWidget extends StatelessWidget {
  final double batteryPercent;
  final VoidCallback onTap;

  const BatteryIndicatorWidget({
    super.key,
    required this.batteryPercent,
    required this.onTap,
  });

  static const _green = Color(0xFF34D765);

  @override
  Widget build(BuildContext context) {
    final remainKm = (batteryPercent * 5).clamp(0.0, 999.0);
    final remainKmText = '${remainKm.toStringAsFixed(1)} km';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Expanded(
            child: _StatBar(
              icon: LucideIcons.batteryFull,
              label: 'Baterai',
              valueText:
                  '${(batteryPercent * 100).clamp(0, 100).toStringAsFixed(0)}%',
              percent: batteryPercent,
              barColor: _green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatBar(
              icon: LucideIcons.batteryCharging,
              label: 'Jarak',
              valueText: remainKmText,
              percent: batteryPercent,
              barColor: _green,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valueText;
  final double percent;
  final Color barColor;

  const _StatBar({
    required this.icon,
    required this.label,
    required this.valueText,
    required this.percent,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.85)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              valueText,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LayoutBuilder(
            builder: (context, c) => Stack(
              children: [
                Container(
                  height: 6,
                  width: c.maxWidth,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  height: 6,
                  width: c.maxWidth * percent.clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
