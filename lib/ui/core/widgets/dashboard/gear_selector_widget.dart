import 'package:flutter/material.dart';

/// Circular gear pills (P R N D), styled after the reference dashboard's
/// gear row: a solid blue glowing circle behind the active gear, plain
/// white/60 text for the rest.
class GearSelectorWidget extends StatelessWidget {
  final String selectedGear;
  final Function(String) onGearChanged;
  final List<String> gears;

  /// Diameter of each circle. Defaults to 44 (the original size); pass a
  /// smaller value (e.g. 30) for a more compact row, such as when placed
  /// next to the Settings/Collapse icons at the bottom of the panel.
  final double circleSize;

  /// Font size for the gear letter. Defaults to 16; pass something
  /// smaller (e.g. 11) to match a smaller [circleSize].
  final double fontSize;

  /// Font weight for the gear letter. Defaults to w800 (bold); pass a
  /// lighter weight (e.g. FontWeight.w500) for a "thinner" look.
  final FontWeight fontWeight;

  const GearSelectorWidget({
    super.key,
    required this.selectedGear,
    required this.onGearChanged,
    this.gears = const ['P', 'R', 'N', 'D'],
    this.circleSize = 44,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w800,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: gears.map((gear) {
        final isActive = gear == selectedGear;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: circleSize * 0.09),
          child: GestureDetector(
            onTap: () => onGearChanged(gear),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              width: circleSize,
              height: circleSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? const Color(0xFF2196F3)
                    : Colors.white.withValues(alpha: 0.06),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: const Color(
                            0xFF2196F3,
                          ).withValues(alpha: 0.45),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                  color: isActive
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.45),
                  letterSpacing: -0.5,
                ),
                child: Text(gear),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
