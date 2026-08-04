class Location {
  final double latitude;
  final double longitude;
  final String name;

  const Location({
    required this.latitude,
    required this.longitude,
    required this.name,
  });

  @override
  String toString() {
    return 'Location: $name, Latitude: $latitude, Longitude: $longitude';
  }

  factory Location.fromJson(Map<String, dynamic> json) {
    final coordinates = json['geometry']['coordinates'];
    final placeName = json['place_name'] ?? 'Unknown Location';

    return Location(
      latitude: coordinates[1],
      longitude: coordinates[0],
      name: placeName,
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'latitude': latitude, 'longitude': longitude};
  }

  Location copyWith({String? name, double? latitude, double? longitude}) {
    return Location(
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
