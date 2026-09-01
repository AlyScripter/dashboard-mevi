import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../pages/navigation/navigation_page.dart';
import '../../pages/navigation/navigation_widget.dart';
import '../widgets/dashboard/weather_time_widget.dart';
import '../../pages/data/data_index.dart';
import '../../pages/camera/camera_index.dart';
import '../../pages/settings/settings_index.dart';
import '../../pages/bev/bev_page.dart';
import '../widgets/navigation/side_nav_rail.dart';
import '../../../services/navigation_distance_service.dart';
import '../../../services/trip_service.dart';
import '../../../core/theme/glass_container.dart';
import '../../../core/theme/colors.dart';

// Enhanced Route State Management
enum RouteState {
  noDestination,
  destinationSet,
  routePlanning,
  navigating,
  completed,
}

// Menu items with better structure. `settings` is a normal DashboardMenu
// value — like every other nav entry it swaps into the content area
// directly (no slide/fade overlay), so the side nav rail stays visible
// and selectable the whole time, same as Maps/Camera/Data/BEV.
enum DashboardMenu { home, camera, data, bev, settings }

class LayoutDashboard extends StatefulWidget {
  const LayoutDashboard({super.key});

  @override
  State<LayoutDashboard> createState() => _LayoutDashboardState();
}

