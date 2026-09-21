import 'package:flutter/material.dart';
// import 'package:lucide_icons_flutter/lucide_icons_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/colors.dart';

/// About Section for Settings Page
///
/// REVISI: style light mode ditambahkan — background card jadi putih,
/// border/shadow tipis, dan teks/ikon/divider di dalamnya menyesuaikan
/// jadi warna gelap supaya tetap kontras, senada dengan kartu "Data
/// Source" di sebelahnya. Dark mode tidak berubah sama sekali.
class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    final cardBg = isLight ? Colors.white : AppColors.settingsCardBg;
    final cardBorder = isLight
        ? const Color(0xFFDDE3EC)
        : AppColors.glassBlueBorder.withValues(alpha: 0.45);
    final cardShadow = isLight
        ? Colors.black.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.35);
    final textPrimary = isLight
        ? const Color(0xFF1A2331)
        : AppColors.glassTextPrimary;
    final textSecondary = isLight
        ? const Color(0xFF5B6472)
        : AppColors.glassTextSecondary;
    final dividerClr = isLight
        ? const Color(0xFFE3E7EE)
        : AppColors.glassDivider;
    final accentBlue = isLight
        ? const Color(0xFF1565C0)
        : AppColors.glassTextSecondary;
    final iconBoxBg = isLight
        ? const Color(0xFF1A2331).withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.06);
    final chipBg = isLight
        ? const Color(0xFFF5F7FA)
        : AppColors.glassSurfaceAlt;
    final chipBorder = isLight
        ? const Color(0xFFE3E7EE)
        : AppColors.glassDivider;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: cardShadow,
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
                  color: iconBoxBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(LucideIcons.info, size: 18, color: accentBlue),
              ),
              const SizedBox(width: 12),
              Text(
                'About',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // App Info
          _buildInfoRow(
            'Application',
            'MEVI Dashboard',
            textPrimary,
            textSecondary,
          ),
          _buildInfoRow('Version', '2.0.0', textPrimary, textSecondary),
          _buildInfoRow(
            'Platform',
            'Flutter Linux',
            textPrimary,
            textSecondary,
          ),

          const SizedBox(height: 14),
          Divider(color: dividerClr, height: 1),
          const SizedBox(height: 14),

          // Hardware Info
          _buildSubsectionTitle('Connected Hardware', textSecondary),
          const SizedBox(height: 10),
          _buildHardwareGrid(textPrimary, textSecondary, chipBg, chipBorder),

          const SizedBox(height: 14),
          Divider(color: dividerClr, height: 1),
          const SizedBox(height: 14),

          // Credits
          _buildSubsectionTitle('Development', textSecondary),
          const SizedBox(height: 8),
          Text(
            'MEVI Autonomous Vehicle Project • Dashboard for monitoring and control',
            style: TextStyle(fontSize: 12, color: textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareGrid(
    Color textPrimary,
    Color textSecondary,
    Color chipBg,
    Color chipBorder,
  ) {
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
          .map(
            (item) => _buildHardwareChip(
              item.$1,
              item.$2,
              textPrimary,
              textSecondary,
              chipBg,
              chipBorder,
            ),
          )
          .toList(),
    );
  }

  Widget _buildHardwareChip(
    String name,
    IconData icon,
    Color textPrimary,
    Color textSecondary,
    Color chipBg,
    Color chipBorder,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: chipBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textSecondary),
          const SizedBox(width: 6),
          Text(
            name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubsectionTitle(String title, Color textSecondary) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}
