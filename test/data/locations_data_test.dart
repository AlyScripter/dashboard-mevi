import 'package:flutter_test/flutter_test.dart';
import 'package:dashboardmevi/data/locations_data.dart';
import 'package:dashboardmevi/data/waypoints.dart';
import 'package:dashboardmevi/model/location.dart';

void main() {
  group('TripData', () {
    test('should create TripData correctly', () {
      final trip = TripData(
        name: 'Test Trip',
        description: 'Test Description',
        destination: Waypoints.wp33,
        waypoints: [
          Waypoints.wp01,
          Waypoints.wp02,
          Waypoints.wp33,
        ],
        estimatedDuration: 10.0,
      );

      expect(trip.name, 'Test Trip');
      expect(trip.description, 'Test Description');
      expect(trip.waypoints.length, 2);
      expect(trip.estimatedDuration, 10.0);
    });
  });

  group('LocationsData', () {
    test('should have predefined trips', () {
      expect(LocationsData.predefinedTrips, isNotEmpty);
    });

    test('should get destinations', () {
      final destinations = LocationsData.destinations;
      expect(destinations, isNotEmpty);
      expect(destinations.first, isA<Location>());
    });

    test('should filter locations by category', () {
      final brinLocations = LocationsData.getLocationsByCategory('brin');
      expect(brinLocations, isNotEmpty);

      final allLocations = LocationsData.getLocationsByCategory('all');
      expect(allLocations, isNotEmpty);
    });

    test('should search locations', () {
      final results = LocationsData.searchLocations('BRIN');
      expect(results, isNotEmpty);

      final emptyResults = LocationsData.searchLocations('');
      expect(emptyResults, isEmpty);
    });

    test('should get BRIN locations', () {
      final brinLocations = LocationsData.getBRINLocations();
      expect(brinLocations, isNotEmpty);
    });

    test('should search BRIN locations', () {
      final results = LocationsData.searchBRINLocations('Gedung');
      expect(results, isA<List<Location>>());

      final allBrin = LocationsData.searchBRINLocations('');
      expect(allBrin, isNotEmpty);
    });

    test('should find trip by destination', () {
      final tripName = LocationsData.predefinedTrips.first.name;
      final trip = LocationsData.findTripByDestination(tripName);
      expect(trip, isNotNull);
      expect(trip?.name, tripName);

      final nullTrip = LocationsData.findTripByDestination('Non-existent');
      expect(nullTrip, isNull);
    });

    test('should get available trip names', () {
      final names = LocationsData.getAvailableTripNames();
      expect(names, isNotEmpty);
      expect(names, isA<List<String>>());
    });

    test('should get waypoints for trip', () {
      final tripName = LocationsData.predefinedTrips.first.name;
      final waypoints = LocationsData.getWaypointsForTrip(tripName);
      expect(waypoints, isNotEmpty);

      final emptyWaypoints = LocationsData.getWaypointsForTrip('Non-existent');
      expect(emptyWaypoints, isEmpty);
    });

    test('should get trip as JSON', () {
      final tripName = LocationsData.predefinedTrips.first.name;
      final json = LocationsData.getTripAsJson(tripName);
      expect(json, isNotEmpty);
      expect(json['mission_name'], tripName);
      expect(json['waypoints'], isA<List>());

      final emptyJson = LocationsData.getTripAsJson('Non-existent');
      expect(emptyJson, isEmpty);
    });

    test('should get KML trips', () {
      final kmlTrips = LocationsData.getKMLTrips();
      expect(kmlTrips, isA<List<TripData>>());
    });

    test('should get BRIN POI from KML', () {
      final poi = LocationsData.getBRINPOIFromKML();
      expect(poi, isNotEmpty);
      expect(poi['gedung_10'], isA<Location>());
      expect(poi['lab_autonomous'], isA<Location>());
    });
  });

  group('Waypoints', () {
    test('should have all waypoints defined', () {
      expect(Waypoints.wp01, isA<Location>());
      expect(Waypoints.wp02, isA<Location>());
      expect(Waypoints.wp33, isA<Location>());
      expect(Waypoints.allWaypoints, isA<List<Location>>());
      expect(Waypoints.allWaypoints.length, 33);
    });

    test('waypoints should have correct properties', () {
      expect(Waypoints.wp01.name, 'WP 01 - Start');
      expect(Waypoints.wp01.latitude, isA<double>());
      expect(Waypoints.wp01.longitude, isA<double>());

      expect(Waypoints.wp33.name, 'WP 33 - Finish');
      expect(Waypoints.wp33.latitude, isA<double>());
      expect(Waypoints.wp33.longitude, isA<double>());
    });
  });
}
