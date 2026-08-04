import 'package:flutter_test/flutter_test.dart';
import 'package:dashboardmevi/data/locations_data.dart';
import 'package:dashboardmevi/model/location.dart';

void main() {
  group('TripData', () {
    test('should create TripData with all fields', () {
      final trip = TripData(
        name: 'Test Trip',
        description: 'Test Description',
        destination: Location(name: 'Dest', latitude: -6.88, longitude: 107.61),
        waypoints: [
          Location(name: 'WP1', latitude: -6.881, longitude: 107.611),
        ],
        estimatedDuration: 10.0,
      );

      expect(trip.name, 'Test Trip');
      expect(trip.description, 'Test Description');
      expect(trip.destination.name, 'Dest');
      expect(trip.waypoints.length, 1);
      expect(trip.estimatedDuration, 10.0);
    });
  });

  group('LocationsData', () {
    test('predefinedTrips is not empty', () {
      expect(LocationsData.predefinedTrips, isNotEmpty);
    });

    test('predefinedTrips contains at least 5 trips', () {
      expect(LocationsData.predefinedTrips.length, greaterThanOrEqualTo(5));
    });

    test('destinations returns list of locations', () {
      final destinations = LocationsData.destinations;
      expect(destinations, isA<List<Location>>());
      expect(destinations, isNotEmpty);
    });

    test('getLocationsByCategory returns BRIN locations', () {
      final brinLocations = LocationsData.getLocationsByCategory('brin');
      expect(brinLocations, isNotEmpty);
    });

    test('getLocationsByCategory returns all for unknown category', () {
      final allLocations = LocationsData.getLocationsByCategory('unknown');
      expect(allLocations, LocationsData.destinations);
    });

    test('searchLocations returns empty for empty query', () {
      final results = LocationsData.searchLocations('');
      expect(results, isEmpty);
    });

    test('searchLocations finds matching locations', () {
      final results = LocationsData.searchLocations('gedung');
      expect(results, isNotEmpty);
      for (final loc in results) {
        expect(loc.name.toLowerCase(), contains('gedung'));
      }
    });

    test('searchLocations is case insensitive', () {
      final results1 = LocationsData.searchLocations('BRIN');
      final results2 = LocationsData.searchLocations('brin');
      expect(results1.length, results2.length);
    });

    test('getBRINLocations returns BRIN-related locations', () {
      final brinLocations = LocationsData.getBRINLocations();
      expect(brinLocations, isNotEmpty);
    });

    test('searchBRINLocations returns all BRIN locations for empty query', () {
      final results = LocationsData.searchBRINLocations('');
      expect(results, LocationsData.getBRINLocations());
    });

    test('searchBRINLocations filters by query', () {
      final results = LocationsData.searchBRINLocations('gedung');
      expect(results, isNotEmpty);
    });

    test('findTripByDestination finds existing trip', () {
      final tripName = LocationsData.predefinedTrips.first.name;
      final trip = LocationsData.findTripByDestination(tripName);
      expect(trip, isNotNull);
      expect(trip!.name, tripName);
    });

    test('findTripByDestination returns null for non-existent trip', () {
      final trip = LocationsData.findTripByDestination('Non Existent Trip');
      expect(trip, isNull);
    });

    test('findTripByDestination is case insensitive', () {
      final tripName = LocationsData.predefinedTrips.first.name;
      final trip = LocationsData.findTripByDestination(tripName.toLowerCase());
      expect(trip, isNotNull);
    });

    test('getAvailableTripNames returns list of trip names', () {
      final names = LocationsData.getAvailableTripNames();
      expect(names, isA<List<String>>());
      expect(names, isNotEmpty);
      expect(names.length, LocationsData.predefinedTrips.length);
    });

    test('getWaypointsForTrip returns waypoints for valid trip', () {
      final tripName = LocationsData.predefinedTrips.first.name;
      final waypoints = LocationsData.getWaypointsForTrip(tripName);
      expect(waypoints, isNotEmpty);
    });

    test('getWaypointsForTrip returns empty list for invalid trip', () {
      final waypoints = LocationsData.getWaypointsForTrip('Invalid Trip');
      expect(waypoints, isEmpty);
    });

    test('getTripAsJson returns valid map for existing trip', () {
      final tripName = LocationsData.predefinedTrips.first.name;
      final json = LocationsData.getTripAsJson(tripName);
      
      expect(json, isNotEmpty);
      expect(json['mission_name'], tripName);
      expect(json['description'], isNotNull);
      expect(json['waypoints'], isA<List>());
    });

    test('getTripAsJson returns empty map for non-existent trip', () {
      final json = LocationsData.getTripAsJson('Non Existent');
      expect(json, isEmpty);
    });

    test('getKMLTrips returns trips with KML or Taman BRIN', () {
      final kmlTrips = LocationsData.getKMLTrips();
      // Might be empty if no KML trips exist
      expect(kmlTrips, isA<List<TripData>>());
    });

    test('getBRINPOIFromKML returns map of POI locations', () {
      final pois = LocationsData.getBRINPOIFromKML();
      
      expect(pois, isA<Map<String, Location>>());
      expect(pois['gedung_10'], isNotNull);
      expect(pois['lab_autonomous'], isNotNull);
      expect(pois['gedung_80'], isNotNull);
      expect(pois['pos_satpam'], isNotNull);
      expect(pois['taman_brin'], isNotNull);
    });

    test('all predefined trips have valid waypoints', () {
      for (final trip in LocationsData.predefinedTrips) {
        expect(trip.waypoints, isNotEmpty);
        expect(trip.destination, isNotNull);
        expect(trip.estimatedDuration, greaterThan(0));
      }
    });
  });
}
