import 'package:latlong2/latlong.dart';
import '../../../../services/ros_service.dart';

/// Thin wrapper if you want to keep non-UI navigation logic out of Cubit.
class NavigationService {
  final RosService _ros = RosService();

  void publishDestination(LatLng dest) {
    _ros.publishDestinationCoordinates(dest.latitude, dest.longitude);
  }
}
