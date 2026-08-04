import 'package:flutter_test/flutter_test.dart';
import 'package:dashboardmevi/model/geojson_feature.dart';
import 'package:latlong2/latlong.dart';

void main() {
group('GeoJsonFeature Extended Tests', () {
test('should create feature with basic properties', () {
final feature = GeoJsonFeature(
name: 'Test Point',
coordinates: const LatLng(-6.1751, 106.8650),
type: 'Point',
);

  expect(feature.name, 'Test Point');
  expect(feature.coordinates.latitude, -6.1751);
  expect(feature.coordinates.longitude, 106.8650);
  expect(feature.type, 'Point');
});

test('should create feature without name', () {
  final feature = GeoJsonFeature(
    coordinates: const LatLng(-6.1751, 106.8650),
    type: 'Point',
  );

  expect(feature.name, isNull);
  expect(feature.coordinates.latitude, -6.1751);
  expect(feature.coordinates.longitude, 106.8650);
  expect(feature.type, 'Point');
});

test('should create feature with LineString type', () {
  final feature = GeoJsonFeature(
    name: 'Test Route',
    coordinates: const LatLng(-6.1751, 106.8650),
    type: 'LineString',
  );

  expect(feature.name, 'Test Route');
  expect(feature.type, 'LineString');
  expect(feature.coordinates, isA<LatLng>());
});

test('should create feature with Polygon type', () {
  final feature = GeoJsonFeature(
    name: 'Test Area',
    coordinates: const LatLng(-6.1761, 106.8660),
    type: 'Polygon',
  );

  expect(feature.name, 'Test Area');
  expect(feature.type, 'Polygon');
  expect(feature.coordinates.latitude, -6.1761);
  expect(feature.coordinates.longitude, 106.8660);
});

test('should verify coordinate precision', () {
  final feature = GeoJsonFeature(
    name: 'Precision Test',
    coordinates: const LatLng(-6.17512345, 106.86501234),
    type: 'Point',
  );

  expect(feature.coordinates.latitude, closeTo(-6.175, 0.001));
  expect(feature.coordinates.longitude, closeTo(106.865, 0.001));
});

test('should handle boundary coordinates - north pole', () {
  final feature = GeoJsonFeature(
    name: 'North Pole',
    coordinates: const LatLng(90.0, 0.0),
    type: 'Point',
  );

  expect(feature.coordinates.latitude, 90.0);
  expect(feature.coordinates.longitude, 0.0);
});

test('should handle boundary coordinates - south pole', () {
  final feature = GeoJsonFeature(
    name: 'South Pole',
    coordinates: const LatLng(-90.0, 0.0),
    type: 'Point',
  );

  expect(feature.coordinates.latitude, -90.0);
  expect(feature.coordinates.longitude, 0.0);
});

test('should handle boundary coordinates - dateline', () {
  final feature = GeoJsonFeature(
    name: 'Dateline',
    coordinates: const LatLng(0.0, 180.0),
    type: 'Point',
  );

  expect(feature.coordinates.latitude, 0.0);
  expect(feature.coordinates.longitude, 180.0);
});

test('should handle different geometry types', () {
  final types = ['Point', 'LineString', 'Polygon', 'MultiPoint'];

  for (final type in types) {
    final feature = GeoJsonFeature(
      name: 'Test $type',
      coordinates: const LatLng(-6.1751, 106.8650),
      type: type,
    );

    expect(feature.type, type);
    expect(feature.coordinates, isA<LatLng>());
  }
});

test('should verify equator coordinates', () {
  final feature = GeoJsonFeature(
    name: 'Equator',
    coordinates: const LatLng(0.0, 106.8650),
    type: 'Point',
  );

  expect(feature.coordinates.latitude, 0.0);
  expect(feature.coordinates.longitude, 106.8650);
});

test('should verify prime meridian coordinates', () {
  final feature = GeoJsonFeature(
    name: 'Prime Meridian',
    coordinates: const LatLng(-6.1751, 0.0),
    type: 'Point',
  );

  expect(feature.coordinates.latitude, -6.1751);
  expect(feature.coordinates.longitude, 0.0);
});

test('should handle negative coordinates', () {
  final feature = GeoJsonFeature(
    name: 'Southern Hemisphere',
    coordinates: const LatLng(-45.0, -120.0),
    type: 'Point',
  );

  expect(feature.coordinates.latitude, -45.0);
  expect(feature.coordinates.longitude, -120.0);
});

});
}
