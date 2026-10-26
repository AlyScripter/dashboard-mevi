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
  final Color previewIconColor;
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
    required this.previewIconColor,
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
    previewIconColor: Color(0xFF7DB4FF),
    inkSplashColor: Color(0x0FFFFFFF),
  );

  // ── Terang: clean white + subtle border + slate typography (Edaca style) ──
  static const light = _ResultTheme(
    containerBg: Colors.white,
    containerBorder: Color(0xFFE2E8F0),
    shadow: Color(0x140F172A),
    divider: Color(0xFFF1F5F9),
    emptyIconColor: Color(0xFF94A3B8),
    emptyTextColor: Color(0xFF64748B),
    itemTitleColor: Color(0xFF0F172A),
    itemSubColor: Color(0xFF64748B),
    chevronColor: Color(0xFF94A3B8),
    previewIconColor: Color(0xFF2563EB),
    inkSplashColor: Color(0x0A2563EB),
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
    // Lebar disesuaikan dengan search bar
    final screen = WidgetsBinding
        .instance.platformDispatcher.views.first.physicalSize /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final isFullHD = screen.width >= 1900 && screen.height >= 1000;
    final dropdownWidth = isFullHD ? 420.0 : 360.0;
    final isDark = appThemeMode.value == ThemeMode.dark;

    return Container(
      width: dropdownWidth,
      constraints: const BoxConstraints(maxHeight: 380),
      decoration: BoxDecoration(
        color: t.containerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: t.containerBorder,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x40000000) : const Color(0x140F172A),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
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
    if (name.contains('satpam') || name.contains('pos')) {
      return LucideIcons.shield;
    }
    return LucideIcons.mapPin;
  }

  Color _getTripIconColor() {
    final name = trip.name.toLowerCase();
    if (name.contains('keliling')) return const Color(0xFF9333EA); // purple-600
    if (name.contains('gedung')) return const Color(0xFF2563EB); // blue-600
    if (name.contains('lab')) return const Color(0xFF0D9488); // teal-600
    if (name.contains('taman')) return const Color(0xFF16A34A); // green-600
    if (name.contains('satpam') || name.contains('pos')) {
      return const Color(0xFFD97706); // amber-600
    }
    return const Color(0xFF64748B); // slate-500
  }

  Color _getTripBgColor() {
    final isDark = appThemeMode.value == ThemeMode.dark;
    if (isDark) {
      final name = trip.name.toLowerCase();
      if (name.contains('keliling')) return const Color(0x289333EA);
      if (name.contains('gedung')) return const Color(0x282563EB);
      if (name.contains('lab')) return const Color(0x280D9488);
      if (name.contains('taman')) return const Color(0x2816A34A);
      if (name.contains('satpam') || name.contains('pos')) {
        return const Color(0x28D97706);
      }
      return const Color(0x2864748B);
    }
    final name = trip.name.toLowerCase();
    if (name.contains('keliling')) return const Color(0xFFF3E8FF); // soft purple
    if (name.contains('gedung')) return const Color(0xFFEFF6FF); // soft blue
    if (name.contains('lab')) return const Color(0xFFF0FDFA); // soft teal
    if (name.contains('taman')) return const Color(0xFFECFDF5); // soft green
    if (name.contains('satpam') || name.contains('pos')) {
      return const Color(0xFFFEF3C7); // soft amber
    }
    return const Color(0xFFF1F5F9);
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _getTripIconColor();
    final bgColor = _getTripBgColor();

    return InkWell(
      onTap: onTap,
      splashColor: t.inkSplashColor,
      highlightColor: t.inkSplashColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Icon squircle badge — modern pastel container ala Edaca
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(_getTripIcon(), size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trip.name,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: t.itemTitleColor,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(LucideIcons.mapPin,
                          size: 11.5, color: t.itemSubColor),
                      const SizedBox(width: 4),
                      Text(
                        '${trip.waypoints.length} titik',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: t.itemSubColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(LucideIcons.clock,
                          size: 11.5, color: t.itemSubColor),
                      const SizedBox(width: 4),
                      Text(
                        trip.formattedDuration,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: t.itemSubColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onPreview != null)
              Tooltip(
                message: 'Lihat rute & waypoint jalur',
                child: IconButton(
                  icon: Icon(
                    LucideIcons.eye,
                    size: 17,
                    color: t.previewIconColor,
                  ),
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () {
                    onPreview!();
                  },
                ),
              ),
            const SizedBox(width: 2),
            Icon(LucideIcons.chevronRight,
                size: 16, color: t.chevronColor),
          ],
        ),
      ),
    );
  }
}
