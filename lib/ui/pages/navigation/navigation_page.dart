import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/navigation_cubit.dart';
import 'navigation_widget.dart';

/// Complete Navigation Page with all decomposed widgets and functionality
///
/// This page now includes:
/// - GeoJSON parsing utilities (utils/geojson_parser.dart)
/// - Search results widget (widgets/search_results_widget.dart)
/// - Improved search bar with full search functionality
/// - All original navigation features from the god widget
class NavigationPage extends StatelessWidget {
  final void Function(String name, double distanceKm, String eta)? onRouteInfo;
  final VoidCallback? onClearRouteInfo;
  final VoidCallback? onRouteCompleted;
  final GlobalKey? navigationKey;

  const NavigationPage({
    super.key,
    this.onRouteInfo,
    this.onClearRouteInfo,
    this.onRouteCompleted,
    this.navigationKey,
  });

  @override
  Widget build(BuildContext context) {
    // REVISI: NavigationCubit sekarang disediakan satu level di atas
    // (lihat LayoutDashboard) supaya BevPage bisa membaca state yang
    // sama persis — di sini kita pakai `.value` untuk memakai ulang
    // instance ancestor tsb, bukan membuat instance baru yang terpisah.
    return BlocProvider.value(
      value: context.read<NavigationCubit>(),
      child: NavigationWidget(
        key: navigationKey,
        destinationLat: -6.881377969504214,
        destinationLng: 107.61154761359956,
        onMinimizedChanged: _onMinimizedChanged,
        onRouteInfo: onRouteInfo,
        onClearRouteInfo: onClearRouteInfo,
        onRouteCompleted: onRouteCompleted,
        simulateGps: false, // Set to false to use static placeholder
      ),
    );
  }

  static void _onMinimizedChanged(bool isMinimized) {
    // Handle minimized state change
    // Can be used to adjust UI when navigation is minimized
  }
}
