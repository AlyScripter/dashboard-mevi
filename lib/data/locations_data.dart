import 'dart:math' as math;
import '../model/location.dart';
import '../data/waypoints.dart';

class TripData {
  final String name;
  final String description;
  final Location destination;
  final List<Location> waypoints;
  final double estimatedDuration;

  TripData({
    required this.name,
    required this.description,
    required this.destination,
    required this.waypoints,
    double? estimatedDuration,
  }) : estimatedDuration = estimatedDuration ??
            _calculateDurationMinutes(waypoints, destination);

  /// Kecepatan acuan kendaraan autonomous: 20 km/jam
  static const double speedKmh = 20.0;
  static const double speedMps = (speedKmh * 1000.0) / 3600.0; // ~5.556 m/s

  /// Total jarak rute dalam meter (Haversine akumulatif titik waypoint + destinasi)
  double get totalDistanceMeters =>
      _calculateTotalDistanceMeters(waypoints, destination);

  /// Total jarak rute dalam kilometer
  double get totalDistanceKm => totalDistanceMeters / 1000.0;

  /// Estimasi waktu tempuh dalam detik pada kecepatan 20 km/jam
  double get estimatedDurationSeconds => estimatedDuration * 60.0;

  /// Format ringkas untuk list & badge: '20 dtk', '35 dtk', '1 mnt'
  String get formattedDuration {
    final sec = (estimatedDuration * 60.0).round();
    if (sec < 55) {
      final s = sec < 5 ? 5 : sec;
      return '$s dtk';
    } else {
      final mins = (sec / 60.0).round();
      return '$mins mnt';
    }
  }

  /// Format lengkap untuk detail info chip: '20 detik', '35 detik', '1 menit'
  String get formattedDurationLong {
    final sec = (estimatedDuration * 60.0).round();
    if (sec < 55) {
      final s = sec < 5 ? 5 : sec;
      return '$s detik';
    } else {
      final mins = (sec / 60.0).round();
      return '$mins menit';
    }
  }

  static double _calculateDurationMinutes(
    List<Location> wps,
    Location dest,
  ) {
    final meters = _calculateTotalDistanceMeters(wps, dest);
    if (meters <= 0) return 0.0;
    final seconds = meters / speedMps;
    return seconds / 60.0;
  }

  static double _calculateTotalDistanceMeters(
    List<Location> wps,
    Location dest,
  ) {
    if (wps.isEmpty) return 0.0;
    double total = 0.0;
    for (int i = 0; i < wps.length - 1; i++) {
      total += _haversineMeters(wps[i], wps[i + 1]);
    }
    final lastPoint = wps.last;
    final distToDest = _haversineMeters(lastPoint, dest);
    if (distToDest > 3.0) {
      total += distToDest;
    }
    return total;
  }

  static double _haversineMeters(Location a, Location b) {
    const earthRadius = 6371000.0; // meters
    final dLat = (b.latitude - a.latitude) * (math.pi / 180.0);
    final dLon = (b.longitude - a.longitude) * (math.pi / 180.0);
    final lat1 = a.latitude * (math.pi / 180.0);
    final lat2 = b.latitude * (math.pi / 180.0);

    final sinDLat = math.sin(dLat / 2.0);
    final sinDLon = math.sin(dLon / 2.0);
    final h = sinDLat * sinDLat +
        math.cos(lat1) * math.cos(lat2) * sinDLon * sinDLon;
    final c = 2.0 * math.atan2(math.sqrt(h), math.sqrt(1.0 - h));
    return earthRadius * c;
  }
}

class LocationsData {
  static final List<TripData> predefinedTrips = [
    TripData(
      name: "Keliling Area BRIN (CBF Route)",
      description:
          "Tour lengkap area BRIN menggunakan jalur CBF Navigation yang sudah teruji (33 waypoints)",
      destination: Waypoints.posSatpam,
      waypoints: Waypoints.allWaypoints,
    ),
    TripData(
      name: "Gedung 10 BRIN",
      description: "Menuju Gedung 10 area BRIN via jalur CBF (13 waypoints)",
      destination: Waypoints.gedung10,
      waypoints: Waypoints.toGedung10,
    ),
    TripData(
      name: "Lab Autonomous BRIN",
      description: "Menuju Lab Autonomous area BRIN via jalur CBF (22 waypoints)",
      destination: Waypoints.labAutonomous,
      waypoints: Waypoints.toLabAutonomous,
    ),
    TripData(
      name: "Gedung 80 BRIN",
      description: "Menuju Gedung 80 area BRIN via jalur CBF (4 waypoints)",
      destination: Waypoints.gedung80,
      waypoints: Waypoints.toGedung80,
    ),
    TripData(
      name: "Taman BRIN",
      description: "Menuju Taman area BRIN via jalur CBF (24 waypoints)",
      destination: Waypoints.tamanBRIN,
      waypoints: Waypoints.toTamanBRIN,
    ),
    TripData(
      name: "Pos Satpam BRIN",
      description:
          "Menuju Pos Satpam (Gerbang Keluar) via jalur CBF lengkap (33 waypoints)",
      destination: Waypoints.posSatpam,
      waypoints: Waypoints.toPosSatpam,
    ),
  ];

