import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../pages/navigation/navigation_page.dart';
import '../../pages/navigation/navigation_widget.dart';
import '../../pages/navigation/bloc/navigation_cubit.dart';
import '../widgets/dashboard/weather_time_widget.dart';
import '../../pages/data/data_index.dart';
import '../../pages/camera/camera_index.dart';
import '../../pages/settings/settings_index.dart';
import '../../pages/bev/bev_page.dart';
import '../widgets/navigation/side_nav_rail.dart';
import '../../../services/navigation_distance_service.dart';
import '../../../services/trip_service.dart';
import '../../../services/voice_navigation_service.dart';
import '../../../core/theme/glass_container.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_controller.dart';

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
    if (id != 'bev') {
      VoiceNavigationService().stop();
      VoiceNavigationService().clearInstruction();
    }
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
  Widget _buildBottomOverlay() {
    final isLargeScreen = _isLargeScreen(context);
    final bottomPadding = isLargeScreen ? 32.0 : 20.0;
    final horizontalPadding = isLargeScreen ? 32.0 : 14.0;

    // Ikuti tema aktif — dark mode pakai navy glass, light mode pakai putih
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, themeMode, _) {
        final isDark = themeMode == ThemeMode.dark;
        return Positioned(
          bottom: bottomPadding,
          left: horizontalPadding,
          child: _buildRouteInfoContainer(isLargeScreen, dark: isDark),
        );
      },
    );
  }

  // Route-info card — shape changed from a full pill to a rounded
  // rectangle matching the corner radius used by the other floating
  // widgets (search bar / weather / heading HUD), and widened to sit
  // more in line with the search bar above. Pass dark: true over dark
  // backgrounds so it doesn't wash out.
  Widget _buildRouteInfoContainer(bool isLargeScreen, {bool dark = false}) {
    final screenSize = MediaQuery.of(context).size;
    final isFullHD = screenSize.width >= 1900 && screenSize.height >= 1000;

    final containerHeight = isLargeScreen ? 86.0 : 74.0;
    final horizontalPadding = isLargeScreen ? 16.0 : 14.0;
    final verticalPadding = isLargeScreen ? 12.0 : 10.0;
    final maxWidth = isFullHD ? 420.0 : 360.0;
    final cardBorderRadius = isLargeScreen ? 16.0 : 14.0;
    final iconSize = isLargeScreen ? 20.0 : 18.0;
    // Light mode: teks biru tua senada dengan nav rail & search bar terang
    final textColor = dark ? Colors.white : const Color(0xFF1A237E);
    final subTextColor = dark ? Colors.white70 : const Color(0xFF546E7A);

    return GlassContainer(
      width: maxWidth,
      height: containerHeight,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      // Rounded rectangle — radius disamakan dengan widget lain
      borderRadius: cardBorderRadius,
      blurSigma: 0,
      // Light mode: putih solid + border biru, senada dengan search bar & dropdown
      tint: dark ? AppColors.glassNavyTint : Colors.white,
      tintOpacity: 1.0,
      borderColor: dark ? AppColors.glassBlueBorder : const Color(0xFF1976D2),
      borderOpacity: 0.7,
      borderWidth: 1.2,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? 0.3 : 0.12),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
      child: Row(
        children: [
          Container(
            width: isLargeScreen ? 44 : 38,
            height: isLargeScreen ? 44 : 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: dark
                  ? LinearGradient(
                      colors: [
                        _getRouteStatusColor().withValues(alpha: 0.9),
                        _getRouteStatusColor().withValues(alpha: 0.5),
                      ],
                    )
                  : null,
              color: dark
                  ? null
                  : _getRouteStatusColor().withValues(alpha: 0.12),
            ),
            child: Icon(
              _getRouteStatusIcon(),
              size: iconSize,
              color: _getRouteStatusColor(),
            ),
          ),
          SizedBox(width: isLargeScreen ? 12 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _routeName,
                  style: TextStyle(
                    fontSize: isLargeScreen ? 14.0 : 12.5,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                SizedBox(height: isLargeScreen ? 5 : 4),
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
                    SizedBox(width: isLargeScreen ? 14.0 : 12.0),
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
            SizedBox(width: isLargeScreen ? 8 : 6),
            _buildCancelButton(isLargeScreen: isLargeScreen),
          ],
        ],
      ),
    );
  }

  /// Build cancel button (Apple-style)
  Widget _buildCancelButton({required bool isLargeScreen}) {
    final buttonSize = isLargeScreen ? 38.0 : 34.0;
    final iconSize = isLargeScreen ? 18.0 : 16.0;

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
              color: const Color(0xFFFF3B30).withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
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
    final fontSize = isLargeScreen ? 13.0 : 11.5;
    final spacing = isLargeScreen ? 5.0 : 4.0;

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
              letterSpacing: -0.2,
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

  Widget _buildTopOverlay({
    bool compactMode = false,
    bool bevMode = false,
    bool cameraMode = false,
  }) {
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

    if (cameraMode) {
      // REVISI: disejajarkan dengan top bar kamera.
      // CameraPage outer padding = 6px → weather mulai dari top=6.
      // Height weather = 38px (sama dengan dropdown) → keduanya setara.
      // right = 10px agar tidak mepet tepi frame.
      topPadding = 6.0;
      rightPadding = 10.0;
    } else if (compactMode) {
      // For DataPage - position higher to avoid collision with DataPageHeader
      topPadding = isLargeScreen ? 16.0 : (isTablet ? 10.0 : 8.0);
      rightPadding = isLargeScreen ? 20.0 : (isTablet ? 14.0 : 10.0);
    } else {
      topPadding = isLargeScreen ? 24.0 : 14.0;
      rightPadding = isLargeScreen ? 36.0 : 16.0;
    }

    return Positioned(
      top: topPadding,
      right: rightPadding,
      child: WeatherTimeWidget(compactMode: cameraMode ? true : compactMode),
    );
  }

  @override
  Widget build(BuildContext context) {
    // REVISI: NavigationCubit dipromosikan ke sini (ancestor bersama
    // NavigationPage & BevPage) supaya BEV bisa membaca rute/posisi/
    // heading navigasi yang sama persis dengan halaman Maps — dulu
    // cubit ini hanya dibuat secara lokal di dalam NavigationPage,
    // jadi BevPage (sibling-nya di Stack) tidak bisa mengaksesnya.
    return BlocProvider(
      create: (_) => NavigationCubit(),
      child: Container(
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
                  onBack: () =>
                      setState(() => _activeMenu = DashboardMenu.home),
                ),
                _ => _buildDefaultLayoutWithFloatingNavbar(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultLayoutWithFloatingNavbar() {
    final isCameraActive = _activeMenu == DashboardMenu.camera;
    final isBevActive = _activeMenu == DashboardMenu.bev;
    final isMapsActive = _activeMenu == DashboardMenu.home;
    return Stack(
      children: [
        // NavigationPage selalu aktif untuk mempertahankan polyline.
        // showSearchBar: hanya true saat halaman Maps aktif — mencegah
        // search bar & overlay dropdown muncul di Camera/BEV.
        NavigationPage(
          onRouteInfo: _handleRouteInfo,
          onClearRouteInfo: _clearRouteInfo,
          onRouteCompleted: _completeRoute,
          navigationKey: navigationWidgetKey,
          showSearchBar: isMapsActive,
        ),
        // REVISI: Background halaman kamera theme-aware — biru (senada
        // warna nav rail) di light mode, hitam seperti sebelumnya di dark mode.
        if (isCameraActive)
          ValueListenableBuilder<ThemeMode>(
            valueListenable: appThemeMode,
            builder: (context, themeMode, _) {
              final isDark = themeMode == ThemeMode.dark;
              return Container(
                // REVISI: Light: putih bersih, Dark: hitam
                color: isDark ? Colors.black : Colors.white,
                child: const CameraPage(),
              );
            },
          ),
        if (isBevActive) Container(color: Colors.black, child: const BevPage()),
        _buildTopOverlay(bevMode: isBevActive, cameraMode: isCameraActive),
        // _buildBottomOverlay sekarang theme-aware (tidak perlu arg dark)
        if (isMapsActive) _buildBottomOverlay(),
      ],
    );
  }

  Widget _buildDataLayoutWithFixedNavbar() {
    return Stack(
      children: [
        // showSearchBar: false — DataPage menimpa NavigationPage, jangan
        // biarkan search bar & dropdown tembus ke halaman Data.
        NavigationPage(
          onRouteInfo: _handleRouteInfo,
          onClearRouteInfo: _clearRouteInfo,
          onRouteCompleted: _completeRoute,
          navigationKey: navigationWidgetKey,
          showSearchBar: false,
        ),
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
