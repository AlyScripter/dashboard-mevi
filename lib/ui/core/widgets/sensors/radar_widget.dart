import 'package:flutter/material.dart';
import 'package:dashboardmevi/services/ros_service.dart';
import 'radar_painter.dart';

class LidarRadarScreen extends StatefulWidget {
  const LidarRadarScreen({super.key});
  @override
  State<LidarRadarScreen> createState() => _LidarRadarScreenState();
}

class _LidarRadarScreenState extends State<LidarRadarScreen> {
  final RosService rosService = RosService();

  // Cache untuk mengurangi rebuild dan flickering
  List<double>? _cachedData;
  double? _cachedRangeMax;
  DateTime _lastDataUpdate = DateTime.now();
  static const Duration _updateThrottle = Duration(
    milliseconds: 200,
  ); // Throttle 5 FPS

  @override
  void dispose() {
    super.dispose();
  }

  bool _shouldUpdateVisual(List<double> newData, double newRangeMax) {
    final now = DateTime.now();

    // Throttle update rate - maksimal 5 FPS untuk visual yang smooth
    if (now.difference(_lastDataUpdate) < _updateThrottle) {
      return false;
    }

    // Update jika data berubah signifikan atau cache kosong
    if (_cachedData == null || _cachedRangeMax == null) {
      return true;
    }

    // Update jika range berubah
    if ((_cachedRangeMax! - newRangeMax).abs() > 0.1) {
      return true;
    }

    // Update jika ada perubahan signifikan dalam data (> 10cm untuk mengurangi noise)
    if (_cachedData!.length != newData.length) {
      return true;
    }

    for (int i = 0; i < newData.length; i++) {
      if ((_cachedData![i] - newData[i]).abs() > 0.1) {
        return true;
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: StreamBuilder<List<double>>(
          stream: rosService.lidarStream,
          builder: (context, scanSnap) {
            return StreamBuilder<Map<String, dynamic>>(
              stream: rosService.lidarSummaryStream,
              builder: (context, sumSnap) {
                if (scanSnap.connectionState == ConnectionState.waiting) {
                  return const Text('Waiting for LIDAR data...');
                }
                if (scanSnap.hasError) {
                  return Text('Error: ${scanSnap.error}');
                }
                final data = scanSnap.data;
                if (data == null || data.isEmpty) {
                  return const Text('No LIDAR data available.');
                }

                final summary = sumSnap.data ?? {};
                final rangeMax = (summary['range_max'] as double?) ?? 10.0;

                // Throttle visual updates untuk mengurangi flickering
                if (_shouldUpdateVisual(data, rangeMax)) {
                  _lastDataUpdate = DateTime.now();
                  _cachedData = List.from(data);
                  _cachedRangeMax = rangeMax;
                }

                // Gunakan cached data untuk rendering
                final displayData = _cachedData ?? data;
                final displayRangeMax = _cachedRangeMax ?? rangeMax;

                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: RadarWidget(
                      lidarDataMeters: displayData,
                      rangeMaxMeters: displayRangeMax,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
