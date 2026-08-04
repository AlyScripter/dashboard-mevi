import 'package:latlong2/latlong.dart';

class GeoJsonFeature {
  final String? name;
  final LatLng coordinates;
  final String type;

  const GeoJsonFeature({
    this.name,
    required this.coordinates,
    required this.type,
  });
}