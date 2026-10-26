import 'package:flutter/material.dart';
import '../../../../../core/theme/colors.dart';

class ChartContainer extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;
  final Color? iconColor;
  final Color? iconBadgeBg;

  const ChartContainer({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
    this.iconColor,
    this.iconBadgeBg,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    // ── Edaca / Modern Autonomous Dashboard Card Style ──
    final cardColor = isLight ? Colors.white : AppColors.glassSurface;
    final cardBorder = isLight
        ? const Color(0xFFE2E8F0)
        : AppColors.glassBlueBorder.withValues(alpha: 0.45);
    final cardShadow = isLight
        ? const Color(0x0A0F172A)
        : Colors.black.withValues(alpha: 0.35);

    final badgeBg = isLight
        ? (iconBadgeBg ?? const Color(0xFFEFF6FF))
        : (iconColor?.withValues(alpha: 0.16) ?? const Color(0x1A7DB4FF));
    final iconClr = isLight
        ? (iconColor ?? const Color(0xFF2563EB))
        : (iconColor ?? const Color(0xFF7DB4FF));
    final titleClr = isLight
        ? const Color(0xFF0F172A)
        : AppColors.glassTextPrimary;

    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: cardShadow,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconClr),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: titleClr,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}
