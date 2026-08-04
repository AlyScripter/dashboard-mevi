import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

class NavigationUtils {
  static double degreesToRadians(double deg) => deg * (math.pi / 180.0);

  /// Haversine distance in meters.
  static double calculateDistance(LatLng a, LatLng b) {
    const earthRadius = 6371000.0; // meters
    final dLat = degreesToRadians(b.latitude - a.latitude);
    final dLon = degreesToRadians(b.longitude - a.longitude);
    final lat1 = degreesToRadians(a.latitude);
    final lat2 = degreesToRadians(b.latitude);

    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return earthRadius * c;
  }

  static String formatTravelTime(double seconds) {
    final s = seconds.round();
    final m = s ~/ 60;
    final h = m ~/ 60;
    if (h > 0) {
      return '${h}h ${m % 60}m';
    } else if (m > 0) {
      return '${m}m ${s % 60}s';
    } else {
      return '${s}s';
    }
  }
}
