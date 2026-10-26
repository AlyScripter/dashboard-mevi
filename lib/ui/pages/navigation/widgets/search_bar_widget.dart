import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../model/location.dart';
import '../../../../data/locations_data.dart';
import '../../../../services/trip_service.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_controller.dart';
import 'search_results_widget.dart';
import 'in_app_notification_widget.dart';

// ─── Tema token untuk SearchBar ───────────────────────────────────────────────
// Semua warna widget dikontrol melalui kelas ini, bukan hardcode di dalam build.
class _NavTheme {
  final Color containerBg;
  final Color containerBorder;
  final Color iconColor;
  final Color hintColor;
  final Color textColor;
  final Color clearBtnBg;
  final Color clearBtnIcon;
  final Color shadow;
  final Color dialogBg;
  final Color dialogBorder;
  final Color dialogTitleColor;
  final Color dialogBodyColor;
  final Color dialogSubColor;
  final Color dialogDetailBg;
  final Color dialogDetailBorder;
  final Color chipBg;
  final Color chipBorder;
  final Color chipIconColor;
  final Color chipTextColor;

  const _NavTheme({
    required this.containerBg,
    required this.containerBorder,
    required this.iconColor,
    required this.hintColor,
    required this.textColor,
    required this.clearBtnBg,
    required this.clearBtnIcon,
    required this.shadow,
    required this.dialogBg,
    required this.dialogBorder,
    required this.dialogTitleColor,
    required this.dialogBodyColor,
    required this.dialogSubColor,
    required this.dialogDetailBg,
    required this.dialogDetailBorder,
    required this.chipBg,
    required this.chipBorder,
    required this.chipIconColor,
    required this.chipTextColor,
  });

  // ── Mode gelap: sama persis dengan sebelumnya ──────────────────────────────
  static const dark = _NavTheme(
    containerBg: AppColors.glassNavyTint,
    containerBorder: AppColors.glassBlueBorder,
    iconColor: Color(0xFF7DB4FF),
    hintColor: AppColors.glassTextSecondary,
    textColor: AppColors.glassTextPrimary,
    clearBtnBg: Color(0x14FFFFFF),
    clearBtnIcon: AppColors.glassTextSecondary,
    shadow: Color(0x59000000),
    dialogBg: AppColors.glassSurface,
    dialogBorder: AppColors.glassBlueBorder,
    dialogTitleColor: AppColors.glassTextPrimary,
    dialogBodyColor: AppColors.glassTextPrimary,
    dialogSubColor: AppColors.glassTextSecondary,
    dialogDetailBg: AppColors.glassSurfaceAlt,
    dialogDetailBorder: AppColors.glassDivider,
    chipBg: AppColors.glassSurface,
    chipBorder: AppColors.glassDivider,
    chipIconColor: Color(0xFF7DB4FF),
    chipTextColor: AppColors.glassTextSecondary,
  );

  // ── Mode terang: clean white + subtle border + slate typography (Edaca style) ──
  static const light = _NavTheme(
    containerBg: Colors.white,
    containerBorder: Color(0xFFE2E8F0),
    iconColor: Color(0xFF64748B),
    hintColor: Color(0xFF94A3B8),
    textColor: Color(0xFF0F172A),
    clearBtnBg: Color(0xFFF1F5F9),
    clearBtnIcon: Color(0xFF64748B),
    shadow: Color(0x0F0F172A),
    dialogBg: Colors.white,
    dialogBorder: Color(0xFFE2E8F0),
    dialogTitleColor: Color(0xFF0F172A),
    dialogBodyColor: Color(0xFF1E293B),
    dialogSubColor: Color(0xFF64748B),
    dialogDetailBg: Color(0xFFF8FAFC),
    dialogDetailBorder: Color(0xFFE2E8F0),
    chipBg: Color(0xFFF1F5F9),
    chipBorder: Color(0xFFE2E8F0),
    chipIconColor: Color(0xFF2563EB),
    chipTextColor: Color(0xFF334155),
  );
}

