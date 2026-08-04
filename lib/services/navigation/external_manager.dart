import '../../services/service_locator.dart';
import 'package:latlong2/latlong.dart';

class ExternalRouteManager {
  final LocationService _locationService = LocationService();
  Future<List<LatLng>> getExternalRoute(LatLng start, LatLng end) async {
    try {
      final response = await _locationService.getRouteFromApi(start, end);

      if (response.isNotEmpty) {
        // Parse the route response and convert to List<LatLng>
        return response
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();
      }

      throw Exception('No route found');
    } catch (e) {
      print('Error getting external route: $e');
      return [];
    }
  }
}
