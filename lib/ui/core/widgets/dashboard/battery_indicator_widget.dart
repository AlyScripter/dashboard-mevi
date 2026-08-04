import 'package:flutter/material.dart';
import 'package:dashboardmevi/core/theme/dimensions.dart';

class BatteryIndicatorWidget extends StatelessWidget {
  final double batteryPercent;
  final VoidCallback onTap;

  const BatteryIndicatorWidget({
    super.key,
    required this.batteryPercent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final percentText = '${(batteryPercent * 100).toStringAsFixed(0)}%';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 145,
        height: 40,
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 0, 0, 0),
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          border: Border.all(color: Colors.grey.shade600, width: 1.2),
        ),
        child: Stack(
          children: [
            // Fill
            LayoutBuilder(
              builder: (context, c) => AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                width: c.maxWidth * batteryPercent,
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
            Center(
              child: Text(
                percentText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: batteryPercent > 0.15 ? Colors.white : Colors.black,
                  letterSpacing: .5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
