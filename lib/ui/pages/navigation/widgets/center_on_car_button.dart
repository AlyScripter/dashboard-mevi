import 'package:flutter/material.dart';
// import 'package:lucide_icons_flutter/lucide_icons_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/colors.dart';

/// Center on car button.
/// REVISI: dulu solid putih polos (beda sendiri dari widget kaca
/// lainnya) — sekarang disamakan dengan tema kaca navy + border biru
/// neon yang dipakai heading HUD, search bar, dan pill "Tentukan
/// destinasi Anda" supaya senada satu tema.
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
    // Responsive sizing for Full HD
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isFullHD = screenWidth >= 1900 && screenHeight >= 1000;

    final buttonSize = size ?? (isFullHD ? 56.0 : 48.0);
    final icon = iconSize ?? (isFullHD ? 24.0 : 22.0);
    final iconColor = color ?? const Color(0xFF7DB4FF);
    final borderRadiusValue = buttonSize / 2.6;

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
              color: AppColors.glassNavyTint,
              borderRadius: BorderRadius.circular(borderRadiusValue),
              border: Border.all(
                color: AppColors.glassBlueBorder.withValues(alpha: 0.85),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 14,
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
