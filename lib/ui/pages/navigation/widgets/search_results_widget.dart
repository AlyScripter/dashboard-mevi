import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../data/locations_data.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_controller.dart';

// ─── Tema token untuk SearchResults ──────────────────────────────────────────
class _ResultTheme {
  final Color containerBg;
  final Color containerBorder;
  final Color shadow;
  final Color divider;
  final Color emptyIconColor;
  final Color emptyTextColor;
  final Color itemTitleColor;
  final Color itemSubColor;
  final Color chevronColor;
  final Color inkSplashColor;

  const _ResultTheme({
    required this.containerBg,
    required this.containerBorder,
    required this.shadow,
    required this.divider,
    required this.emptyIconColor,
    required this.emptyTextColor,
    required this.itemTitleColor,
    required this.itemSubColor,
    required this.chevronColor,
    required this.inkSplashColor,
  });

  // ── Gelap: identik dengan sebelumnya ───────────────────────────────────────
  static const dark = _ResultTheme(
    containerBg: AppColors.glassNavyTint,
    containerBorder: AppColors.glassBlueBorder,
    shadow: Color(0x66000000),
    divider: AppColors.glassDivider,
    emptyIconColor: AppColors.glassTextSecondary,
    emptyTextColor: AppColors.glassTextSecondary,
    itemTitleColor: AppColors.glassTextPrimary,
    itemSubColor: AppColors.glassTextSecondary,
    chevronColor: AppColors.glassTextSecondary,
    inkSplashColor: Color(0x0FFFFFFF),
  );

  // ── Terang: putih bersih + border biru ─────────────────────────────────────
  static const light = _ResultTheme(
    containerBg: Colors.white,
    containerBorder: Color(0xFF1976D2),
    shadow: Color(0x33000000),
    divider: Color(0xFFBBDEFB),
    emptyIconColor: Color(0xFF90A4AE),
    emptyTextColor: Color(0xFF546E7A),
    itemTitleColor: Color(0xFF1A237E),
    itemSubColor: Color(0xFF546E7A),
    chevronColor: Color(0xFF90A4AE),
    inkSplashColor: Color(0x0F1565C0),
  );
}

class SearchResultsWidget extends StatelessWidget {
  final List<TripData> searchResults;
  final bool showSearchResults;
  final bool isLoading;
  final Function(TripData) onSelectResult;
  final Function(TripData)? onPreview;

  const SearchResultsWidget({
    super.key,
    required this.searchResults,
    required this.showSearchResults,
    required this.isLoading,
    required this.onSelectResult,
    this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    if (!showSearchResults && !isLoading) return const SizedBox.shrink();

    // ValueListenableBuilder: dropdown ikut berganti tema saat tombol ditekan
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, themeMode, _) {
        final isDark = themeMode == ThemeMode.dark;
        final t = isDark ? _ResultTheme.dark : _ResultTheme.light;

        if (isLoading) {
          return _buildContainer(
            t: t,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: isDark
                        ? const Color(0xFF7DB4FF)
                        : const Color(0xFF1565C0),
                  ),
                ),
              ),
            ),
          );
        }

        if (searchResults.isEmpty) {
          return _buildContainer(
            t: t,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.searchX, size: 32, color: t.emptyIconColor),
                    const SizedBox(height: 12),
                    Text(
                      'Tidak ada hasil ditemukan',
                      style: TextStyle(color: t.emptyTextColor, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return _buildContainer(
          t: t,
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: searchResults.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: t.divider,
              indent: 56,
              endIndent: 16,
            ),
            itemBuilder: (context, index) {
              final trip = searchResults[index];
              return _TripResultItem(
                trip: trip,
                t: t,
                onTap: () => onSelectResult(trip),
                onPreview: onPreview != null ? () => onPreview!(trip) : null,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildContainer({required _ResultTheme t, required Widget child}) {
    // Lebar disesuaikan dengan search bar: isFullHD → 520, selainnya → 440
    // (rumus identik dengan barWidth di search_bar_widget.dart)
    final screen = WidgetsBinding
        .instance.platformDispatcher.views.first.physicalSize /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final isFullHD = screen.width >= 1900 && screen.height >= 1000;
    final dropdownWidth = isFullHD ? 520.0 : 440.0;

    return Container(
      width: dropdownWidth,
      constraints: const BoxConstraints(maxHeight: 420),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: t.shadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: t.containerBg,
            border: Border.all(
              color: t.containerBorder.withValues(alpha: 0.85),
              width: 1.4,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── Item baris perjalanan ────────────────────────────────────────────────────
class _TripResultItem extends StatelessWidget {
  final TripData trip;
  final _ResultTheme t;
  final VoidCallback onTap;
  final VoidCallback? onPreview;

  const _TripResultItem({
    required this.trip,
    required this.t,
    required this.onTap,
    this.onPreview,
  });

  IconData _getTripIcon() {
    final name = trip.name.toLowerCase();
    if (name.contains('keliling')) return LucideIcons.navigation;
    if (name.contains('gedung')) return LucideIcons.building2;
    if (name.contains('lab')) return LucideIcons.flaskConical;
    if (name.contains('taman')) return LucideIcons.trees;
    if (name.contains('satpam') || name.contains('pos'))
      return LucideIcons.shield;
    return LucideIcons.mapPin;
  }

  Color _getTripColor() {
    final name = trip.name.toLowerCase();
    if (name.contains('keliling')) return Colors.purple.shade600;
    if (name.contains('gedung')) return Colors.blue.shade600;
    if (name.contains('lab')) return Colors.teal.shade600;
    if (name.contains('taman')) return Colors.green.shade600;
    if (name.contains('satpam') || name.contains('pos'))
      return Colors.orange.shade600;
    return Colors.grey.shade600;
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _getTripColor();

    return InkWell(
      onTap: onTap,
      splashColor: t.inkSplashColor,
      highlightColor: t.inkSplashColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            // Icon badge — warna ikon kategori tetap vivid di kedua mode
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_getTripIcon(), size: 22, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: t.itemTitleColor,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(LucideIcons.mapPin,
                          size: 13, color: t.itemSubColor),
                      const SizedBox(width: 4),
                      Text(
                        '${trip.waypoints.length} titik',
                        style:
                            TextStyle(fontSize: 13, color: t.itemSubColor),
                      ),
                      const SizedBox(width: 14),
                      Icon(LucideIcons.clock,
                          size: 13, color: t.itemSubColor),
                      const SizedBox(width: 4),
                      Text(
                        '${trip.estimatedDuration.toInt()} mnt',
                        style:
                            TextStyle(fontSize: 13, color: t.itemSubColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onPreview != null)
              IconButton(
                icon:
                    Icon(LucideIcons.eye, size: 20, color: t.chevronColor),
                splashRadius: 22,
                onPressed: () {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    onPreview!();
                  });
                },
              ),
            Icon(LucideIcons.chevronRight,
                size: 20, color: t.chevronColor),
          ],
        ),
      ),
    );
  }
}
