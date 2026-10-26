import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'widgets/data_source_section.dart';
import 'widgets/about_section.dart';
import '../../../core/theme/colors.dart';

/// Settings Page - Dedicated page for system configuration & data source
///
/// REVISI: Mengadopsi visual style & layout dari Menu Data / LiDAR BEV:
/// 1. Background light mode menggunakan slate-50 (0xFFF8FAFC), bukan biru solid,
///    sehingga serasi dengan halaman Data & LiDAR BEV.
/// 2. Background dark mode menggunakan dark navy linear gradient.
/// 3. Judul "Settings" ditempatkan di luar card pada Top Bar (tinggi 54px)
///    dengan icon box rounded biru dan subtitle deskriptif.
/// 4. Menyediakan area yang luas untuk DataSourceSection & AboutSection
///    tanpa merubah fungsi data stream sama sekali.
class SettingsPage extends StatefulWidget {
  final VoidCallback? onBack;

  const SettingsPage({super.key, this.onBack});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    // Card styling matching DataPage / LidarBevPage
    final cardBg = isLight ? Colors.white : AppColors.glassNavyTint;
    final cardBorder = isLight
        ? const Color(0xFFE2E8F0)
        : AppColors.glassBlueBorder.withValues(alpha: 0.65);
    final cardShadow = isLight
        ? const Color(0x0A0F172A)
        : Colors.black.withValues(alpha: 0.35);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          color: isLight ? const Color(0xFFF8FAFC) : null,
          gradient: isLight
              ? null
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF12161F), Color(0xFF0A0D13)],
                ),
        ),
        padding: const EdgeInsets.only(left: 14, right: 14, top: 10, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar: Judul halaman di luar card (meniru konsep Menu Data / LiDAR BEV)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title Header Card
                  Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder, width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: cardShadow,
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isLight
                                ? const Color(0xFFEFF6FF)
                                : const Color(0x1A7DB4FF),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            LucideIcons.settings,
                            size: 19,
                            color: isLight
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF7DB4FF),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Settings',
                              style: TextStyle(
                                fontSize: 14.0,
                                height: 1.15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                color: isLight
                                    ? const Color(0xFF0F172A)
                                    : AppColors.glassTextPrimary,
                              ),
                            ),
                            Text(
                              'Data Source & System Preferences',
                              style: TextStyle(
                                fontSize: 10.5,
                                height: 1.15,
                                fontWeight: FontWeight.w500,
                                color: isLight
                                    ? const Color(0xFF64748B)
                                    : AppColors.glassTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Main Content: Data Source & About Section side-by-side
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: BouncingScrollPhysics(),
                      child: DataSourceSection(),
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: BouncingScrollPhysics(),
                      child: AboutSection(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
