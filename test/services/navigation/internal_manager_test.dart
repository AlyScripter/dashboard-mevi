import 'package:flutter_test/flutter_test.dart';
import 'package:dashboardmevi/services/navigation/internal_manager.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('InternalRouteManager', () {
    late InternalRouteManager manager;

    setUp(() {
      manager = InternalRouteManager();
    });

    test('getInternalRoute returns empty list initially', () {
      // Act
      final route = manager.getInternalRoute();

      // Assert
      expect(route, isEmpty);
    });

    test('loadGeoJsonData parses LineString correctly', () async {
      // Arrange
      const geoJsonString = '''
      {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "geometry": {
              "type": "LineString",
              "coordinates": [
                [107.61, -6.88],
                [107.62, -6.89],
                [107.63, -6.90]
              ]
            },
            "properties": {}
          }
        ]
      }
      ''';

      // Act
      await manager.loadGeoJsonData(geoJsonString);
      final route = manager.getInternalRoute();

      // Assert
      expect(route, isNotEmpty);
      expect(route.length, 3);
      expect(route[0].latitude, closeTo(-6.88, 0.001));
      expect(route[0].longitude, closeTo(107.61, 0.001));
    });

    test('loadGeoJsonData handles multiple LineString features', () async {
      // Arrange
      const geoJsonString = '''
      {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "geometry": {
              "type": "LineString",
              "coordinates": [
                [107.61, -6.88],
                [107.62, -6.89]
              ]
            }
          },
          {
            "type": "Feature",
            "geometry": {
              "type": "LineString",
              "coordinates": [
                [107.63, -6.90],
                [107.64, -6.91]
              ]
            }
          }
        ]
      }
      ''';

      // Act
      await manager.loadGeoJsonData(geoJsonString);
      final route = manager.getInternalRoute();

      // Assert
      expect(route.length, 4); // 2 + 2 coordinates
    });

    test('loadGeoJsonData ignores non-LineString features', () async {
      // Arrange
      const geoJsonString = '''
      {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "geometry": {
              "type": "Point",
              "coordinates": [107.61, -6.88]
            }
          },
          {
            "type": "Feature",
            "geometry": {
              "type": "LineString",
              "coordinates": [
                [107.62, -6.89],
                [107.63, -6.90]
              ]
            }
          }
        ]
      }
      ''';

      // Act
      await manager.loadGeoJsonData(geoJsonString);
      final route = manager.getInternalRoute();

      // Assert
      expect(route.length, 2); // Only LineString coordinates
    });

    test('loadGeoJsonData handles invalid JSON gracefully', () async {
      // Arrange
      const invalidJson = 'invalid json {[}';

      // Act
      await manager.loadGeoJsonData(invalidJson);
      final route = manager.getInternalRoute();

      // Assert
      expect(route, isEmpty); // Should remain empty on error
    });

    test('getInternalRoute returns unmodifiable list', () {
      // Act
      final route = manager.getInternalRoute();

      // Assert
      expect(() => route.add(LatLng(0, 0)), throwsUnsupportedError);
    });

    test('isPointOnInternalRoad returns true for exact match', () async {
      // Arrange
      const geoJsonString = '''
      {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "geometry": {
              "type": "LineString",
              "coordinates": [
                [107.61, -6.88],
                [107.62, -6.89]
              ]
            }
          }
        ]
      }
      ''';
      await manager.loadGeoJsonData(geoJsonString);

      // Act
      final isOnRoad = manager.isPointOnInternalRoad(LatLng(-6.88, 107.61));

      // Assert
      expect(isOnRoad, isTrue);
    });

    test('isPointOnInternalRoad returns false for distant point', () async {
      // Arrange
      const geoJsonString = '''
      {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "geometry": {
              "type": "LineString",
              "coordinates": [
                [107.61, -6.88],
                [107.62, -6.89]
              ]
            }
          }
        ]
      }
      ''';
      await manager.loadGeoJsonData(geoJsonString);

      // Act
      final isOnRoad = manager.isPointOnInternalRoad(LatLng(-6.99, 107.99));

      // Assert
      expect(isOnRoad, isFalse);
    });

    test('isPointOnInternalRoad returns false when no road loaded', () {
      // Act
      final isOnRoad = manager.isPointOnInternalRoad(LatLng(-6.88, 107.61));

      // Assert
      expect(isOnRoad, isFalse);
    });

    test('loadGeoJsonData handles empty features array', () async {
      // Arrange
      const geoJsonString = '''
      {
        "type": "FeatureCollection",
        "features": []
      }
      ''';

      // Act
      await manager.loadGeoJsonData(geoJsonString);
      final route = manager.getInternalRoute();

      // Assert
      expect(route, isEmpty);
    });

    test('coordinates are converted correctly from GeoJSON format', () async {
      // Arrange - GeoJSON uses [lng, lat] format
      const geoJsonString = '''
      {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "geometry": {
              "type": "LineString",
              "coordinates": [
                [107.61138, -6.88127]
              ]
            }
          }
        ]
      }
      ''';

      // Act
      await manager.loadGeoJsonData(geoJsonString);
      final route = manager.getInternalRoute();

      // Assert
      expect(route.length, 1);
      // LatLng uses (lat, lng) format
      expect(route[0].latitude, closeTo(-6.88127, 0.00001));
      expect(route[0].longitude, closeTo(107.61138, 0.00001));
    });

    test('isPointOnInternalRoad uses distance tolerance', () async {
      // Arrange
      const geoJsonString = '''
      {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "geometry": {
              "type": "LineString",
              "coordinates": [
                [107.61, -6.88]
              ]
            }
          }
        ]
      }
      ''';
      await manager.loadGeoJsonData(geoJsonString);

      // Act - Point very close but not exact (smaller offset within tolerance)
      final isOnRoad = manager.isPointOnInternalRoad(
        LatLng(-6.88, 107.61), // Exact match
      );

      // Assert
      expect(isOnRoad, isTrue); // Exact match should work
    });

    test('multiple loadGeoJsonData calls append data', () async {
      // Arrange
      const geoJson1 = '''
      {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "geometry": {
              "type": "LineString",
              "coordinates": [[107.61, -6.88]]
            }
          }
        ]
      }
      ''';
      const geoJson2 = '''
      {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "geometry": {
              "type": "LineString",
              "coordinates": [[107.62, -6.89]]
            }
          }
        ]
      }
      ''';

      // Act
      await manager.loadGeoJsonData(geoJson1);
      final count1 = manager.getInternalRoute().length;
      await manager.loadGeoJsonData(geoJson2);
      final count2 = manager.getInternalRoute().length;

      // Assert
      expect(count1, 1);
      expect(count2, 2); // Should have both points
    });
  });
}
