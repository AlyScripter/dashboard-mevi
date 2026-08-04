import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../config/api_keys.dart';
import '../model/location.dart';
import '../model/response_route.dart';
import 'package:geolocator/geolocator.dart';
// import 'package:geolocator_linux/geolocator_linux.dart';  // Disabled for ARM64
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class LocationService {
  final String apiKey = ApiKeys.mapboxAccessToken;

  // Primary method to get route - now with fallback to free services
  Future<RouteResponse?> getRoute(Location start, Location destination) async {
    // Try OSRM first (completely free, no API key needed)
    try {
      return await _getOSRMRoute(start, destination);
    } catch (e) {
      print('OSRM routing failed: $e');
    }

    // Fallback to OpenRouteService (free tier available)
    try {
      return await _getOpenRouteServiceRoute(start, destination);
    } catch (e) {
      print('OpenRouteService routing failed: $e');
    }

    // Last fallback: simple straight line with estimated distance
    return _getStraightLineRoute(start, destination);
  }

  // OSRM routing (completely free)
  Future<RouteResponse?> _getOSRMRoute(
    Location start,
    Location destination,
  ) async {
    final String url =
        'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}?steps=true&geometries=geojson&overview=full';

    print('Requesting OSRM route URL: $url');

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['routes'] != null && data['routes'].isNotEmpty) {
        final route = data['routes'][0];

        // Extract route coordinates
        final geometry = route['geometry'];
        List<List<double>> coordinates = [];

        if (geometry != null && geometry['coordinates'] != null) {
          for (var coord in geometry['coordinates']) {
            if (coord is List && coord.length >= 2) {
              coordinates.add([coord[0].toDouble(), coord[1].toDouble()]);
            }
          }
        }

        // Format distance and duration
        String distance = '${(route['distance'] / 1000).toStringAsFixed(2)} km';
        String duration = '${(route['duration'] / 60).toStringAsFixed(0)} mins';

        return RouteResponse(
          coordinates: coordinates,
          distance: distance,
          duration: duration,
        );
      }
    } else {
      print('Failed to fetch OSRM route. Status code: ${response.statusCode}');
      print('Response body: ${response.body}');
      return null;
    }
    return null;
  }

  // OpenRouteService routing (free tier)
  Future<RouteResponse?> _getOpenRouteServiceRoute(
    Location start,
    Location destination,
  ) async {
    final String url =
        'https://api.openrouteservice.org/v2/directions/driving-car?api_key=${ApiKeys.openRouteServiceApiKey}&start=${start.longitude},${start.latitude}&end=${destination.longitude},${destination.latitude}';

    print('Requesting OpenRouteService route URL: $url');

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['features'] != null && data['features'].isNotEmpty) {
        final feature = data['features'][0];
        final geometry = feature['geometry'];
        final properties = feature['properties'];

        List<List<double>> coordinates = [];

        if (geometry != null && geometry['coordinates'] != null) {
          for (var coord in geometry['coordinates']) {
            if (coord is List && coord.length >= 2) {
              coordinates.add([coord[0].toDouble(), coord[1].toDouble()]);
            }
          }
        }

        // Format distance and duration from properties
        String distance =
            '${(properties['summary']['distance'] / 1000).toStringAsFixed(2)} km';
        String duration =
            '${(properties['summary']['duration'] / 60).toStringAsFixed(0)} mins';

        return RouteResponse(
          coordinates: coordinates,
          distance: distance,
          duration: duration,
        );
      }
    } else {
      print(
        'Failed to fetch OpenRouteService route. Status code: ${response.statusCode}',
      );
      print('Response body: ${response.body}');
      return null;
    }
    return null;
  }

  // Straight line fallback
  RouteResponse _getStraightLineRoute(Location start, Location destination) {
    // Calculate straight line distance using Haversine formula
    const double earthRadius = 6371; // km
    double lat1Rad = start.latitude * (math.pi / 180);
    double lat2Rad = destination.latitude * (math.pi / 180);
    double deltaLatRad =
        (destination.latitude - start.latitude) * (math.pi / 180);
    double deltaLngRad =
        (destination.longitude - start.longitude) * (math.pi / 180);

    double a =
        math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLngRad / 2) *
            math.sin(deltaLngRad / 2);
    double c = 2 * math.asin(math.sqrt(a));
    double distance = earthRadius * c;

    // Simple straight line coordinates
    List<List<double>> coordinates = [
      [start.longitude, start.latitude],
      [destination.longitude, destination.latitude],
    ];

    // Estimate time (assuming 50 km/h average speed)
    String duration = '${(distance / 50 * 60).toStringAsFixed(0)} mins';

    return RouteResponse(
      coordinates: coordinates,
      distance: '${distance.toStringAsFixed(2)} km',
      duration: duration,
    );
  }

  Future<List<Location>> getRouteFromApi(LatLng start, LatLng end) async {
    // Try OSRM first (free routing service)
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${end.longitude},${end.latitude}'
        '?geometries=geojson&overview=full',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final geometry = data['routes'][0]['geometry'];
          final coordinates = geometry['coordinates'] as List;

          return coordinates.map((coord) {
            return Location(
              latitude: coord[1],
              longitude: coord[0],
              name: 'Route Point',
            );
          }).toList();
        }
      }

      throw Exception('Failed to get route from OSRM');
    } catch (e) {
      print('Error fetching route from OSRM: $e');

      // Fallback to simple straight line
      return [
        Location(
          latitude: start.latitude,
          longitude: start.longitude,
          name: 'Start',
        ),
        Location(latitude: end.latitude, longitude: end.longitude, name: 'End'),
      ];
    }
  }

  Future<Position?> checkPermissionAndGetLocation(BuildContext context) async {
    try {
      // Removed GeolocatorLinux.registerWith() for ARM64 compatibility
      if (Platform.isLinux) {
        // GeolocatorLinux.registerWith();  // Disabled for ARM64
        print('Linux platform detected - using default geolocator');
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context.mounted) {
          _showSnackBar(context, 'Location services are disabled.');
        }
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (context.mounted) {
            _showSnackBar(context, 'Location permissions are denied');
          }
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (context.mounted) {
          _showSnackBar(
            context,
            'Location permissions are permanently denied, we cannot request permissions.',
          );
        }
        return null;
      }

      return await Geolocator.getCurrentPosition();
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, 'Error getting location: $e');
      }
      return null;
    }
  }

  // Future<Position?> checkPermissionAndGetLocation(
  //   BuildContext context,
  //   RosService rosService,
  // ) async {
  //   try {
  //     if (Platform.isLinux) {
  //       GeolocatorLinux.registerWith();
  //     }
  //     // Check location permission
  //     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  //     if (!serviceEnabled) {
  //       _showSnackBar(context, 'Location services are disabled.');
  //       return null;
  //     }

  //     LocationPermission permission = await Geolocator.checkPermission();
  //     if (permission == LocationPermission.denied) {
  //       permission = await Geolocator.requestPermission();
  //       if (permission == LocationPermission.denied) {
  //         _showSnackBar(context, 'Location permissions are denied');
  //         return null;
  //       }
  //     }

  //     if (permission == LocationPermission.deniedForever) {
  //       _showSnackBar(
  //         context,
  //         'Location permissions are permanently denied, we cannot request permissions.',
  //       );
  //       return null;
  //     }

  //     // Get latitude and longitude from ROS
  //     double? latitude;
  //     double? longitude;

  //     // Listen to the ROS latitude and longitude stream
  //     rosService.latitudeStream.listen((lat) {
  //       latitude = lat;
  //     });

  //     rosService.longitudeStream.listen((lon) {
  //       longitude = lon;
  //     });

  //     await Future.delayed(const Duration(seconds: 10));

  //     if (latitude != null && longitude != null) {
  //       return Position(
  //         latitude: latitude!,
  //         longitude: longitude!,
  //         timestamp: DateTime.now(),
  //         accuracy: 1.0,
  //         altitude: 0.0,
  //         altitudeAccuracy: 1.0,
  //         heading: 0.0,
  //         headingAccuracy: 1.0,
  //         speed: 0.0,
  //         speedAccuracy: 1.0,
  //       );
  //     } else {
  //       _showSnackBar(context, 'Failed to get location from ROS.');
  //       return null;
  //     }
  //   } catch (e) {
  //     print('Error getting location: $e');
  //     _showSnackBar(context, 'Error getting location: $e');
  //     return null;
  //   }
  // }

  Future<String?> getAddressFromCoordinates(Position position) async {
    try {
      // Use Nominatim (free OpenStreetMap geocoding)
      String url =
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1';

      print('Requesting URL: $url');

      var response = await http.get(Uri.parse(url));

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        if (data['display_name'] != null) {
          return data['display_name'];
        } else {
          print('No results found in the response.');
          return null;
        }
      } else {
        print('Failed to fetch address. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error retrieving address: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> searchDestination(String query) async {
    // Use Nominatim for free geocoding
    final Uri uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&countrycodes=id&limit=5&addressdetails=1',
    );

    print("Requesting: $uri");

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        print("Full Response Data: $data");

        List<Map<String, dynamic>> results = [];

        if (data is List) {
          for (var place in data) {
            print("Processing place: $place");

            String name = place['display_name'] ?? 'Unknown location';
            double lat = double.tryParse(place['lat'].toString()) ?? 0.0;
            double lng = double.tryParse(place['lon'].toString()) ?? 0.0;

            results.add({'name': name, 'lat': lat, 'lng': lng});
          }
        } else {
          print("Unexpected response format.");
        }

        return results;
      } else {
        throw Exception(
          'Failed to fetch search results: ${response.statusCode}',
        );
      }
    } catch (e) {
      print("Error fetching locations: $e");
      throw Exception('Error fetching location data from Nominatim API: $e');
    }
  }

  Future<List<Location>> fetchLocationsFromNominatim(String query) async {
    // Updated to use Nominatim instead of Mapbox
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?format=json&q=$query&countrycodes=id&limit=5&addressdetails=1',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      List<Location> locations = [];

      if (data is List) {
        for (var place in data) {
          final location = Location(
            latitude: double.tryParse(place['lat'].toString()) ?? 0.0,
            longitude: double.tryParse(place['lon'].toString()) ?? 0.0,
            name: place['display_name'] ?? 'Unknown Location',
          );
          locations.add(location);
        }
      } else {
        print('Unexpected response format');
      }

      return locations;
    } else {
      print('Failed to fetch locations from Nominatim: ${response.statusCode}');
      throw Exception('Failed to fetch locations from Nominatim');
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
