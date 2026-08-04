import 'package:flutter/material.dart';
// import 'package:lucide_icons_flutter/lucide_icons_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// About Section for Settings Page
class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  LucideIcons.info,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'About',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
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
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 14),

          // Hardware Info
          _buildSubsectionTitle('Connected Hardware'),
          const SizedBox(height: 10),
          _buildHardwareGrid(),

          const SizedBox(height: 14),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 14),

          // Credits
          _buildSubsectionTitle('Development'),
          const SizedBox(height: 8),
          Text(
            'MEVI Autonomous Vehicle Project • Dashboard for monitoring and control',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
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
      children:
          items.map((item) => _buildHardwareChip(item.$1, item.$2)).toList(),
    );
  }

  Widget _buildHardwareChip(String name, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Text(
            name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
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
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
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
        color: Colors.grey.shade400,
        letterSpacing: 0.8,
      ),
    );
  }
}