class _LayoutDashboardState extends State<LayoutDashboard>
    with TickerProviderStateMixin {
  // Core state variables
  DashboardMenu _activeMenu = DashboardMenu.home;
  RouteState _routeState = RouteState.noDestination;
  Timer? _autoResetTimer;

  // Animation controllers
  late AnimationController _completionController;

  // Navigation data
  final GlobalKey<NavigationWidgetState> navigationWidgetKey =
      GlobalKey<NavigationWidgetState>();
  final NavigationDistanceService _distanceService =
      NavigationDistanceService();

  double? _routeDistanceKm;
  String? _routeEta;
  String _routeName = '';
  String _destinationName = '';

  // Items rendered by the new side nav rail — maps, camera, data, BEV,
  // and settings (5 total, per the updated design). Each id maps 1:1 to
  // a DashboardMenu value, so selecting any of them — including
  // settings — is a plain content swap with the rail staying put.
  static const List<SideNavItem> _navItems = [
    SideNavItem(id: 'maps', icon: LucideIcons.map, label: 'Peta'),
    SideNavItem(id: 'camera', icon: LucideIcons.camera, label: 'Kamera'),
    SideNavItem(id: 'data', icon: LucideIcons.database, label: 'Data'),
    SideNavItem(id: 'bev', icon: LucideIcons.layoutDashboard, label: 'BEV'),
    SideNavItem(
      id: 'settings',
      icon: LucideIcons.settings,
      label: 'Pengaturan',
    ),
  ];

  String get _activeNavId {
    switch (_activeMenu) {
      case DashboardMenu.home:
        return 'maps';
      case DashboardMenu.camera:
        return 'camera';
      case DashboardMenu.data:
        return 'data';
      case DashboardMenu.bev:
        return 'bev';
      case DashboardMenu.settings:
        return 'settings';
    }
  }

  void _onNavSelect(String id) {
    setState(() {
      switch (id) {
        case 'maps':
          _activeMenu = DashboardMenu.home;
          break;
        case 'camera':
          _activeMenu = DashboardMenu.camera;
          break;
        case 'data':
          _activeMenu = DashboardMenu.data;
          break;
        case 'bev':
          _activeMenu = DashboardMenu.bev;
          break;
        case 'settings':
          _activeMenu = DashboardMenu.settings;
          break;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupDistanceService();
    _setInitialState();
  }

  void _initializeAnimations() {
    _completionController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  void _setupDistanceService() {
    _distanceService.onDistanceUpdate = (remainingKm) {
      // Only update distance when actively navigating
      if (_routeState == RouteState.navigating) {
        setState(() {
          _routeDistanceKm = remainingKm;

          // Auto-complete when very close to destination (50 meters)
          if (remainingKm <= 0.05) {
            _completeRoute();
          }
        });
      }
    };
  }

  void _setInitialState() {
    setState(() {
      _routeState = RouteState.noDestination;
      _routeName = 'Tentukan destinasi Anda';
    });
  }

  // Enhanced route management methods
  void _handleRouteInfo(String name, double distanceKm, String eta) {
    _cancelAutoReset();
    _destinationName = name;

    setState(() {
      _routeState = RouteState.destinationSet;
      _routeName = 'Siap menuju $name';
      _routeDistanceKm = distanceKm;
      _routeEta = eta;
    });

    // Auto-start navigation after route is set
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _routeState == RouteState.destinationSet) {
        _startNavigation();
      }
    });
  }

  void _startNavigation() {
    _cancelAutoReset(); // Cancel any auto-reset timer when starting navigation

    setState(() {
      _routeState = RouteState.navigating;
      _routeName = 'Menuju $_destinationName';
    });
  }

  void _completeRoute() {
    _cancelAutoReset(); // Cancel any existing timer
    _completionController.forward();

    setState(() {
      _routeState = RouteState.completed;
      _routeName = 'Anda telah sampai di tujuan';
      _routeDistanceKm = 0.0;
      _routeEta = 'Selesai';
    });

    // Auto-reset after completion - increased to 5 seconds for better UX
    _scheduleAutoReset(const Duration(seconds: 15));
  }

  void _clearRouteInfo() {
    // Don't call _completeRoute() - just reset to initial state
    _cancelAutoReset();
    _resetToInitialState();
  }

  /// Cancel navigation and stop the vehicle
  Future<void> _cancelNavigation() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              LucideIcons.triangleAlert,
              color: Colors.orange.shade600,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              'Batalkan Navigasi?',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kendaraan akan berhenti dan navigasi menuju "$_destinationName" akan dibatalkan.',
              style: const TextStyle(color: Colors.black87, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.info,
                    size: 18,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Perintah stop akan dikirim ke kendaraan',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Lanjutkan',
              style: TextStyle(color: Colors.black54),
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(LucideIcons.octagon, size: 18),
            label: const Text('Berhenti'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Send stop command to vehicle
    try {
      await TripService.stopTrip();
      debugPrint('🛑 Navigation cancelled - stop command sent');
    } catch (e) {
      debugPrint('⚠️ Error sending stop command: $e');
    }

    // Clear the route polyline on the map
    navigationWidgetKey.currentState?.clearNavigation();

    // Reset navigation state
    _cancelAutoReset();
    _resetToInitialState();

    // Show feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.stop_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Navigasi dibatalkan, kendaraan berhenti'),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  /// Check if cancel button should be visible
  bool get _showCancelButton =>
      _routeState == RouteState.destinationSet ||
      _routeState == RouteState.navigating ||
      _routeState == RouteState.routePlanning;

  void _scheduleAutoReset([Duration duration = const Duration(seconds: 5)]) {
    _cancelAutoReset();
    _autoResetTimer = Timer(duration, () {
      if (mounted && _routeState == RouteState.completed) {
        _resetToInitialState();
      }
    });
  }

  void _cancelAutoReset() {
    _autoResetTimer?.cancel();
    _autoResetTimer = null;
  }

  void _resetToInitialState() {
    _completionController.reset();

    setState(() {
      _routeState = RouteState.noDestination;
      _routeName = 'Tentukan destinasi Anda';
      _routeDistanceKm = null;
      _routeEta = null;
      _destinationName = '';
    });
  }

  // Display methods - consistent sizing
  String _getDisplayDistance() {
    switch (_routeState) {
      case RouteState.noDestination:
        return '-';
      case RouteState.destinationSet:
      case RouteState.navigating:
        return _routeDistanceKm != null
            ? '${_routeDistanceKm!.toStringAsFixed(1)} KM'
            : '-';
      case RouteState.completed:
        return 'Tiba';
      case RouteState.routePlanning:
        return 'Menghitung...';
    }
  }

  String _getDisplayEta() {
    switch (_routeState) {
      case RouteState.noDestination:
        return '-';
      case RouteState.destinationSet:
      case RouteState.navigating:
        return _routeEta ?? '-';
      case RouteState.completed:
        return 'Selesai';
      case RouteState.routePlanning:
        return 'Memproses...';
    }
  }

  IconData _getRouteStatusIcon() {
    switch (_routeState) {
      case RouteState.noDestination:
        return LucideIcons.mapPin;
      case RouteState.destinationSet:
        return LucideIcons.play;
      case RouteState.routePlanning:
        return LucideIcons.loader;
      case RouteState.navigating:
        return LucideIcons.navigation;
      case RouteState.completed:
        return LucideIcons.circleCheck;
    }
  }

  Color _getRouteStatusColor() {
    switch (_routeState) {
      case RouteState.noDestination:
        return Colors.grey.shade600;
      case RouteState.destinationSet:
        return Colors.blue.shade600;
      case RouteState.routePlanning:
        return Colors.orange.shade600;
      case RouteState.navigating:
        return Colors.green.shade600;
      case RouteState.completed:
        return Colors.green.shade700;
    }
  }

  // REVISI: "Tentukan destinasi" sekarang HANYA dipanggil dari halaman
  // Maps (lihat _buildDefaultLayoutWithFloatingNavbar) — sudah tidak
  // dipakai lagi di Camera, BEV, atau Data. Bar-nya juga dibikin
  // minimalis: pill kecil menempel kiri-bawah (tidak lagi melebar
  // sampai kanan layar), warnanya disamakan dengan aksen biru neon di
  // referensi (search bar, nav rail, dsb) supaya senada satu tema.
  // REVISI: pill "Tentukan destinasi" sekarang disejajarkan penuh dengan
  // search bar "Cari tujuan perjalanan" di atasnya — inset kiri dan lebar
  // maksimum disamakan persis dengan searchBarLeft/searchBarMaxWidth di
  // navigation_widget.dart (48/720 di layar besar, 16/480 di layar kecil)
  // supaya kedua widget kelihatan satu kolom yang rapi, bukan cuma
  // "mendekati" sejajar seperti sebelumnya.
  Widget _buildBottomOverlay({bool dark = false}) {
    final isLargeScreen = _isLargeScreen(context);

    final bottomPadding = isLargeScreen ? 40.0 : 24.0;
    final horizontalPadding = isLargeScreen ? 48.0 : 16.0;

    return Positioned(
      bottom: bottomPadding,
      left: horizontalPadding,
      child: _buildRouteInfoContainer(isLargeScreen, dark: dark),
    );
  }

  // Route-info card — shape changed from a full pill to a rounded
  // rectangle matching the corner radius used by the other floating
  // widgets (search bar / weather / heading HUD), and widened to sit
  // more in line with the search bar above. Pass dark: true over dark
  // backgrounds so it doesn't wash out.
  Widget _buildRouteInfoContainer(bool isLargeScreen, {bool dark = false}) {
    // REVISI 2: lebar sebelumnya disamakan ke `searchBarMaxWidth`
    // (720/480), TAPI itu cuma sebuah ConstrainedBox longgar yang tidak
    // pernah dipakai penuh — SearchBarWidget sendiri (lihat
    // search_bar_widget.dart) sudah punya `width` tetap sendiri
    // (`barWidth = isFullHD ? 520.0 : 440.0`, berdasarkan resolusi
    // layar, bukan `isLargeScreen`/diagonal seperti di sini), jadi
    // hasilnya pill ini malah lebih lebar dari search bar aslinya.
    // Sekarang dihitung ulang persis dengan rumus + angka yang sama
    // dengan search_bar_widget.dart supaya lebarnya betul-betul sama,
    // bukan cuma dikira-kira dari `isLargeScreen`.
    final screenSize = MediaQuery.of(context).size;
    final isFullHD = screenSize.width >= 1900 && screenSize.height >= 1000;

    final containerHeight = isLargeScreen ? 110.0 : 94.0;
    final horizontalPadding = isLargeScreen ? 20.0 : 17.0;
    final verticalPadding = isLargeScreen ? 15.0 : 12.0;
    final maxWidth = isFullHD ? 520.0 : 440.0;
    final cardBorderRadius = isLargeScreen ? 22.0 : 18.0;
    final iconSize = isLargeScreen ? 24.0 : 21.0;
    final textColor = dark ? Colors.white : Colors.black87;
    final subTextColor = dark ? Colors.white70 : Colors.grey.shade600;

    return GlassContainer(
      width: maxWidth,
      height: containerHeight,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      // Rounded rectangle (bukan pill lagi) — radius disamakan dengan
      // widget kaca lain di dashboard supaya bentuknya senada.
      borderRadius: cardBorderRadius,
      blurSigma: dark ? 0 : 18,
      tint: dark ? AppColors.glassNavyTint : Colors.white,
      tintOpacity: dark ? 1.0 : 0.55,
      borderColor: dark ? AppColors.glassBlueBorder : Colors.white,
      borderOpacity: dark ? 0.85 : 0.6,
      borderWidth: dark ? 1.4 : 1.0,
      boxShadow: dark
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ]
          : null,
      child: Row(
        children: [
          Container(
            width: isLargeScreen ? 60 : 50,
            height: isLargeScreen ? 60 : 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Blue gradient badge, same accent family used by the
              // active item in the side nav rail — ties the pill back
              // to the reference's blue-highlight style.
              gradient: dark
                  ? LinearGradient(
                      colors: [
                        _getRouteStatusColor().withValues(alpha: 0.9),
                        _getRouteStatusColor().withValues(alpha: 0.5),
                      ],
                    )
                  : null,
              color: dark ? null : Colors.transparent,
            ),
            child: Icon(
              _getRouteStatusIcon(),
              // Same size as the car/clock metric icons below (was
              // 30/25 — visibly larger than the rest of the icons in
              // this pill).
              size: iconSize,
              color: dark ? Colors.white : _getRouteStatusColor(),
            ),
          ),
          SizedBox(width: isLargeScreen ? 14 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _routeName,
                  style: TextStyle(
                    fontSize: isLargeScreen ? 16.0 : 14.0,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                SizedBox(height: isLargeScreen ? 6 : 5),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMetricItem(
                      icon: LucideIcons.car,
                      value: _getDisplayDistance(),
                      isLargeScreen: isLargeScreen,
                      iconSize: iconSize,
                      color: subTextColor,
                      valueColor: textColor,
                    ),
                    SizedBox(width: isLargeScreen ? 16.0 : 14.0),
                    _buildMetricItem(
                      icon: LucideIcons.clock,
                      value: _getDisplayEta(),
                      isLargeScreen: isLargeScreen,
                      iconSize: iconSize,
                      color: subTextColor,
                      valueColor: textColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_showCancelButton) ...[
            SizedBox(width: isLargeScreen ? 10 : 8),
            _buildCancelButton(isLargeScreen: isLargeScreen),
          ],
        ],
      ),
    );
  }

  /// Build cancel button (Apple-style)
  Widget _buildCancelButton({required bool isLargeScreen}) {
    final buttonSize = isLargeScreen ? 46.0 : 40.0;
    final iconSize = isLargeScreen ? 22.0 : 19.0;

    return GestureDetector(
      onTap: _cancelNavigation,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: const Color(0xFFFF3B30), // Apple red
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF3B30).withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(LucideIcons.x, size: iconSize, color: Colors.white),
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String value,
    required bool isLargeScreen,
    required double iconSize,
    Color? color,
    Color? valueColor,
  }) {
    // REVISI: iconSize sekarang diterima dari pemanggil (disamakan
    // dengan ukuran ikon badge status) alih-alih dihitung sendiri di
    // sini, supaya semua ikon dalam pill "Tentukan destinasi Anda"
    // konsisten satu ukuran.
    final fontSize = isLargeScreen ? 16.0 : 14.0;
    final spacing = isLargeScreen ? 7.0 : 6.0;

    return Row(
      children: [
        Icon(icon, size: iconSize, color: color ?? Colors.grey.shade600),
        SizedBox(width: spacing),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            value,
            key: ValueKey(value),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: valueColor ?? Colors.black87,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }

  // Helper to detect device type based on physical size
  bool _isLargeScreen(BuildContext context) {
    final data = MediaQuery.of(context);
    final screenWidth = data.size.width;
    final screenHeight = data.size.height;

    // Calculate diagonal in inches (assuming standard DPI)
    // Tablet 11" Infinix: 1920x1200 @ 206 PPI = ~11.6 inches diagonal
    // Laptop 15": 1920x1080 @ ~141 PPI = ~15.6 inches diagonal
    final diagonal =
        math.sqrt(screenWidth * screenWidth + screenHeight * screenHeight) /
        data.devicePixelRatio;

    // Alternatively use physical size if available
    // Tablets usually < 13 inches, laptops >= 13 inches
    return diagonal >= 700; // Threshold: ~13 inches in logical pixels
  }

  Widget _buildTopOverlay({bool compactMode = false, bool bevMode = false}) {
    // REVISI: on the BEV page the weather/time chip is shrunk down to
    // roughly the same footprint as the battery/range readout in the
    // opposite corner, and pinned to the exact same 24px inset the BEV
    // page uses for that battery card — so the two line up precisely
    // instead of the weather chip floating at its own larger offset.
    if (bevMode) {
      return const Positioned(
        top: 24,
        right: 24,
        child: WeatherTimeWidget(compactMode: true),
      );
    }

    final isLargeScreen = _isLargeScreen(context);
    final data = MediaQuery.of(context);
    final screenWidth = data.size.width;
    final screenHeight = data.size.height;
    final diagonal =
        math.sqrt(screenWidth * screenWidth + screenHeight * screenHeight) /
        data.devicePixelRatio;
    final isTablet = diagonal >= 500 && diagonal < 700;

    // Adjust position based on mode and device type
    final double topPadding;
    final double rightPadding;

    if (compactMode) {
      // For DataPage - position higher to avoid collision with DataPageHeader
      topPadding = isLargeScreen ? 18.0 : (isTablet ? 12.0 : 10.0);
      rightPadding = isLargeScreen ? 24.0 : (isTablet ? 16.0 : 12.0);
    } else {
      topPadding = isLargeScreen ? 36.0 : 16.0;
      rightPadding = isLargeScreen ? 48.0 : 20.0;
    }

    return Positioned(
      top: topPadding,
      right: rightPadding,
      child: WeatherTimeWidget(compactMode: compactMode),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Blue-black glass theme: Data/Settings pages paint their own dark
      // navy gradient (see DataPage / SettingsPage), so the outer shell
      // stays plain black for every menu instead of switching background
      // per page.
      color: Colors.black,
      child: Row(
        children: [
          // Permanent slim icon rail — replaces the old expandable
          // gauge/BEV left panel. All 5 navigation entries (maps,
          // camera, data, BEV, settings) live here now, styled per
          // the reference EV head-unit sidebar. It stays mounted and
          // interactive no matter which page is active, including
          // Settings — selecting any icon is a plain content swap in
          // the Expanded next to it, with no slide/fade transition.
          SideNavRail(
            items: _navItems,
            activeId: _activeNavId,
            onSelect: _onNavSelect,
          ),
          Expanded(
            child: switch (_activeMenu) {
              DashboardMenu.data => _buildDataLayoutWithFixedNavbar(),
              DashboardMenu.settings => SettingsPage(
                onBack: () => setState(() => _activeMenu = DashboardMenu.home),
              ),
              _ => _buildDefaultLayoutWithFloatingNavbar(),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultLayoutWithFloatingNavbar() {
    final isCameraActive = _activeMenu == DashboardMenu.camera;
    final isBevActive = _activeMenu == DashboardMenu.bev;
    // REVISI: "Tentukan destinasi" sekarang eksklusif untuk halaman
    // Maps — tidak relevan lagi ditampilkan di atas Camera/BEV.
    final isMapsActive = _activeMenu == DashboardMenu.home;
    return Stack(
      children: [
        // Keep NavigationPage always active to preserve polyline
        NavigationPage(
          onRouteInfo: _handleRouteInfo,
          onClearRouteInfo: _clearRouteInfo,
          onRouteCompleted: _completeRoute,
          navigationKey: navigationWidgetKey,
        ),
        // Overlay other pages on top when active
        if (isCameraActive)
          Container(color: Colors.black, child: const CameraPage()),
        if (isBevActive) Container(color: Colors.black, child: const BevPage()),
        _buildTopOverlay(bevMode: isBevActive),
        if (isMapsActive) _buildBottomOverlay(dark: true),
      ],
    );
  }

  Widget _buildDataLayoutWithFixedNavbar() {
    // REVISI: bar "Tentukan destinasi" dihapus dari halaman Data (dulu
    // _buildFixedBottomNavbar) — sekarang cuma tampil di halaman Maps.
    return Stack(
      children: [
        // Keep NavigationPage active to preserve polyline state
        NavigationPage(
          onRouteInfo: _handleRouteInfo,
          onClearRouteInfo: _clearRouteInfo,
          onRouteCompleted: _completeRoute,
          navigationKey: navigationWidgetKey,
        ),
        // DataPage overlays the navigation
        const DataPage(),
        _buildTopOverlay(compactMode: true),
      ],
    );
  }

  @override
  void dispose() {
    _cancelAutoReset();
    _completionController.dispose();
    super.dispose();
  }
}
