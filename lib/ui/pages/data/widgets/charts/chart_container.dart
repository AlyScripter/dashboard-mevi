import 'package:flutter/material.dart';
import '../../../../../core/theme/colors.dart';

class ChartContainer extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const ChartContainer({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    // REVISI: light mode → gradient biru nav rail (1565C0 → 1976D2),
    // border 1E88E5, icon & title putih. Dark mode tetap navy.
    final cardGradient = isLight
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
          )
        : null;
    final cardColor = isLight ? null : AppColors.glassSurface;
    final cardBorder = isLight
        ? const Color(0xFF1E88E5)
        : AppColors.glassBlueBorder.withValues(alpha: 0.4);
    final cardShadow = isLight
        ? const Color(0xFF1565C0).withValues(alpha: 0.30)
        : Colors.black.withValues(alpha: 0.35);
    final iconClr = isLight ? Colors.white : AppColors.glassBlueBorder;
    final titleClr = isLight ? Colors.white : AppColors.glassTextPrimary;

    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cardColor,
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconClr),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: titleClr,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(child: child),
        ],
      ),
    );
  }
}
