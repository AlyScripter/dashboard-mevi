import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Top-of-panel stats row: Battery + Estimated range on battery.
class BatteryIndicatorWidget extends StatelessWidget {
  final double batteryPercent;
  final VoidCallback onTap;
  final double? distanceMeters;

  const BatteryIndicatorWidget({
    super.key,
    required this.batteryPercent,
    required this.onTap,
    this.distanceMeters,
  });

  static const _green = Color(0xFF34D765);

  @override
  Widget build(BuildContext context) {
    final String remainKmText;
    final double distPercent;

    if (distanceMeters != null) {
      final km = distanceMeters! / 1000.0;
      remainKmText = '${km.toStringAsFixed(1)} km';
      // Progres bar indikator jarak (normalisasi ke visual ~10km target rute)
      distPercent = (km / 10.0).clamp(0.0, 1.0);
    } else {
      final remainKm = (batteryPercent * 5).clamp(0.0, 999.0);
      remainKmText = '${remainKm.toStringAsFixed(1)} km';
      distPercent = batteryPercent;
    }

    final isLight = Theme.of(context).brightness == Brightness.light;

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
              isLight: isLight,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatBar(
              icon: LucideIcons.batteryCharging,
              label: 'Jarak',
              valueText: remainKmText,
              percent: distPercent,
              barColor: _green,
              isLight: isLight,
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
  final bool isLight;

  const _StatBar({
    required this.icon,
    required this.label,
    required this.valueText,
    required this.percent,
    required this.barColor,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) {
    // REVISI: light mode → teks/ikon jadi gelap dan track progress bar
    // jadi abu-abu terang, supaya kontras di atas background putih.
    final textClr = isLight
        ? const Color(0xFF1A2331).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.85);
    final valueClr = isLight ? const Color(0xFF1A2331) : Colors.white;
    final trackClr = isLight
        ? const Color(0xFF1A2331).withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.15);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: textClr),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textClr,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              valueText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: valueClr,
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
                Container(height: 6, width: c.maxWidth, color: trackClr),
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
