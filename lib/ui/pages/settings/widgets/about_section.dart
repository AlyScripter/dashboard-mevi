import 'package:flutter/material.dart';
// import 'package:lucide_icons_flutter/lucide_icons_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/colors.dart';

/// About Section for Settings Page
class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.settingsCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.glassBlueBorder.withValues(alpha: 0.45),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  LucideIcons.info,
                  size: 18,
                  color: AppColors.glassTextSecondary,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'About',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.glassTextPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // App Info
          _buildInfoRow('Application', 'MEVI Dashboard'),
          _buildInfoRow('Version', '2.0.0'),
          _buildInfoRow('Platform', 'Flutter Linux'),

          const SizedBox(height: 14),
          Divider(color: AppColors.glassDivider, height: 1),
          const SizedBox(height: 14),

          // Hardware Info
          _buildSubsectionTitle('Connected Hardware'),
          const SizedBox(height: 10),
          _buildHardwareGrid(),

          const SizedBox(height: 14),
          Divider(color: AppColors.glassDivider, height: 1),
          const SizedBox(height: 14),

          // Credits
          _buildSubsectionTitle('Development'),
          const SizedBox(height: 8),
          Text(
            'MEVI Autonomous Vehicle Project • Dashboard for monitoring and control',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.glassTextSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareGrid() {
    final items = [
      ('Jetson AGX Xavier', LucideIcons.cpu),
      ('ZED Camera', LucideIcons.camera),
      ('Hokuyo LiDAR', LucideIcons.radar),
      ('Emlid RTK GPS', LucideIcons.navigation),
      ('Witmotion IMU', LucideIcons.gauge),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map((item) => _buildHardwareChip(item.$1, item.$2))
          .toList(),
    );
  }

  Widget _buildHardwareChip(String name, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.glassSurfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.glassDivider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.glassTextSecondary),
          const SizedBox(width: 6),
          Text(
            name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.glassTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.glassTextSecondary),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.glassTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubsectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.glassTextSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}
