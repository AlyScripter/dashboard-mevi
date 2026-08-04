import 'dart:convert';
import '../../../../model/location.dart';

class GeoJsonParser {
  /// Parse GeoJSON string into a list of locations
  static List<Location> parseGeoJson(String geoJsonString) {
    final List<Location> locations = [];

    try {
      final Map<String, dynamic> geoJson = jsonDecode(geoJsonString);

      for (var feature in geoJson['features']) {
        final properties = feature['properties'];
        final coordinates = feature['geometry']['coordinates'];

        if (feature['geometry']['type'] == 'Point') {
          // Extract name from properties with fallback options
          String name =
              properties['name'] ??
              properties['name '] ?? // Handle space after 'name'
              'Unknown Location';

          locations.add(
            Location(
              latitude: coordinates[1].toDouble(),
              longitude: coordinates[0].toDouble(),
              name: name.trim(), // Remove any extra whitespace
            ),
          );
        }
        // Can handle Polygon or LineString if necessary in the future
      }
    } catch (e) {
      print('Error parsing GeoJSON: $e');
    }

    return locations;
  }

  /// Extract LineString coordinates from GeoJSON
  static List<List<double>> extractLineStringCoordinates(String geoJsonString) {
    final List<List<double>> coordinates = [];

    try {
      final Map<String, dynamic> geoJson = jsonDecode(geoJsonString);

      for (var feature in geoJson['features']) {
        if (feature['geometry']['type'] == 'LineString') {
          List<dynamic> coords = feature['geometry']['coordinates'];
          for (var coord in coords) {
            coordinates.add([coord[0].toDouble(), coord[1].toDouble()]);
          }
        }
      }
    } catch (e) {
      print('Error extracting LineString coordinates: $e');
    }

    return coordinates;
  }

  /// Extract Polygon coordinates from GeoJSON
  static List<List<List<double>>> extractPolygonCoordinates(
    String geoJsonString,
  ) {
    final List<List<List<double>>> polygons = [];

    try {
      final Map<String, dynamic> geoJson = jsonDecode(geoJsonString);

      for (var feature in geoJson['features']) {
        if (feature['geometry']['type'] == 'Polygon') {
          List<dynamic> coordinates = feature['geometry']['coordinates'];

          for (var ring in coordinates) {
            List<List<double>> polygon = (ring as List)
                .map<List<double>>(
                  (coord) => [
                    (coord[0] as num).toDouble(),
                    (coord[1] as num).toDouble(),
                  ],
                )
                .toList();
            polygons.add(polygon);
          }
        }
      }
    } catch (e) {
      print('Error extracting Polygon coordinates: $e');
    }

    return polygons;
  }
}
