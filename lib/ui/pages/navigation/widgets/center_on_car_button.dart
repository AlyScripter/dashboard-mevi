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

    // --- THEME-AWARE COLORS (Edaca style) ---
    final bgColor = isLight ? Colors.white : AppColors.glassNavyTint;
    final borderColor = isLight
        ? const Color(0xFFE2E8F0)
        : AppColors.glassBlueBorder.withValues(alpha: 0.85);
    final shadowColor = isLight
        ? const Color(0x0C0F172A)
        : Colors.black.withValues(alpha: 0.35);
    final defaultIconColor = isLight
        ? const Color(0xFF2563EB)
        : const Color(0xFF7DB4FF);

    // Responsive sizing for Full HD
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isFullHD = screenWidth >= 1900 && screenHeight >= 1000;

    final buttonSize = size ?? (isFullHD ? 44.0 : 40.0);
    final icon = iconSize ?? (isFullHD ? 19.0 : 17.5);
    final iconColor = color ?? defaultIconColor;
    final borderRadiusValue = 13.0;

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
              border: Border.all(color: borderColor, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 16,
                  offset: const Offset(0, 4),
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
