/// Data model untuk titik waypoint 3D di depan kendaraan (format ego vehicle).
/// Mendukung kompatibilitas dengan format CSV rosbag `waypoints_ego` [x, y] / [x, y, z].
class Waypoint3D {
  final double x; // meter (lateral, - kiri, + kanan)
  final double y; // meter (elevasi, 0 = jalan)
  final double z; // meter (longitudinal, jarak ke depan)
  final double speedLimit;
  final bool isPassed;

  const Waypoint3D({
    required this.x,
    this.y = 0.05,
    required this.z,
    this.speedLimit = 20.0,
    this.isPassed = false,
  });

  /// Factory untuk membuat Waypoint3D dari array [x, z] atau [x, y, z]
  factory Waypoint3D.fromList(List<dynamic> coords) {
    if (coords.length >= 3) {
      return Waypoint3D(
        x: (coords[0] as num).toDouble(),
        y: (coords[1] as num).toDouble(),
        z: (coords[2] as num).toDouble(),
      );
    } else if (coords.length >= 2) {
      return Waypoint3D(
        x: (coords[0] as num).toDouble(),
        z: (coords[1] as num).toDouble(),
      );
    }
    return const Waypoint3D(x: 0.0, z: 0.0);
  }
}
