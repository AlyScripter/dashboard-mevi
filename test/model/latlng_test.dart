import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('LatLng', () {
    test('should create LatLng', () {
      const latlng = LatLng(-6.8825, 107.6107);

      expect(latlng.latitude, -6.8825);
      expect(latlng.longitude, 107.6107);
    });

    test('should be const', () {
      const latlng1 = LatLng(-6.8825, 107.6107);
      const latlng2 = LatLng(-6.8825, 107.6107);

      expect(identical(latlng1, latlng2), true);
    });

    test('should handle different coordinates', () {
      const latlng1 = LatLng(-6.8825, 107.6107);
      const latlng2 = LatLng(-6.8826, 107.6108);

      expect(latlng1.latitude, isNot(equals(latlng2.latitude)));
      expect(latlng1.longitude, isNot(equals(latlng2.longitude)));
    });
  });
}
