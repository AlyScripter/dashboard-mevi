import 'package:flutter/material.dart';
// import 'package:lucide_icons_flutter/lucide_icons_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../data/locations_data.dart';
import '../../../../core/theme/colors.dart';

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
    if (!showSearchResults && !isLoading) {
      return const SizedBox.shrink();
    }

    if (isLoading) {
      return _buildContainer(
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF7DB4FF),
              ),
            ),
          ),
        ),
      );
    }

    if (searchResults.isEmpty) {
      return _buildContainer(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.searchX,
                  size: 32,
                  color: AppColors.glassTextSecondary,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tidak ada hasil ditemukan',
                  style: TextStyle(
                    color: AppColors.glassTextSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _buildContainer(
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: searchResults.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: AppColors.glassDivider,
          indent: 56,
          endIndent: 16,
        ),
        itemBuilder: (context, index) {
          final trip = searchResults[index];
          return _TripResultItem(
            trip: trip,
            onTap: () => onSelectResult(trip),
            onPreview: onPreview != null ? () => onPreview!(trip) : null,
          );
        },
      ),
    );
  }

  // REVISI 2: bukan glass/blur lagi — solid hitam biasa + border biru
  // neon saja, tanpa BackdropFilter, senada dengan search bar & panel
  // kiri (flat modern minimalis).
  Widget _buildContainer({required Widget child}) {
    return Container(
      width: 520,
      constraints: const BoxConstraints(maxHeight: 420),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.glassNavyTint,
            border: Border.all(
              color: AppColors.glassBlueBorder.withValues(alpha: 0.85),
              width: 1.4,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Individual trip result item
class _TripResultItem extends StatelessWidget {
  final TripData trip;
  final VoidCallback onTap;
  final VoidCallback? onPreview;

  const _TripResultItem({
    required this.trip,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
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
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.glassTextPrimary,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.mapPin,
                        size: 13,
                        color: AppColors.glassTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${trip.waypoints.length} titik',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.glassTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Icon(
                        LucideIcons.clock,
                        size: 13,
                        color: AppColors.glassTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${trip.estimatedDuration.toInt()} mnt',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.glassTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onPreview != null)
              IconButton(
                // Tooltip dihapus agar tidak bentrok dengan overlay
                icon: const Icon(
                  LucideIcons.eye,
                  size: 20,
                  color: AppColors.glassTextSecondary,
                ),
                splashRadius: 22,
                onPressed: () {
                  // Menjalankan fungsi preview rute setelah rendering frame selesai
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    onPreview!();
                  });
                },
              ),
            const Icon(
              LucideIcons.chevronRight,
              size: 20,
              color: AppColors.glassTextSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
