import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/colors.dart';

/// Center on car button.
/// THEME-AWARE: putih bersih + border biru tipis di light mode,
/// navy gelap + border biru neon di dark mode — selaras dengan
/// heading HUD, search bar, dan pill "Tentukan destinasi Anda".
class CenterOnCarButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String tooltip;
  final double? iconSize;
  final double? size;
  final Color? color;

  const CenterOnCarButton({
    super.key,
    this.onPressed,
    this.tooltip = 'Center on car',
    this.iconSize,
    this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    // --- THEME-AWARE COLORS ---
    final bgColor = isLight ? Colors.white : AppColors.glassNavyTint;
    final borderColor = isLight
        ? AppColors.primary.withValues(alpha: 0.35)
        : AppColors.glassBlueBorder.withValues(alpha: 0.85);
    final shadowColor = isLight
        ? Colors.black.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.35);
    final defaultIconColor = isLight
        ? AppColors.primary
        : const Color(0xFF7DB4FF);

    // Responsive sizing for Full HD
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isFullHD = screenWidth >= 1900 && screenHeight >= 1000;

    final buttonSize = size ?? (isFullHD ? 46.0 : 40.0);
    final icon = iconSize ?? (isFullHD ? 20.0 : 18.0);
    final iconColor = color ?? defaultIconColor;
    final borderRadiusValue = buttonSize / 2.8;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadiusValue),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          onTap: onPressed,
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(borderRadiusValue),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(LucideIcons.crosshair, size: icon, color: iconColor),
          ),
        ),
      ),
    );
  }
}
