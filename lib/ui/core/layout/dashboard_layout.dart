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
import '../panels/left_panel.dart';
import '../../../services/navigation_distance_service.dart';
import '../../../services/trip_service.dart';
import '../../../services/ros_service.dart';

// Enhanced Route State Management
enum RouteState {
  noDestination,
  destinationSet,
  routePlanning,
  navigating,
  completed,
}

// Menu items with better structure
enum DashboardMenu { home, camera, data }

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
  bool _showSettings = false;
  bool _isPanelExpanded = true;

  // Animation controllers
  late AnimationController _completionController;
  late AnimationController _settingsAnimController;
  late Animation<Offset> _settingsSlideAnimation;
  late Animation<double> _settingsFadeAnimation;
  late AnimationController _panelAnimController;

  // Navigation data
  final GlobalKey<NavigationWidgetState> navigationWidgetKey =
      GlobalKey<NavigationWidgetState>();
  final NavigationDistanceService _distanceService =
      NavigationDistanceService();

  double? _routeDistanceKm;
  String? _routeEta;
  String _routeName = '';
  String _destinationName = '';

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

    // Settings page slide animation (from right)
    _settingsAnimController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _settingsSlideAnimation =
        Tween<Offset>(
          begin: const Offset(1.0, 0.0), // Start from right
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _settingsAnimController,
            curve: Curves.easeOutCubic,
          ),
        );

    _settingsFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _settingsAnimController, curve: Curves.easeOut),
    );

    // Panel animation controller (kept for future use)
    _panelAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
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

  // OPTIMIZED FOR 1920x1080 - Floating navbar version
  Widget _buildBottomOverlay() {
    final isLargeScreen = _isLargeScreen(context);

    // Responsive padding - same as fixed navbar
    final bottomPadding = isLargeScreen ? 40.0 : 24.0;
    final horizontalPadding = isLargeScreen ? 40.0 : 24.0;
    final containerSpacing = isLargeScreen ? 20.0 : 12.0;

    return Positioned(
      bottom: bottomPadding,
      left: horizontalPadding,
      right: horizontalPadding,
      child: Row(
        children: [
          _buildRouteInfoContainer(isLargeScreen),
          SizedBox(width: containerSpacing),
          _buildNavigationContainer(isLargeScreen),
        ],
      ),
    );
  }

  // Floating route info - Apple-style clean
  Widget _buildRouteInfoContainer(bool isLargeScreen) {
    final containerHeight = isLargeScreen ? 180.0 : 120.0;
    final containerPadding = isLargeScreen ? 28.0 : 18.0;

    return Expanded(
      flex: 3,
      child: Container(
        height: containerHeight,
        padding: EdgeInsets.all(containerPadding),
        decoration: _overlayBoxDecoration(isLargeScreen),
        child: Row(
          children: [
            // Left side - Route info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getRouteStatusIcon(),
                        size: isLargeScreen ? 28.0 : 24.0,
                        color: _getRouteStatusColor(),
                      ),
                      SizedBox(width: isLargeScreen ? 14 : 10),
                      Expanded(
                        child: Text(
                          _routeName,
                          style: TextStyle(
                            fontSize: isLargeScreen ? 28.0 : 23.0,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: isLargeScreen ? 3 : 2,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isLargeScreen ? 18 : 14),
                  Row(
                    children: [
                      _buildMetricItem(
                        icon: LucideIcons.car,
                        value: _getDisplayDistance(),
                        isLargeScreen: isLargeScreen,
                      ),
                      SizedBox(width: isLargeScreen ? 48.0 : 36.0),
                      _buildMetricItem(
                        icon: LucideIcons.clock,
                        value: _getDisplayEta(),
                        isLargeScreen: isLargeScreen,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Right side - Cancel button (Google Maps style)
            if (_showCancelButton) ...[
              SizedBox(width: isLargeScreen ? 24 : 16),
              _buildCancelButton(isLargeScreen: isLargeScreen),
            ],
          ],
        ),
      ),
    );
  }

  /// Build cancel button (Apple-style)
  Widget _buildCancelButton({required bool isLargeScreen}) {
    final buttonSize = isLargeScreen ? 52.0 : 44.0;
    final iconSize = isLargeScreen ? 24.0 : 22.0;

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
              blurRadius: 12,
              offset: const Offset(0, 4),
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
  }) {
    final iconSize = isLargeScreen ? 26.0 : 22.0;
    final fontSize = isLargeScreen ? 22.0 : 18.0;
    final spacing = isLargeScreen ? 12.0 : 10.0;

    return Row(
      children: [
        Icon(icon, size: iconSize, color: Colors.grey.shade600),
        SizedBox(width: spacing),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            value,
            key: ValueKey(value),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationContainer(bool isLargeScreen) {
    final containerHeight = isLargeScreen ? 180.0 : 140.0;
    final horizontalPadding = isLargeScreen ? 28.0 : 22.0;
    final verticalPadding = isLargeScreen ? 24.0 : 18.0;

    return Expanded(
      flex: 2,
      child: Container(
        height: containerHeight,
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: _overlayBoxDecoration(isLargeScreen),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Menu navigation buttons only
            ...DashboardMenu.values.map((menu) {
              return _buildNavButton(menu: menu, isLargeScreen: isLargeScreen);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required DashboardMenu menu,
    required bool isLargeScreen,
  }) {
    final isActive = _activeMenu == menu;
    final config = _getMenuConfig(menu);

    final iconSize = isLargeScreen ? 38.0 : 30.0;
    final paddingSize = isLargeScreen ? 16.0 : 14.0;
    final indicatorWidth = isLargeScreen ? 36.0 : 28.0;
    final indicatorHeight = isLargeScreen ? 4.0 : 3.0;

    return Expanded(
      child: GestureDetector(
        onTap: () => _setActiveMenu(menu),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: paddingSize),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(paddingSize),
                decoration: BoxDecoration(
                  color: isActive ? Colors.grey.shade100 : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  config.icon,
                  size: iconSize,
                  color: isActive ? Colors.black87 : Colors.grey.shade400,
                ),
              ),
              SizedBox(height: isLargeScreen ? 12 : 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: indicatorHeight,
                width: isActive ? indicatorWidth : 0,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(indicatorHeight / 2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setActiveMenu(DashboardMenu menu) {
    setState(() => _activeMenu = menu);
  }

  MenuConfig _getMenuConfig(DashboardMenu menu) {
    switch (menu) {
      case DashboardMenu.home:
        return MenuConfig(LucideIcons.map, 'Peta');
      case DashboardMenu.camera:
        return MenuConfig(LucideIcons.camera, 'Kamera');
      case DashboardMenu.data:
        return MenuConfig(LucideIcons.database, 'Data');
    }
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

  // Apple-style clean box decoration
  BoxDecoration _overlayBoxDecoration([bool isLargeScreen = false]) =>
      BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isLargeScreen ? 24 : 20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: isLargeScreen ? 32 : 24,
            offset: Offset(0, isLargeScreen ? 8 : 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: isLargeScreen ? 12 : 8,
            offset: Offset(0, isLargeScreen ? 4 : 3),
          ),
        ],
      );

  Widget _buildTopOverlay({bool compactMode = false}) {
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
    return Stack(
      children: [
        // Main dashboard (always rendered)
        Container(
          color: _activeMenu == DashboardMenu.data
              ? const Color(0xFFF2F2F2)
              : Colors.black,
          child: Row(
            children: [
              // Animated Left Panel
              AnimatedBuilder(
                animation: _panelAnimController,
                builder: (context, child) {
                  return _isPanelExpanded
                      ? Expanded(
                          flex: 2,
                          child: LeftPanel(
                            onSettingsPressed: _openSettings,
                            onTogglePanel: _togglePanel,
                            isExpanded: true,
                          ),
                        )
                      : _buildCollapsedPanel();
                },
              ),
              Expanded(
                flex: _isPanelExpanded ? 8 : 1,
                child: _activeMenu == DashboardMenu.data
                    ? _buildDataLayoutWithFixedNavbar()
                    : _buildDefaultLayoutWithFloatingNavbar(),
              ),
            ],
          ),
        ),

        // Settings page overlay with animation
        if (_showSettings)
          SlideTransition(
            position: _settingsSlideAnimation,
            child: FadeTransition(
              opacity: _settingsFadeAnimation,
              child: SettingsPage(onBack: _closeSettings),
            ),
          ),
      ],
    );
  }

  Widget _buildCollapsedPanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      width: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey.shade200, width: 1.0),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Expand button
          _buildExpandButton(),
          const Spacer(),
          // Mini speed display
          _buildMiniSpeedDisplay(),
          const Spacer(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildExpandButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _togglePanel,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            LucideIcons.panelLeftOpen,
            size: 20,
            color: Colors.grey.shade500,
          ),
        ),
      ),
    );
  }

  Widget _buildMiniSpeedDisplay() {
    return StreamBuilder<double>(
      stream: RosService().speedometerRosStream,
      builder: (context, snapshot) {
        final speed = (snapshot.data ?? 0).toInt();
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Text(
                '$speed',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'km/h',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _togglePanel() {
    setState(() {
      _isPanelExpanded = !_isPanelExpanded;
    });
    if (_isPanelExpanded) {
      _panelAnimController.reverse();
    } else {
      _panelAnimController.forward();
    }
  }

  void _openSettings() {
    setState(() => _showSettings = true);
    _settingsAnimController.forward();
  }

  Future<void> _closeSettings() async {
    await _settingsAnimController.reverse();
    setState(() => _showSettings = false);
  }

  Widget _buildDefaultLayoutWithFloatingNavbar() {
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
        if (_activeMenu == DashboardMenu.camera)
          Container(color: Colors.black, child: const CameraPage()),
        _buildTopOverlay(),
        _buildBottomOverlay(),
      ],
    );
  }

  Widget _buildDataLayoutWithFixedNavbar() {
    final isLargeScreen = _isLargeScreen(context);

    return Column(
      children: [
        Expanded(
          child: Stack(
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
          ),
        ),
        SizedBox(height: isLargeScreen ? 20 : 16),
        _buildFixedBottomNavbar(),
      ],
    );
  }

  // CONSISTENT SIZING - Fixed navbar with same dimensions as floating
  Widget _buildFixedBottomNavbar() {
    final isLargeScreen = _isLargeScreen(context);

    // Apple-style compact dimensions
    final marginSize = isLargeScreen ? 40.0 : 28.0;
    final containerHeight = isLargeScreen ? 180.0 : 140.0;
    final containerPadding = isLargeScreen ? 28.0 : 22.0;
    final spacing = isLargeScreen ? 20.0 : 16.0;

    return Container(
      margin: EdgeInsets.all(marginSize),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              height: containerHeight,
              padding: EdgeInsets.all(containerPadding),
              decoration: _overlayBoxDecoration(isLargeScreen),
              child: Row(
                children: [
                  // Left side - Route info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getRouteStatusIcon(),
                              size: isLargeScreen ? 28.0 : 24.0,
                              color: _getRouteStatusColor(),
                            ),
                            SizedBox(width: isLargeScreen ? 14 : 10),
                            Expanded(
                              child: Text(
                                _routeName,
                                style: TextStyle(
                                  fontSize: isLargeScreen ? 28.0 : 23.0,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                  letterSpacing: -0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: isLargeScreen ? 3 : 2,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isLargeScreen ? 18 : 14),
                        Row(
                          children: [
                            _buildMetricItem(
                              icon: LucideIcons.car,
                              value: _getDisplayDistance(),
                              isLargeScreen: isLargeScreen,
                            ),
                            SizedBox(width: isLargeScreen ? 48.0 : 36.0),
                            _buildMetricItem(
                              icon: LucideIcons.clock,
                              value: _getDisplayEta(),
                              isLargeScreen: isLargeScreen,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Right side - Cancel button (Google Maps style)
                  if (_showCancelButton) ...[
                    SizedBox(width: isLargeScreen ? 24 : 16),
                    _buildCancelButton(isLargeScreen: isLargeScreen),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(width: spacing),
          Expanded(
            flex: 2,
            child: Container(
              height: containerHeight,
              padding: EdgeInsets.symmetric(
                horizontal: isLargeScreen ? 28.0 : 22.0,
                vertical: isLargeScreen ? 24.0 : 18.0,
              ),
              decoration: _overlayBoxDecoration(isLargeScreen),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Menu navigation buttons only
                  ...DashboardMenu.values.map((menu) {
                    return _buildNavButton(
                      menu: menu,
                      isLargeScreen: isLargeScreen,
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cancelAutoReset();
    _completionController.dispose();
    _settingsAnimController.dispose();
    _panelAnimController.dispose();
    super.dispose();
  }
}

// Helper classes
class MenuConfig {
  final IconData icon;
  final String label;

  const MenuConfig(this.icon, this.label);
}
