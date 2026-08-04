import 'package:flutter/material.dart';
// import 'package:lucide_icons_flutter/lucide_icons_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Apple-style center on car button
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
    final iconColor = color ?? Colors.grey.shade700;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
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
