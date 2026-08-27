import 'dart:async';
import 'package:flutter/material.dart';
// import 'package:lucide_icons_flutter/lucide_icons_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../model/location.dart';
import '../../../../data/locations_data.dart';
import '../../../../services/trip_service.dart';
import '../../../../core/theme/glass_container.dart';
import '../../../../core/theme/colors.dart';
import 'search_results_widget.dart';

class SearchBarWidget extends StatefulWidget {
  final Function(Location) onLocationSelected;
  final void Function(Location)? onPreviewLocation;

  const SearchBarWidget({
    super.key,
    required this.onLocationSelected,
    this.onPreviewLocation,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final TextEditingController _searchController = TextEditingController();
  final LayerLink _layerLink = LayerLink();

  // State
  List<TripData> _searchResults = [];
  bool _showSearchResults = false;
  bool _isSearching = false;
  bool _disposed = false;

  // Timers
  Timer? _searchTimer;
  Timer? _overlayAutoHide;

  // Overlay
  OverlayEntry? _overlayEntry;

  // Debounce config
  static const _searchDebounce = Duration(milliseconds: 350);
  static const _overlayHideDelay = Duration(seconds: 10);

  @override
  void dispose() {
    _disposed = true;
    _searchController.dispose();
    _searchTimer?.cancel();
    _overlayAutoHide?.cancel();
    _removeOverlay();
    super.dispose();
  }

  /// Show all available trips as suggestions
  void _showTripSuggestions() {
    if (_disposed) return;
    setState(() {
      _searchResults = LocationsData.predefinedTrips;
      _showSearchResults = true;
      _isSearching = false;
    });
    _showOverlay();
  }

  // Overlay helpers
  void _showOverlay() {
    try {
      _removeOverlay();
      _overlayEntry = _createOverlayEntry();
      // FIX: rootOverlay:true menaruh dropdown ini di overlay paling atas
      // aplikasi, terpisah jauh dari search bar (CompositedTransformTarget).
      // Saat ada rebuild besar di layout utama (mis. preview rute, BEV
      // panel), CompositedTransformFollower kehilangan sinkronisasi layer
      // -> 'debugNeedsLayout' assertion. Pakai Overlay terdekat saja.
      Overlay.of(context).insert(_overlayEntry!);

      // Auto-hide overlay after inactivity
      _overlayAutoHide?.cancel();
      _overlayAutoHide = Timer(_overlayHideDelay, () {
        if (!_disposed) _removeOverlay();
      });
    } catch (_) {}
  }

  void _removeOverlay() {
    try {
      _overlayEntry?.remove();
    } catch (_) {}
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        return Positioned(
          width: 520,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 70),
            child: Material(
              color: Colors.transparent,
              elevation: 0,
              child: SearchResultsWidget(
                searchResults: _searchResults,
                showSearchResults: _showSearchResults || _isSearching,
                isLoading: _isSearching,
                onSelectResult: _selectSearchResult,
                onPreview: (trip) {
                  // FIX: tutup dropdown dulu SEBELUM memicu perubahan besar
                  // di layout utama (preview rute -> setState di parent).
                  // Kalau overlay masih terpasang saat rebuild besar terjadi,
                  // CompositedTransformFollower-nya rawan race condition.
                  _removeOverlay();

                  // FIX: jalankan setelah frame ini selesai layout+paint,
                  // supaya tidak "memotong" pipeline layout yang sedang
                  // berjalan di frame yang sama dengan klik ini.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_disposed || !mounted) return;
                    widget.onPreviewLocation?.call(trip.destination);
                    // Pakai `this.context` milik SearchBarWidgetState, BUKAN
                    // `context` dari builder OverlayEntry di atas -- yang itu
                    // sudah tidak valid setelah _removeOverlay() dipanggil.
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('Preview: ${trip.name}'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  });
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// Debounced search - filter trips by query
  void _onSearchChanged(String query) {
    _searchTimer?.cancel();

    if (query.isEmpty) {
      _showTripSuggestions();
      return;
    }

    setState(() => _isSearching = true);
    _showOverlay();

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

      if (_showSearchResults) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    });
  }

  /// Handle trip selection with confirmation dialog
  Future<void> _selectSearchResult(TripData trip) async {
    _removeOverlay();
    if (mounted) {
      setState(() {
        _showSearchResults = false;
        _searchResults = [];
      });
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.glassSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppColors.glassBlueBorder.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.glassBlueBorder.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                LucideIcons.navigation,
                size: 20,
                color: const Color(0xFF7DB4FF),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Konfirmasi Perjalanan',
                style: TextStyle(
                  color: AppColors.glassTextPrimary,
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
              style: const TextStyle(
                color: AppColors.glassTextPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              trip.destination.name,
              style: const TextStyle(
                color: AppColors.glassTextSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            _TripDetailCard(trip: trip),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.glassTextSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            icon: const Icon(LucideIcons.play, size: 18),
            label: const Text('Mulai Perjalanan'),
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.glassBlueBorder,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    _searchController.text = trip.name;

    // Loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const _LoadingDialog(message: 'Mengirim tujuan ke kendaraan...'),
    );

    try {
      final success = await TripService.startTrip(trip.name);

      if (!mounted) return;
      Navigator.of(context).pop();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  LucideIcons.circleCheck,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Perjalanan dimulai: ${trip.name}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        widget.onLocationSelected(trip.destination);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(LucideIcons.circleAlert, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Gagal memulai perjalanan. Pastikan sistem aktif.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    // Responsive sizing for Full HD
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isFullHD = screenWidth >= 1900 && screenHeight >= 1000;

    final barHeight = isFullHD ? 60.0 : 52.0;
    final barWidth = isFullHD ? 520.0 : 440.0;
    final iconSize = isFullHD ? 22.0 : 20.0;
    final fontSize = isFullHD ? 16.0 : 15.0;
    final borderRadius = isFullHD ? 18.0 : 16.0;

    return CompositedTransformTarget(
      link: _layerLink,
      // REVISI 2: bukan glass/blur lagi — solid hitam biasa + border
      // biru neon, gaya flat modern minimalis (blurSigma: 0 = tanpa
      // BackdropFilter sama sekali).
      child: GlassContainer(
        height: barHeight,
        width: barWidth,
        borderRadius: borderRadius,
        padding: EdgeInsets.zero,
        blurSigma: 0,
        tint: AppColors.glassNavyTint,
        tintOpacity: 1.0,
        borderColor: AppColors.glassBlueBorder,
        borderOpacity: 0.85,
        borderWidth: 1.4,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        child: Row(
          children: [
            const SizedBox(width: 18),
            Icon(
              LucideIcons.search,
              color: const Color(0xFF7DB4FF),
              size: iconSize,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                onTap: () {
                  if (_searchController.text.isEmpty) {
                    _showTripSuggestions();
                  }
                },
                cursorColor: AppColors.glassBlueBorder,
                decoration: InputDecoration(
                  hintText: 'Cari tujuan perjalanan...',
                  hintStyle: TextStyle(
                    color: AppColors.glassTextSecondary,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.3,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                style: TextStyle(
                  color: AppColors.glassTextPrimary,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            // Tombol X: sebelumnya hanya muncul kalau ada teks yang
            // diketik. Masalahnya, tap kosong pada search bar juga
            // langsung memunculkan daftar saran tujuan (lihat
            // _showTripSuggestions di atas) — jadi kalau user tap lalu
            // berubah pikiran, tidak ada cara menutup listnya karena
            // teksnya masih kosong. Sekarang tombol X juga muncul kalau
            // daftar tujuan sedang tampil (_showSearchResults), tidak
            // cuma saat ada teks.
            if (_searchController.text.isNotEmpty ||
                _showSearchResults ||
                _isSearching)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  _removeOverlay();
                  setState(() {
                    _searchResults = [];
                    _showSearchResults = false;
                    _isSearching = false;
                  });
                  FocusScope.of(context).unfocus();
                },
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.x,
                      color: AppColors.glassTextSecondary,
                      size: 14,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/// Loading dialog widget
class _LoadingDialog extends StatelessWidget {
  final String message;
  const _LoadingDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.glassSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.glassBlueBorder.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFF7DB4FF),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.glassTextPrimary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Trip detail card for confirmation dialog
class _TripDetailCard extends StatelessWidget {
  final TripData trip;
  const _TripDetailCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassSurfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trip.description,
            style: const TextStyle(
              color: AppColors.glassTextSecondary,
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
              ),
              const SizedBox(width: 12),
              _InfoChip(
                icon: LucideIcons.clock,
                label: '${trip.estimatedDuration.toInt()} menit',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small info chip widget
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.glassSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.glassDivider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF7DB4FF)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.glassTextSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
