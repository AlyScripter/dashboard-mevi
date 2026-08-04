import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

class NavigationState extends Equatable {
  final LatLng center;
  final LatLng current;
  final LatLng? destination;
  final List<LatLng> routePoints;
  final double zoom;
  final bool isLoading;
  final String? error;
  final double fallbackHeadingDeg;

  const NavigationState({
    required this.center,
    required this.current,
    this.destination,
    this.routePoints = const [],
    this.zoom = 16.0,
    this.isLoading = false,
    this.error,
    this.fallbackHeadingDeg = 0.0,
  });

  NavigationState copyWith({
    LatLng? center,
    LatLng? current,
    LatLng? destination,
    List<LatLng>? routePoints,
    double? zoom,
    bool? isLoading,
    String? error,
    double? fallbackHeadingDeg,
  }) {
    return NavigationState(
      center: center ?? this.center,
      current: current ?? this.current,
      destination: destination ?? this.destination,
      routePoints: routePoints ?? this.routePoints,
      zoom: zoom ?? this.zoom,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      fallbackHeadingDeg: fallbackHeadingDeg ?? this.fallbackHeadingDeg,
    );
  }

  static NavigationState initial() => const NavigationState(
    center: LatLng(-6.2088, 106.8456),
    current: LatLng(-6.2088, 106.8456),
    destination: null,
    routePoints: [],
    zoom: 16.0,
    isLoading: false,
    error: null,
    fallbackHeadingDeg: 0.0,
  );

  @override
  List<Object?> get props => [
    center,
    current,
    destination,
    routePoints,
    zoom,
    isLoading,
    error,
    fallbackHeadingDeg,
  ];
}
