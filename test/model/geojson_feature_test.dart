import 'package:flutter_test/flutter_test.dart';
import 'package:dashboardmevi/model/geojson_feature.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('GeoJsonFeature (from geojson_feature.dart)', () {
    test('should create GeoJsonFeature with name', () {
      final feature = GeoJsonFeature(
        name: 'Test Location',
        coordinates: LatLng(-6.8825, 107.6107),
        type: 'Point',
      );

      expect(feature.name, 'Test Location');
      expect(feature.coordinates.latitude, -6.8825);
      expect(feature.coordinates.longitude, 107.6107);
      expect(feature.type, 'Point');
    });

    test('should create GeoJsonFeature without name', () {
      final feature = GeoJsonFeature(
        coordinates: LatLng(-6.8825, 107.6107),
        type: 'Point',
      );

      expect(feature.name, isNull);
      expect(feature.coordinates.latitude, -6.8825);
      expect(feature.coordinates.longitude, 107.6107);
      expect(feature.type, 'Point');
    });

    test('should handle different types', () {
      final pointFeature = GeoJsonFeature(
        name: 'Point Feature',
        coordinates: LatLng(-6.8825, 107.6107),
        type: 'Point',
      );

      final lineFeature = GeoJsonFeature(
        name: 'Line Feature',
        coordinates: LatLng(-6.8825, 107.6107),
        type: 'LineString',
      );

      expect(pointFeature.type, 'Point');
      expect(lineFeature.type, 'LineString');
    });

    test('should store coordinates correctly', () {
      final feature = GeoJsonFeature(
        name: 'BRIN Location',
        coordinates: LatLng(-6.882577704450938, 107.6107211528497),
        type: 'Point',
      );

      expect(feature.coordinates.latitude, -6.882577704450938);
      expect(feature.coordinates.longitude, 107.6107211528497);
    });
  });
}
