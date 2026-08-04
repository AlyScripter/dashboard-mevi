import 'package:flutter/material.dart';
import 'package:dashboardmevi/core/theme/colors.dart';
import 'package:dashboardmevi/core/theme/typography.dart';
import 'package:dashboardmevi/core/theme/dimensions.dart';

class GearSelectorWidget extends StatelessWidget {
  final String selectedGear;
  final Function(String) onGearChanged;
  final List<String> gears;

  const GearSelectorWidget({
    super.key,
    required this.selectedGear,
    required this.onGearChanged,
    this.gears = const ['P', 'N', 'R', 'D'],
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize = screenWidth * 0.02; // responsif, ±2% dari lebar layar

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: gears.map((gear) {
        final isActive = gear == selectedGear;
        return GestureDetector(
          onTap: () => onGearChanged(gear),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(
              horizontal: 8.0,
              vertical: AppDimensions.paddingS,
            ),
            decoration: isActive
                ? BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  )
                : const BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                  ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              style: AppTypography.bodyMedium.copyWith(
                fontSize: fontSize,
                color: isActive ? AppColors.primary : Colors.black,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
              child: Text(gear),
            ),
          ),
        );
      }).toList(),
    );
  }
}