class SearchBarWidget extends StatefulWidget {
  final Function(Location) onLocationSelected;
  final void Function(Location)? onPreviewLocation;
  final void Function(TripData)? onPreviewTrip;

  const SearchBarWidget({
    super.key,
    required this.onLocationSelected,
    this.onPreviewLocation,
    this.onPreviewTrip,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final TextEditingController _searchController = TextEditingController();

  List<TripData> _searchResults = [];
  bool _showSearchResults = false;
  bool _isSearching = false;
  bool _disposed = false;

  Timer? _searchTimer;

  static const _searchDebounce = Duration(milliseconds: 350);

  @override
  void dispose() {
    _disposed = true;
    _searchController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  void _showTripSuggestions() {
    if (_disposed) return;
    setState(() {
      _searchResults = LocationsData.predefinedTrips;
      _showSearchResults = true;
      _isSearching = false;
    });
  }

  void _handlePreview(TripData trip) {
    if (_disposed || !mounted) return;
    setState(() {
      _showSearchResults = false;
      _searchResults = [];
      _isSearching = false;
    });
    _searchController.text = trip.name;
    FocusScope.of(context).unfocus();

    if (widget.onPreviewTrip != null) {
      widget.onPreviewTrip!(trip);
    } else if (widget.onPreviewLocation != null) {
      widget.onPreviewLocation!(trip.destination);
    }
  }

  void _onSearchChanged(String query) {
    _searchTimer?.cancel();
    if (query.isEmpty) {
      _showTripSuggestions();
      return;
    }
    setState(() {
      _isSearching = true;
      _showSearchResults = true;
    });
    _searchTimer = Timer(_searchDebounce, () {
      if (_disposed) return;
      final lower = query.toLowerCase();
      final filtered = LocationsData.predefinedTrips
          .where(
            (trip) =>
                trip.name.toLowerCase().contains(lower) ||
                trip.description.toLowerCase().contains(lower) ||
                trip.destination.name.toLowerCase().contains(lower),
          )
          .toList();
      setState(() {
        _searchResults = filtered;
        _showSearchResults = true;
        _isSearching = false;
      });
    });
  }

  Future<void> _selectSearchResult(TripData trip) async {
    if (mounted) {
      setState(() {
        _showSearchResults = false;
        _searchResults = [];
      });
    }

    // Baca tema saat dialog ditampilkan
    final isDark = appThemeMode.value == ThemeMode.dark;
    final t = isDark ? _NavTheme.dark : _NavTheme.light;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ConfirmDialog(trip: trip, t: t),
    );

    if (confirmed != true || !mounted) return;

    _searchController.text = trip.name;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _LoadingDialog(message: 'Mengirim tujuan ke kendaraan...', t: t),
    );

    try {
      final success = await TripService.startTrip(trip.name);
      if (!mounted) return;
      Navigator.of(context).pop();

      if (success) {
        CenterNotification.show(
          context,
          message: 'Perjalanan dimulai: ${trip.name}',
          kind: NotificationKind.success,
          duration: const Duration(seconds: 3),
        );
        widget.onLocationSelected(trip.destination);
      } else {
        CenterNotification.show(
          context,
          message: 'Gagal memulai perjalanan. Pastikan sistem aktif.',
          kind: NotificationKind.error,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      CenterNotification.show(
        context,
        message: 'Error: $e',
        kind: NotificationKind.error,
        duration: const Duration(seconds: 4),
      );
    }

    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isFullHD = screenWidth >= 1900 && screenHeight >= 1000;

    final barHeight = isFullHD ? 48.0 : 44.0;
    final barWidth = isFullHD ? 420.0 : 360.0;
    final iconSize = isFullHD ? 19.0 : 17.5;
    final fontSize = isFullHD ? 13.5 : 12.5;
    final borderRadius = 16.0;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, themeMode, _) {
        final isDark = themeMode == ThemeMode.dark;
        final t = isDark ? _NavTheme.dark : _NavTheme.light;

        final showDropdown = (_showSearchResults || _isSearching) &&
            (_searchResults.isNotEmpty || _isSearching || _searchController.text.isNotEmpty);

        return TapRegion(
          onTapOutside: (_) {
            if (_showSearchResults || _isSearching) {
              setState(() {
                _showSearchResults = false;
                _isSearching = false;
              });
              FocusScope.of(context).unfocus();
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: barHeight,
                width: barWidth,
                decoration: BoxDecoration(
                  color: t.containerBg,
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(
                    color: t.containerBorder,
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? const Color(0x33000000) : const Color(0x0C0F172A),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 14, right: 10),
                      child: Icon(
                        LucideIcons.search,
                        color: t.iconColor,
                        size: iconSize,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          onTap: () {
                            if (_searchController.text.isEmpty) {
                              _showTripSuggestions();
                            } else {
                              setState(() => _showSearchResults = true);
                            }
                          },
                          cursorColor: isDark ? const Color(0xFF7DB4FF) : const Color(0xFF2563EB),
                          textAlignVertical: TextAlignVertical.center,
                          strutStyle: StrutStyle(
                            fontSize: fontSize,
                            height: 1.2,
                            forceStrutHeight: true,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Cari tujuan perjalanan...',
                            hintStyle: TextStyle(
                              color: t.hintColor,
                              fontSize: fontSize,
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.2,
                              height: 1.2,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: TextStyle(
                            color: t.textColor,
                            fontSize: fontSize,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.2,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty ||
                        _showSearchResults ||
                        _isSearching)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _showSearchResults = false;
                            _isSearching = false;
                          });
                          FocusScope.of(context).unfocus();
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6, right: 10),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: t.clearBtnBg,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              LucideIcons.x,
                              color: t.clearBtnIcon,
                              size: 13,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (showDropdown) ...[
                const SizedBox(height: 8),
                SearchResultsWidget(
                  searchResults: _searchResults,
                  showSearchResults: true,
                  isLoading: _isSearching,
                  onSelectResult: _selectSearchResult,
                  onPreview: _handlePreview,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── Dialog Konfirmasi ────────────────────────────────────────────────────────
class _ConfirmDialog extends StatelessWidget {
  final TripData trip;
  final _NavTheme t;
  const _ConfirmDialog({required this.trip, required this.t});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: t.dialogBg,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: t.dialogBorder.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: t.dialogBorder.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              LucideIcons.navigation,
              size: 20,
              color: t.chipIconColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Konfirmasi Perjalanan',
              style: TextStyle(
                color: t.dialogTitleColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trip.name,
            style: TextStyle(
              color: t.dialogBodyColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            trip.destination.name,
            style: TextStyle(color: t.dialogSubColor, fontSize: 13),
          ),
          const SizedBox(height: 16),
          _TripDetailCard(trip: trip, t: t),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: t.dialogSubColor,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text('Batal'),
        ),
        ElevatedButton.icon(
          icon: const Icon(LucideIcons.play, size: 18),
          label: const Text('Mulai Perjalanan'),
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Loading Dialog ───────────────────────────────────────────────────────────
class _LoadingDialog extends StatelessWidget {
  final String message;
  final _NavTheme t;
  const _LoadingDialog({required this.message, required this.t});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: t.dialogBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: t.dialogBorder.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: t.chipIconColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(color: t.dialogBodyColor, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Trip Detail Card (di dalam dialog konfirmasi) ────────────────────────────
class _TripDetailCard extends StatelessWidget {
  final TripData trip;
  final _NavTheme t;
  const _TripDetailCard({required this.trip, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.dialogDetailBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.dialogDetailBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trip.description,
            style: TextStyle(
              color: t.dialogSubColor,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoChip(
                icon: LucideIcons.mapPin,
                label: '${trip.waypoints.length} titik',
                t: t,
              ),
              const SizedBox(width: 12),
              _InfoChip(
                icon: LucideIcons.clock,
                label: trip.formattedDurationLong,
                t: t,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Info Chip ────────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final _NavTheme t;
  const _InfoChip({required this.icon, required this.label, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: t.chipBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: t.chipBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: t.chipIconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: t.chipTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
