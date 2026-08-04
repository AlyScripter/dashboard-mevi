import 'package:flutter_test/flutter_test.dart';
import 'package:dashboardmevi/ui/pages/navigation/utils/geojson_parser.dart';

void main() {
  group('GeoJsonParser', () {
    group('parseGeoJson', () {
      test('parses Point features correctly', () {
        // Arrange
        const geoJson = '''
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {
                "type": "Point",
                "coordinates": [107.61, -6.88]
              },
              "properties": {
                "name": "Test Location"
              }
            }
          ]
        }
        ''';

        // Act
        final locations = GeoJsonParser.parseGeoJson(geoJson);

        // Assert
        expect(locations.length, 1);
        expect(locations[0].name, 'Test Location');
        expect(locations[0].latitude, closeTo(-6.88, 0.001));
        expect(locations[0].longitude, closeTo(107.61, 0.001));
      });

      test('handles multiple Point features', () {
        // Arrange
        const geoJson = '''
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {"type": "Point", "coordinates": [107.61, -6.88]},
              "properties": {"name": "Location 1"}
            },
            {
              "type": "Feature",
              "geometry": {"type": "Point", "coordinates": [107.62, -6.89]},
              "properties": {"name": "Location 2"}
            }
          ]
        }
        ''';

        // Act
        final locations = GeoJsonParser.parseGeoJson(geoJson);

        // Assert
        expect(locations.length, 2);
        expect(locations[0].name, 'Location 1');
        expect(locations[1].name, 'Location 2');
      });

      test('handles missing name property with fallback', () {
        // Arrange
        const geoJson = '''
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {"type": "Point", "coordinates": [107.61, -6.88]},
              "properties": {}
            }
          ]
        }
        ''';

        // Act
        final locations = GeoJsonParser.parseGeoJson(geoJson);

        // Assert
        expect(locations.length, 1);
        expect(locations[0].name, 'Unknown Location');
      });

      test('handles name with trailing space', () {
        // Arrange
        const geoJson = '''
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {"type": "Point", "coordinates": [107.61, -6.88]},
              "properties": {"name ": "Location With Space"}
            }
          ]
        }
        ''';

        // Act
        final locations = GeoJsonParser.parseGeoJson(geoJson);

        // Assert
        expect(locations.length, 1);
        expect(locations[0].name, 'Location With Space');
      });

      test('trims whitespace from names', () {
        // Arrange
        const geoJson = '''
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {"type": "Point", "coordinates": [107.61, -6.88]},
              "properties": {"name": "  Test Location  "}
            }
          ]
        }
        ''';

        // Act
        final locations = GeoJsonParser.parseGeoJson(geoJson);

        // Assert
        expect(locations[0].name, 'Test Location');
      });

      test('ignores non-Point features', () {
        // Arrange
        const geoJson = '''
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {
                "type": "LineString",
                "coordinates": [[107.61, -6.88], [107.62, -6.89]]
              },
              "properties": {"name": "Line"}
            },
            {
              "type": "Feature",
              "geometry": {"type": "Point", "coordinates": [107.63, -6.90]},
              "properties": {"name": "Point"}
            }
          ]
        }
        ''';

        // Act
        final locations = GeoJsonParser.parseGeoJson(geoJson);

        // Assert
        expect(locations.length, 1);
        expect(locations[0].name, 'Point');
      });

      test('handles invalid JSON gracefully', () {
        // Arrange
        const invalidJson = 'invalid json {[}';

        // Act
        final locations = GeoJsonParser.parseGeoJson(invalidJson);

        // Assert
        expect(locations, isEmpty);
      });

      test('handles empty features array', () {
        // Arrange
        const geoJson = '''
        {
          "type": "FeatureCollection",
          "features": []
        }
        ''';

        // Act
        final locations = GeoJsonParser.parseGeoJson(geoJson);

        // Assert
        expect(locations, isEmpty);
      });
    });

    group('extractLineStringCoordinates', () {
      test('extracts LineString coordinates correctly', () {
        // Arrange
        const geoJson = '''
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
              }
            }
          ]
        }
        ''';

        // Act
        final coords = GeoJsonParser.extractLineStringCoordinates(geoJson);

        // Assert
        expect(coords.length, 3);
        expect(coords[0], [107.61, -6.88]);
        expect(coords[1], [107.62, -6.89]);
        expect(coords[2], [107.63, -6.90]);
      });

      test('extracts multiple LineString features', () {
        // Arrange
        const geoJson = '''
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {
                "type": "LineString",
                "coordinates": [[107.61, -6.88], [107.62, -6.89]]
              }
            },
            {
              "type": "Feature",
              "geometry": {
                "type": "LineString",
                "coordinates": [[107.63, -6.90]]
              }
            }
          ]
        }
        ''';

        // Act
        final coords = GeoJsonParser.extractLineStringCoordinates(geoJson);

        // Assert
        expect(coords.length, 3); // 2 + 1 coordinates
      });

      test('ignores non-LineString features', () {
        // Arrange
        const geoJson = '''
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {"type": "Point", "coordinates": [107.61, -6.88]}
            },
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
        final coords = GeoJsonParser.extractLineStringCoordinates(geoJson);

        // Assert
        expect(coords.length, 1);
      });

      test('handles invalid JSON gracefully', () {
        // Act
        final coords = GeoJsonParser.extractLineStringCoordinates('invalid');

        // Assert
        expect(coords, isEmpty);
      });

      test('returns empty list for no LineString features', () {
        // Arrange
        const geoJson = '''
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {"type": "Point", "coordinates": [107.61, -6.88]}
            }
          ]
        }
        ''';

        // Act
        final coords = GeoJsonParser.extractLineStringCoordinates(geoJson);

        // Assert
        expect(coords, isEmpty);
      });
    });

    group('extractPolygonCoordinates', () {
      test('extracts Polygon coordinates correctly', () {
        // Arrange
        const geoJson = '''
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {
                "type": "Polygon",
                "coordinates": [
                  [
                    [107.61, -6.88],
                    [107.62, -6.88],
                    [107.62, -6.89],
                    [107.61, -6.89],
                    [107.61, -6.88]
                  ]
                ]
              }
            }
          ]
        }
        ''';

        // Act
        final polygons = GeoJsonParser.extractPolygonCoordinates(geoJson);

        // Assert
        expect(polygons.length, 1);
        expect(polygons[0].length, 5); // 5 points for closed polygon
        expect(polygons[0][0], [107.61, -6.88]);
      });

      test('extracts multiple Polygon features', () {
        // Arrange
        const geoJson = '''
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {
                "type": "Polygon",
                "coordinates": [
                  [[107.61, -6.88], [107.62, -6.88], [107.61, -6.88]]
                ]
              }
            },
            {
              "type": "Feature",
              "geometry": {
                "type": "Polygon",
                "coordinates": [
                  [[107.63, -6.90], [107.64, -6.90], [107.63, -6.90]]
                ]
              }
            }
          ]
        }
        ''';

        // Act
        final polygons = GeoJsonParser.extractPolygonCoordinates(geoJson);

        // Assert
        expect(polygons.length, 2);
      });

      test('handles Polygon with holes', () {
        // Arrange - Polygon with outer ring and inner ring (hole)
        const geoJson = '''
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {
                "type": "Polygon",
                "coordinates": [
                  [[107.61, -6.88], [107.62, -6.88], [107.62, -6.89], [107.61, -6.88]],
                  [[107.611, -6.881], [107.619, -6.881], [107.619, -6.889], [107.611, -6.881]]
                ]
              }
            }
          ]
        }
        ''';

        // Act
        final polygons = GeoJsonParser.extractPolygonCoordinates(geoJson);

        // Assert
        expect(polygons.length, 2); // Outer ring + inner ring
      });

      test('ignores non-Polygon features', () {
        // Arrange
        const geoJson = '''
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {"type": "Point", "coordinates": [107.61, -6.88]}
            },
            {
              "type": "Feature",
              "geometry": {
                "type": "Polygon",
                "coordinates": [
                  [[107.62, -6.89], [107.63, -6.89], [107.62, -6.89]]
                ]
              }
            }
          ]
        }
        ''';

        // Act
        final polygons = GeoJsonParser.extractPolygonCoordinates(geoJson);

        // Assert
        expect(polygons.length, 1);
      });

      test('handles invalid JSON gracefully', () {
        // Act
        final polygons = GeoJsonParser.extractPolygonCoordinates('invalid');

        // Assert
        expect(polygons, isEmpty);
      });

      test('returns empty list for no Polygon features', () {
        // Arrange
        const geoJson = '''
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {"type": "Point", "coordinates": [107.61, -6.88]}
            }
          ]
        }
        ''';

        // Act
        final polygons = GeoJsonParser.extractPolygonCoordinates(geoJson);

        // Assert
        expect(polygons, isEmpty);
      });
    });
  });
}
