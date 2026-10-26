import 'package:flutter/material.dart';
import 'package:dashboardmevi/core/theme/colors.dart';

/// Gear selector widget (P R N D), styled as a unified luxury EV console rail.
///
/// REVISI: Mengadopsi visual style & hierarki cockpit EV modern:
/// - Light mode: Unified white card capsule, border (0xFFE2E8F0), soft shadow (0x0A0F172A).
/// - Dark mode: Dark navy tint, glass blue border, deep shadow.
/// - Gear aktif: Tech-blue vibrant gradient dengan subtle glow.
/// - Gear inaktif: Slate text yang lembut, transparan dan responsif saat ditekan.
class GearSelectorWidget extends StatelessWidget {
  final String selectedGear;
  final Function(String) onGearChanged;
  final List<String> gears;

  /// Diameter of each circle or card size.
  final double circleSize;

  /// Font size for the gear letter.
  final double fontSize;

  /// Font weight for the gear letter.
  final FontWeight fontWeight;

  /// Layout direction for the gear items.
  final Axis direction;

  /// Whether to render as squircle cards / unified console card.
  final bool useCard;

  /// Explicit size for card mode (defaults to 42 for compact modern squircle)
  final double? cardSize;

  /// Border radius for card mode (defaults to 12)
  final double? cardBorderRadius;

  const GearSelectorWidget({
    super.key,
    required this.selectedGear,
    required this.onGearChanged,
    this.gears = const ['P', 'R', 'N', 'D'],
    this.circleSize = 44,
    this.fontSize = 15,
    this.fontWeight = FontWeight.w700,
    this.direction = Axis.horizontal,
    this.useCard = false,
    this.cardSize,
    this.cardBorderRadius,
  });

  static const _activeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
  );

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final itemSize = useCard ? (cardSize ?? 42.0) : circleSize;
    final innerRadius = BorderRadius.circular(cardBorderRadius ?? 12.0);

    final gearItems = gears.map((gear) {
      final isActive = gear == selectedGear;

      final textClr = isActive
          ? Colors.white
          : (isLight ? const Color(0xFF64748B) : AppColors.glassTextSecondary);

      if (useCard) {
        return Padding(
          padding: direction == Axis.horizontal
              ? const EdgeInsets.symmetric(horizontal: 2)
              : const EdgeInsets.symmetric(vertical: 2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onGearChanged(gear),
              borderRadius: innerRadius,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: itemSize,
                height: itemSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: innerRadius,
                  gradient: isActive ? _activeGradient : null,
                  color: isActive ? null : Colors.transparent,
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  gear,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: isActive ? FontWeight.w800 : fontWeight,
                    color: textClr,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        // Circular pills mode (backward-compatible)
        final inactiveFill = isLight
            ? const Color(0xFF1A2331).withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.06);

        return Padding(
          padding: direction == Axis.horizontal
              ? EdgeInsets.symmetric(horizontal: circleSize * 0.09)
              : EdgeInsets.symmetric(vertical: circleSize * 0.09),
          child: GestureDetector(
            onTap: () => onGearChanged(gear),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: itemSize,
              height: itemSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isActive ? _activeGradient : null,
                color: isActive ? null : inactiveFill,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.40),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Text(
                gear,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: isActive ? FontWeight.w800 : fontWeight,
                  color: textClr,
                ),
              ),
            ),
          ),
        );
      }
    }).toList();

    if (useCard) {
      // Unified outer card rail for luxury cockpit look
      return Container(
        padding: const EdgeInsets.all(5),
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
        child: Flex(
          direction: direction,
          mainAxisSize: MainAxisSize.min,
          children: gearItems,
        ),
      );
    }

    return Flex(
      direction: direction,
      mainAxisSize: MainAxisSize.min,
      children: gearItems,
    );
  }
}
