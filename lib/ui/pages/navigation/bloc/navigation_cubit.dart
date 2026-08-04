import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'navigation_state.dart';
import '../utils/navigation_utils.dart';
import '../utils/geojson_utils.dart';
import '../../../../services/ros_service.dart';

class NavigationCubit extends Cubit<NavigationState> {
  final RosService _ros = RosService();
  StreamSubscription? _gpsSub;
  bool _sensorsHooked = false;

  NavigationCubit() : super(NavigationState.initial());

  /// Pastikan sensor (ROS GPS stream) terhubung sekali
  void ensureSensorsHooked() {
    if (_sensorsHooked) return;
    _sensorsHooked = true;

    _gpsSub = _ros.gpsStream.listen((gps) {
      final lat = gps['lat'] ?? state.current.latitude;
      final lon = gps['lng'] ?? state.current.longitude;

      emit(state.copyWith(current: LatLng(lat, lon)));
    });
  }

  void onPanStart(DragStartDetails d) {}

  void onPanUpdate(DragUpdateDetails d) {}

  Future<void> selectDestination(LatLng latLng) async {
    emit(state.copyWith(destination: latLng, isLoading: true));

    // publish ke ROS → biar MPC jalan
    _ros.publishDestinationCoordinates(latLng.latitude, latLng.longitude);

    // bikin polyline sementara (langsung garis lurus)
    final route = [state.current, latLng];
    final dist = NavigationUtils.calculateDistance(state.current, latLng);
    // Travel time estimation: dist / 10 m/s converted to readable format
    NavigationUtils.formatTravelTime(dist / 10 * 3600);

    emit(state.copyWith(routePoints: route, isLoading: false));
  }

  void loadGeoJsonAndRoute(String geoJsonString) {
    final points = GeoJsonUtils.decodeLineString(geoJsonString);
    emit(state.copyWith(routePoints: points));
  }

  @override
  Future<void> close() {
    _gpsSub?.cancel();
    return super.close();
  }
}
