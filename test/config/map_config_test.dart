import 'package:flutter_test/flutter_test.dart';
import 'package:dashboardmevi/config/map_config.dart';

void main() {
  group('MapConfig', () {
    test('should have correct tile URLs', () {
      expect(
        MapConfig.cartoDbUrl,
        'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
      );
      expect(
        MapConfig.openStreetMapUrl,
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      );
      expect(
        MapConfig.wikimediaUrl,
        'https://maps.wikimedia.org/osm-intl/{z}/{x}/{y}.png',
      );
    });

    test('should have correct subdomains', () {
      expect(MapConfig.cartoDbSubdomains, ['a', 'b', 'c', 'd']);
      expect(MapConfig.stamenSubdomains, ['a', 'b', 'c', 'd']);
    });

    test('should have correct zoom settings', () {
      expect(MapConfig.maxZoom, 19.0);
      expect(MapConfig.minZoom, 10.0);
    });
  });
}
