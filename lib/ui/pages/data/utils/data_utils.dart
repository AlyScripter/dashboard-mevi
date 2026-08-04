class DataUtils {
  /// Convert full lidar range data to 8 representative points
  static List<double> convertLidarTo8Points(List<double> fullRanges) {
    if (fullRanges.isEmpty) return List.filled(8, 10.0);

    List<double> eightPoints = [];
    int step = fullRanges.length ~/ 8;

    for (int i = 0; i < 8; i++) {
      int index = i * step;
      if (index < fullRanges.length) {
        double sum = 0;
        int count = 0;

        // Average surrounding points for smoother data
        for (int j = -2; j <= 2; j++) {
          int checkIndex = index + j;
          if (checkIndex >= 0 && checkIndex < fullRanges.length) {
            sum += fullRanges[checkIndex];
            count++;
          }
        }
        eightPoints.add(sum / count);
      } else {
        eightPoints.add(10.0);
      }
    }
    return eightPoints;
  }

  /// Calculate front distance from ultrasonic or lidar data
  static double? calculateFrontDistance(
    List<dynamic>? ultrasonicHistory,
    List<double>? lidarAngles,
  ) {
    // Try ultrasonic first
    if (ultrasonicHistory != null && ultrasonicHistory.isNotEmpty) {
      final lastPoint = ultrasonicHistory.last;
      if (lastPoint.value != null) {
        return lastPoint.value.toDouble();
      }
    }

    // Fallback to lidar front sector
    if (lidarAngles != null && lidarAngles.isNotEmpty) {
      return lidarAngles[0]; // Assume first angle represents forward sector
    }

    return null;
  }

  /// Find nearest obstacle from lidar data
  static double? findNearestObstacle(List<double>? lidarAngles) {
    if (lidarAngles == null || lidarAngles.isEmpty) return null;
    return lidarAngles.reduce((a, b) => a < b ? a : b);
  }
}
