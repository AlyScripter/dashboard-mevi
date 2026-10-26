import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:dashboardmevi/core/theme/colors.dart';
import 'package:dashboardmevi/ui/pages/camera/widgets/bev_point_cloud_view.dart';

/// LiDAR 3D BEV Page
///
/// Halaman visualisasi 3D LiDAR Point Cloud & BEV yang dipindahkan dari
/// dropdown Camera Page menjadi halaman navigasi tersendiri.
/// Fitur, kontrol, dan visualisasi 100% utuh menggunakan [BevPointCloudView].
class LidarBevPage extends StatelessWidget {
  const LidarBevPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    // Card styles matching DataPage / DataPageHeader
    final cardBg = isLight ? Colors.white : AppColors.glassNavyTint;
    final cardBorder = isLight
        ? const Color(0xFFE2E8F0)
        : AppColors.glassBlueBorder.withValues(alpha: 0.65);
    final cardShadow = isLight
        ? const Color(0x0A0F172A)
        : Colors.black.withValues(alpha: 0.35);

    // Frame styling matching DataPage ChartContainer
    final frameBg = isLight ? Colors.white : AppColors.glassSurface;
    final frameBorder = isLight
        ? const Color(0xFFE2E8F0)
        : AppColors.glassBlueBorder.withValues(alpha: 0.45);

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
        padding: const EdgeInsets.only(left: 12, right: 12, top: 10, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar: Judul halaman & icon radar bergaya Card Data Visualization
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title Widget
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
                            LucideIcons.radar,
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
                              'LiDAR 3D BEV',
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
                              'Point Cloud & 3D Perception',
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

                  const SizedBox(width: 8),

                  // Real-time status pill
                  Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
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
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF16A34A),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'LIVE 3D SDC',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: isLight
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF4ADE80),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // LiDAR 3D BEV Frame
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(5.0),
                decoration: BoxDecoration(
                  color: frameBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: frameBorder, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: cardShadow,
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: const BevPointCloudView(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
