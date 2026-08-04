/// Waypoint model class for trajectory navigation
class Waypoint {
  final String name;
  final String? displayName;
  final double longitude;
  final double latitude;
  final double altitude;
  final double heading;
  final WaypointType type;

  const Waypoint({
    required this.name,
    this.displayName,
    required this.longitude,
    required this.latitude,
    required this.altitude,
    required this.heading,
    required this.type,
  });

  factory Waypoint.fromJson(Map<String, dynamic> json) {
    return Waypoint(
      name: json['name'] as String,
      displayName: json['display_name'] as String?,
      longitude: (json['longitude'] as num).toDouble(),
      latitude: (json['latitude'] as num).toDouble(),
      altitude: (json['altitude'] as num).toDouble(),
      heading: (json['heading'] as num).toDouble(),
      type: WaypointType.fromString(json['type'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (displayName != null) 'display_name': displayName,
      'longitude': longitude,
      'latitude': latitude,
      'altitude': altitude,
      'heading': heading,
      'type': type.toString(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Waypoint &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => name.hashCode ^ latitude.hashCode ^ longitude.hashCode;

  @override
  String toString() => 'Waypoint($name: $latitude, $longitude)';
}

/// CBF Boundary Point for Control Barrier Functions
class BoundaryPoint {
  final double longitude;
  final double latitude;

  const BoundaryPoint({required this.longitude, required this.latitude});

  factory BoundaryPoint.fromCoordinates(double longitude, double latitude) {
    return BoundaryPoint(longitude: longitude, latitude: latitude);
  }

  Map<String, dynamic> toJson() {
    return {'longitude': longitude, 'latitude': latitude};
  }

  @override
  String toString() => 'BoundaryPoint($longitude, $latitude)';
}

/// CBF Boundary Data for safe navigation corridors
class CBFBoundary {
  final List<BoundaryPoint> leftBoundary;
  final List<BoundaryPoint> rightBoundary;

  const CBFBoundary({required this.leftBoundary, required this.rightBoundary});

  /// Create CBF boundary from Python navigation data
  static CBFBoundary fromNavigationData() {
    // Left boundary (jalur 2) from cbf_navigation4.py
    final leftBoundaryData = [
      (107.61071296, -6.88258165),
      (107.61072043, -6.88251255),
      (107.61072314, -6.88243996),
      (107.61073997, -6.88239234),
      (107.61077757, -6.88236514),
      (107.61085058, -6.88236838),
      (107.61092396, -6.88238032),
      (107.61101653, -6.8823911),
      (107.61105083, -6.88236961),
      (107.61106845, -6.88232873),
      (107.61108063, -6.88221245),
      (107.61109631, -6.88207706),
      (107.61111475, -6.88191515),
      (107.61113161, -6.88177073),
      (107.61114481, -6.88165422),
      (107.61115521, -6.88154295),
      (107.61117374, -6.88142771),
      (107.61118462, -6.88129436),
      (107.61121047, -6.88124746),
      (107.61126551, -6.88123233),
      (107.61137929, -6.88124323),
      (107.61148211, -6.88125398),
      (107.61157, -6.88125),
      (107.61158, -6.88121),
      (107.61172, -6.88121),
      (107.6117266, -6.88127863),
      (107.61176777, -6.88130704),
      (107.61177805, -6.88134254),
      (107.61176713, -6.88144478),
      (107.61175577, -6.88157622),
      (107.6117381, -6.88172771),
      (107.61172282, -6.88190378),
      (107.61170182, -6.88208124),
      (107.61168182, -6.88227563),
      (107.61165793, -6.88246976),
      (107.61163532, -6.88265899),
      (107.61160617, -6.88271588),
      (107.61155707, -6.88275134),
      (107.61139959, -6.88274666),
      (107.61123941, -6.88273477),
    ];

    final rightBoundaryData = [
      (107.61076882, -6.88258783),
      (107.61077529, -6.88251809),
      (107.61078127, -6.88245697),
      (107.6107872, -6.88243139),
      (107.61080828, -6.88241799),
      (107.6108496, -6.88241985),
      (107.61092674, -6.88242838),
      (107.61103402, -6.88243424),
      (107.61108275, -6.88241149),
      (107.6111093, -6.88236431),
      (107.61112807, -6.88221864),
      (107.61114511, -6.88207896),
      (107.61116039, -6.88192282),
      (107.61117819, -6.88177558),
      (107.61119045, -6.88166362),
      (107.61120228, -6.88154797),
      (107.61121192, -6.88143095),
      (107.61122501, -6.88131391),
      (107.61123747, -6.88128863),
      (107.61126591, -6.88128367),
      (107.61135899, -6.88128888),
      (107.61146531, -6.88129668),
      (107.6116175, -6.88131091),
      (107.61170624, -6.88132114),
      (107.61172368, -6.88133594),
      (107.61172977, -6.88136093),
      (107.61171758, -6.88146002),
      (107.61170647, -6.88157048),
      (107.61169024, -6.88173349),
      (107.61167304, -6.88190028),
      (107.61165523, -6.88208204),
      (107.61163243, -6.88227031),
      (107.61160849, -6.88246167),
      (107.6115887, -6.8826214),
      (107.61156176, -6.88267328),
      (107.61151666, -6.88270045),
      (107.61137818, -6.88269121),
      (107.61124317, -6.88267871),
    ];

    return CBFBoundary(
      leftBoundary: leftBoundaryData
          .map((coord) => BoundaryPoint.fromCoordinates(coord.$1, coord.$2))
          .toList(),
      rightBoundary: rightBoundaryData
          .map((coord) => BoundaryPoint.fromCoordinates(coord.$1, coord.$2))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'left_boundary': leftBoundary.map((point) => point.toJson()).toList(),
      'right_boundary': rightBoundary.map((point) => point.toJson()).toList(),
    };
  }
}

/// Waypoint type enumeration
enum WaypointType {
  path,
  poi; // Point of Interest

  static WaypointType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'path':
        return WaypointType.path;
      case 'poi':
        return WaypointType.poi;
      default:
        return WaypointType.path;
    }
  }

  @override
  String toString() {
    switch (this) {
      case WaypointType.path:
        return 'path';
      case WaypointType.poi:
        return 'poi';
    }
  }
}

/// Waypoint mission data model
class WaypointMission {
  final String missionName;
  final String description;
  final String location;
  final String createdDate;
  final int totalWaypoints;
  final int pathWaypoints;
  final int poiWaypoints;
  final double defaultAltitude;
  final double poiAltitude;
  final String coordinateSystem;
  final List<Waypoint> waypoints;
  final CBFBoundary? cbfBoundary;

  const WaypointMission({
    required this.missionName,
    required this.description,
    required this.location,
    required this.createdDate,
    required this.totalWaypoints,
    required this.pathWaypoints,
    required this.poiWaypoints,
    required this.defaultAltitude,
    required this.poiAltitude,
    required this.coordinateSystem,
    required this.waypoints,
    this.cbfBoundary,
  });

  factory WaypointMission.fromJson(Map<String, dynamic> json) {
    return WaypointMission(
      missionName: json['mission_name'] as String,
      description: json['description'] as String,
      location: json['location'] as String,
      createdDate: json['created_date'] as String,
      totalWaypoints: json['total_waypoints'] as int,
      pathWaypoints: json['path_waypoints'] as int,
      poiWaypoints: json['poi_waypoints'] as int,
      defaultAltitude: (json['default_altitude'] as num).toDouble(),
      poiAltitude: (json['poi_altitude'] as num).toDouble(),
      coordinateSystem: json['coordinate_system'] as String,
      waypoints: (json['waypoints'] as List)
          .map((w) => Waypoint.fromJson(w as Map<String, dynamic>))
          .toList(),
      cbfBoundary:
          CBFBoundary.fromNavigationData(), // Always include CBF boundary
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mission_name': missionName,
      'description': description,
      'location': location,
      'created_date': createdDate,
      'total_waypoints': totalWaypoints,
      'path_waypoints': pathWaypoints,
      'poi_waypoints': poiWaypoints,
      'default_altitude': defaultAltitude,
      'poi_altitude': poiAltitude,
      'coordinate_system': coordinateSystem,
      'waypoints': waypoints.map((w) => w.toJson()).toList(),
      if (cbfBoundary != null) 'cbf_boundary': cbfBoundary!.toJson(),
    };
  }

  /// Get only path waypoints
  List<Waypoint> get pathWaypointsOnly =>
      waypoints.where((w) => w.type == WaypointType.path).toList();

  /// Get only POI waypoints
  List<Waypoint> get poiWaypointsOnly =>
      waypoints.where((w) => w.type == WaypointType.poi).toList();
}
