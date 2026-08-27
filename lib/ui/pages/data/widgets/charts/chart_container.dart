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
    // Blue-black glass theme: dark navy card + glowing blue border,
    // replacing the old plain white card so chart panels (LiDAR,
    // Steering, CTE, Speed, IMU...) match the rest of the dashboard.
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.glassSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.glassBlueBorder.withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
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
              Icon(icon, size: 16, color: AppColors.glassBlueBorder),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.glassTextPrimary,
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
