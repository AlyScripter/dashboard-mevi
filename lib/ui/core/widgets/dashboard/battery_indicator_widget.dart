import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/glass_container.dart';

/// Battery + (dummy) efficiency stat row, wrapped in a blue frosted-glass
/// card — styled after the reference dashboard's "Battery 72% / Fuel 83%"
/// header cards — meant to sit at the very top of the left panel.
///
/// The efficiency figure has no real ROS source yet, so it is clearly
/// dummy/placeholder data — swap `_dummyEfficiency` for a real stream
/// whenever one becomes available.
class BatteryIndicatorWidget extends StatelessWidget {
  final double batteryPercent;
  final VoidCallback onTap;

  const BatteryIndicatorWidget({
    super.key,
    required this.batteryPercent,
    required this.onTap,
  });

  static const double _dummyEfficiency = 0.87; // dummy data
  static const _blue = Color(0xFF2196F3);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: GlassContainer(
        borderRadius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        tint: _blue,
        tintOpacity: 0.18,
        borderOpacity: 0.28,
        blurSigma: 16,
        child: Row(
          children: [
            Expanded(
              child: _StatBar(
                icon: LucideIcons.batteryFull,
                label: 'Baterai',
                percent: batteryPercent,
                barColor: batteryPercent > 0.2
                    ? const Color(0xFF34D399)
                    : const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatBar(
                icon: LucideIcons.gauge,
                label: 'Efisiensi',
                percent: _dummyEfficiency,
                barColor: const Color(0xFF34D399),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  final IconData icon;
  final String label;
  final double percent;
  final Color barColor;

  const _StatBar({
    required this.icon,
    required this.label,
    required this.percent,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    final percentText = '${(percent * 100).clamp(0, 100).toStringAsFixed(0)}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.75)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              percentText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LayoutBuilder(
            builder: (context, c) => Stack(
              children: [
                Container(
                  height: 5,
                  width: c.maxWidth,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  height: 5,
                  width: c.maxWidth * percent.clamp(0.0, 1.0),
                  color: barColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
