class MapConfig {
  // Primary tile sources with fallback hierarchy
  static const String cartoDbUrl =
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
  static const List<String> cartoDbSubdomains = ['a', 'b', 'c', 'd'];

  // Alternative high-quality sources
  static const String openStreetMapUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const String wikimediaUrl =
      'https://maps.wikimedia.org/osm-intl/{z}/{x}/{y}.png';

  // Stamen terrain (good fallback)
  static const List<String> stamenSubdomains = ['a', 'b', 'c', 'd'];

  // Map display settings
  static const double maxZoom = 19.0;
  static const double minZoom = 10.0; // Reduced for better coverage
}
