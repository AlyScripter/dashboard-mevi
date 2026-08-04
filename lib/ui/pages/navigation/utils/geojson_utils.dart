import 'package:latlong2/latlong.dart';
import 'dart:convert';

class GeoJsonUtils {
  /// Parse a GeoJSON LineString and return list of LatLng.
  static List<LatLng> decodeLineString(String geoJson) {
    final obj = jsonDecode(geoJson);
    if (obj is Map && obj['type'] == 'LineString') {
      final coords = obj['coordinates'] as List;
      return coords.map((c) => LatLng(c[1] * 1.0, c[0] * 1.0)).toList();
    }
    // If it's a FeatureCollection -> find first LineString
    if (obj is Map && obj['type'] == 'FeatureCollection') {
      for (final f in (obj['features'] as List)) {
        final g = f['geometry'];
        if (g['type'] == 'LineString') {
          final coords = g['coordinates'] as List;
          return coords.map((c) => LatLng(c[1] * 1.0, c[0] * 1.0)).toList();
        }
      }
    }
    return const [];
  }
}
