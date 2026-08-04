import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
// import 'package:lucide_icons_flutter/lucide_icons_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../data/locations_data.dart';
import '../../../../services/service_locator.dart';

class DestinationMarker extends StatelessWidget {
  final LatLng destination;
  final VoidCallback? onTap;

  const DestinationMarker({super.key, required this.destination, this.onTap});

  Future<String> _getDestinationName(LatLng destination) async {
    // First check in locations data
    for (var location in LocationsData.destinations) {
      if ((location.latitude - destination.latitude).abs() < 0.0001 &&
          (location.longitude - destination.longitude).abs() < 0.0001) {
        return location.name;
      }
    }

    try {
      // Create a string representation of the coordinates
      String coordinates = '${destination.latitude}, ${destination.longitude}';

      // Fetch locations from Nominatim using the coordinates
      final results = await LocationService().fetchLocationsFromNominatim(
        coordinates,
      );

      // Return the name of the first result if found
      if (results.isNotEmpty) {
        return results.first.name;
      }
    } catch (e) {
      debugPrint('Error fetching location from Nominatim: $e');
    }

    // Fallback if no address found
    return "Unknown Location";
  }

  void _showDestinationInfoDialog(BuildContext context) async {
    String destinationName = await _getDestinationName(destination);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Row(
            children: [
              Icon(LucideIcons.mapPin, color: Colors.blueAccent, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Destination Info',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                destinationName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.compass, color: Colors.grey, size: 18),
                  const SizedBox(width: 5),
                  Text(
                    'Latitude: ${destination.latitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.compass, color: Colors.grey, size: 18),
                  const SizedBox(width: 5),
                  Text(
                    'Longitude: ${destination.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
                  },
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers: [
        Marker(
          width: 50,
          height: 50,
          point: destination,
          child: GestureDetector(
            onTap: () {
              onTap?.call();
              _showDestinationInfoDialog(context);
            },
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (Rect bounds) => const RadialGradient(
                center: Alignment.topCenter,
                stops: [.1, 5],
                colors: [
                  Color.fromARGB(255, 255, 0, 0),
                  Color.fromARGB(255, 255, 123, 0),
                ],
              ).createShader(bounds),
              child: const Icon(Icons.location_on_sharp, size: 40),
            ),
          ),
        ),
      ],
    );
  }
}
