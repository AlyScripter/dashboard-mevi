  // Add new model class for route data
  class RouteResponse {
    final List<List<double>> coordinates;
    final String distance;
    final String duration;

    RouteResponse({
      required this.coordinates,
      required this.distance,
      required this.duration,
    });
  }