  // Destinations hanya dari trip yang punya waypoints
  static List<Location> get destinations =>
      predefinedTrips.map((t) => t.destination).toList();

  // Filter by category — tetap merujuk ke trip destinations saja
  static List<Location> getLocationsByCategory(String category) {
    final src = destinations;
    switch (category.toLowerCase()) {
      case 'brin':
        return src
            .where(
              (loc) =>
                  loc.name.contains('BRIN') ||
                  loc.name.contains('Gedung') ||
                  loc.name.contains('Lab') ||
                  loc.name.contains('Taman BRIN') ||
                  loc.name.contains('Pos Satpam'),
            )
            .toList();
      default:
        return src;
    }
  }

  // Search — hanya pada destinations (yang pasti punya rute/waypoints)
  static List<Location> searchLocations(String query) {
    if (query.isEmpty) return [];
    final q = query.toLowerCase();
    return destinations.where((l) => l.name.toLowerCase().contains(q)).toList();
  }

  // Only BRIN locations from destinations
  static List<Location> getBRINLocations() {
    return destinations
        .where(
          (loc) =>
              loc.name.contains('BRIN') ||
              loc.name.contains('Gedung') ||
              loc.name.contains('Lab') ||
              loc.name.contains('Taman BRIN') ||
              loc.name.contains('Pos Satpam') ||
              loc.name.contains('KST'),
        )
        .toList();
  }

  static List<Location> searchBRINLocations(String query) {
    if (query.isEmpty) return getBRINLocations();
    final q = query.toLowerCase();
    return getBRINLocations()
        .where((l) => l.name.toLowerCase().contains(q))
        .toList();
  }

  static TripData? findTripByDestination(String destinationName) {
    try {
      return predefinedTrips.firstWhere(
        (trip) => trip.name.toLowerCase() == destinationName.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  static List<String> getAvailableTripNames() {
    return predefinedTrips.map((t) => t.name).toList();
  }

  static List<Location> getWaypointsForTrip(String tripName) {
    final trip = findTripByDestination(tripName);
    return trip?.waypoints ?? [];
  }

  static Map<String, dynamic> getTripAsJson(String tripName) {
    final trip = findTripByDestination(tripName);
    if (trip == null) return {};
    return {
      "mission_name": trip.name,
      "description": trip.description,
      "location": "BRIN, Bandung, Indonesia",
      "created_date": DateTime.now().toIso8601String().split('T')[0],
      "total_waypoints": trip.waypoints.length,
      "estimated_duration_minutes": trip.estimatedDuration,
      "coordinate_system": "WGS84",
      "source": "CBF_Enhanced",
      "waypoints": trip.waypoints
          .map(
            (wp) => {
              "name": wp.name,
              "latitude": wp.latitude,
              "longitude": wp.longitude,
              "altitude": 10.0,
              "heading": 0.0,
              "type": "path",
            },
          )
          .toList(),
    };
  }

  static List<TripData> getKMLTrips() {
    return predefinedTrips
        .where(
          (trip) =>
              trip.name.contains('KML') || trip.name.contains('Taman BRIN'),
        )
        .toList();
  }

  static Map<String, Location> getBRINPOIFromKML() {
    return {
      'gedung_10': Location(
        name: "Gedung 10 (KML)",
        latitude: -6.881784050362436,
        longitude: 107.6111333063233,
      ),
      'lab_autonomous': Location(
        name: "Lab Autonomous (KML)",
        latitude: -6.881283780406986,
        longitude: 107.6114400048955,
      ),
      'gedung_80': Location(
        name: "Gedung 80 (KML)",
        latitude: -6.882398919774277,
        longitude: 107.610898305495,
      ),
      'pos_satpam': Location(
        name: "Pos Satpam (KML)",
        latitude: -6.88274531661621,
        longitude: 107.611279323457,
      ),
      'taman_brin': Location(
        name: "Taman BRIN (KML)",
        latitude: -6.882229538516845,
        longitude: 107.6116054510044,
      ),
    };
  }
}
