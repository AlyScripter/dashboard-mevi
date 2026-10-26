import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:dashboardmevi/core/theme/colors.dart';

/// Top-of-panel stats row: Battery + Estimated range on battery.
///
/// REVISI: Mengadopsi visual style & hierarki cockpit EV modern:
/// - Light mode: White card, subtle slate border (0xFFE2E8F0), soft shadow (0x0A0F172A).
/// - Dark mode: Dark navy tint, glass blue border, deep shadow.
/// - Ikon di dalam micro-rounded square (green untuk baterai, blue untuk jarak).
/// - Tipografi berjenjang tajam & progress bar dengan gradien elegan.
class BatteryIndicatorWidget extends StatelessWidget {
  final double batteryPercent;
  final VoidCallback? onTap;
  final double? distanceMeters;
  final double? distanceKm;

  final bool asCard;

  const BatteryIndicatorWidget({
    super.key,
    required this.batteryPercent,
    this.onTap,
    this.distanceMeters,
    this.distanceKm,
    this.asCard = false,
  });

  @override
  Widget build(BuildContext context) {
    final String remainKmText;
    final double distPercent;

    if (distanceKm != null) {
      final km = distanceKm!;
      remainKmText =
          '${km.toStringAsFixed(km.truncateToDouble() == km ? 0 : 1)} km';
      // Kapasitas penuh 60 km (48V × 100Ah = 4.800 Wh / 80 Wh/km = 60 km)
      distPercent = (km / 60.0).clamp(0.0, 1.0);
    } else if (distanceMeters != null) {
      final km = distanceMeters! / 1000.0;
      remainKmText = '${km.toStringAsFixed(1)} km';
      distPercent = (km / 10.0).clamp(0.0, 1.0);
    } else {
      final remainKm = (batteryPercent * 60.0).clamp(0.0, 999.0);
      remainKmText =
          '${remainKm.toStringAsFixed(remainKm.truncateToDouble() == remainKm ? 0 : 1)} km';
      distPercent = batteryPercent.clamp(0.0, 1.0);
    }

    final isLight = Theme.of(context).brightness == Brightness.light;

    final statRow = Row(
      children: [
        Expanded(
          child: _StatBar(
            icon: LucideIcons.batteryCharging,
            label: 'Baterai',
            valueText:
                '${(batteryPercent * 100).clamp(0, 100).toStringAsFixed(0)}%',
            percent: batteryPercent,
            accentColor: const Color(0xFF10B981),
            accentBg: isLight
                ? const Color(0xFFECFDF5)
                : const Color(0x1A10B981),
            barGradient: const LinearGradient(
              colors: [Color(0xFF34D399), Color(0xFF10B981)],
            ),
            isLight: isLight,
          ),
        ),
        if (asCard)
          Container(
            width: 1.0,
            height: 32,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: isLight
                ? const Color(0xFFE2E8F0)
                : Colors.white.withValues(alpha: 0.12),
          )
        else
          const SizedBox(width: 12),
        Expanded(
          child: _StatBar(
            icon: LucideIcons.gauge,
            label: 'Jarak',
            valueText: remainKmText,
            percent: distPercent,
            accentColor: const Color(0xFF2563EB),
            accentBg: isLight
                ? const Color(0xFFEFF6FF)
                : const Color(0x1A2563EB),
            barGradient: const LinearGradient(
              colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
            ),
            isLight: isLight,
          ),
        ),
      ],
    );

    Widget content = statRow;

    if (asCard) {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isLight ? Colors.white : AppColors.glassNavyTint,
          border: Border.all(
            color: isLight
                ? const Color(0xFFE2E8F0)
                : AppColors.glassBlueBorder.withValues(alpha: 0.65),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isLight
                  ? const Color(0x0A0F172A)
                  : Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: statRow,
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}

class _StatBar extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valueText;
  final double percent;
  final Color accentColor;
  final Color accentBg;
  final LinearGradient barGradient;
  final bool isLight;

  const _StatBar({
    required this.icon,
    required this.label,
    required this.valueText,
    required this.percent,
    required this.accentColor,
    required this.accentBg,
    required this.barGradient,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) {
    final labelClr = isLight
        ? const Color(0xFF64748B)
        : AppColors.glassTextSecondary;
    final valueClr = isLight
        ? const Color(0xFF0F172A)
        : AppColors.glassTextPrimary;
    final trackClr = isLight
        ? const Color(0xFFF1F5F9)
        : Colors.white.withValues(alpha: 0.10);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // Micro Icon Box
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: accentBg,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 14, color: accentColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.15,
                      fontWeight: FontWeight.w500,
                      color: labelClr,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    valueText,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: valueClr,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        // Modern Progress Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LayoutBuilder(
            builder: (context, c) => Stack(
              children: [
                Container(height: 5, width: c.maxWidth, color: trackClr),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  height: 5,
                  width: c.maxWidth * percent.clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    gradient: barGradient,
                    borderRadius: BorderRadius.circular(3),
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
