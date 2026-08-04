import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class GeoJsonLayer extends StatelessWidget {
  final String geoJsonString;

  const GeoJsonLayer({
    super.key,
    required this.geoJsonString,
    required lineStyle,
  });

  @override
  Widget build(BuildContext context) {
    final geoJson = jsonDecode(geoJsonString);
    final features = geoJson['features'] as List;

    List<Marker> markers = [];
    List<Polyline> polylines = [];
    List<Polygon> polygons = [];

    for (var feature in features) {
      final geometry = feature['geometry'];
      final type = geometry['type'];

      switch (type) {
        case 'Point':
          _parsePoint(geometry, markers);
          break;
        case 'LineString':
          _parseLineString(geometry, polylines);
          break;
        case 'Polygon':
          _parsePolygon(geometry, polygons);
          break;
      }
    }

    return Stack(
      children: [
        PolygonLayer(polygons: polygons),
        PolylineLayer(polylines: polylines),
        MarkerLayer(markers: markers),
      ],
    );
  }

  void _parsePoint(Map<String, dynamic> geometry, List<Marker> markers) {
    final coordinates = geometry['coordinates'] as List;
    final point = LatLng(coordinates[1], coordinates[0]);
    markers.add(
      Marker(
        point: point,
        width: 30,
        height: 30,
        child: const Icon(Icons.location_on, color: Colors.red),
      ),
    );
  }

  void _parseLineString(
    Map<String, dynamic> geometry,
    List<Polyline> polylines,
  ) {
    final coordinates = geometry['coordinates'] as List;
    final points = coordinates
        .map((coord) => LatLng(coord[1], coord[0]))
        .toList();
    polylines.add(
      Polyline(
        points: points.cast<LatLng>(),
        strokeWidth: 2.0,
        color: Colors.blue,
      ),
    );
  }

  void _parsePolygon(Map<String, dynamic> geometry, List<Polygon> polygons) {
    final coordinates = geometry['coordinates'][0] as List;
    final points = coordinates
        .map((coord) => LatLng(coord[1], coord[0]))
        .toList();
    polygons.add(
      Polygon(
        points: points.cast<LatLng>(),
        color: Colors.green.withValues(alpha: 0.3),
        borderColor: Colors.green,
        borderStrokeWidth: 2,
      ),
    );
  }
}
