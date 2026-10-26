import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:math' as math;
import 'dart:async';
import '../../../services/ros_service.dart';
import '../../../services/notification_service.dart';
import 'widgets/ui/data_page_header.dart';
import 'widgets/sensors/sensor_status_row.dart';
import 'widgets/sensors/enhanced_lidar_visualization.dart';
import 'widgets/charts/chart_container.dart';
import 'widgets/charts/steering_angle_chart.dart';
import 'widgets/charts/cte_chart.dart';
import 'widgets/charts/speed_chart.dart';
import 'widgets/charts/imu_chart.dart';
import 'widgets/navigation/simple_trajectory_widget.dart';
import 'utils/data_utils.dart';
import '../../../core/theme/colors.dart';

class DataPage extends StatefulWidget {
  const DataPage({super.key});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> with TickerProviderStateMixin {
  final RosService rosService = RosService();
  final VehicleNotificationService _vehicleNotificationService =
      VehicleNotificationService();
  final PageController _pageController = PageController();

  // Timers and subscriptions
  Timer? _dataTimer;
  StreamSubscription? _speedSubscription;
  StreamSubscription? _distanceSubscription;
  StreamSubscription? _nearestSubscription;
  StreamSubscription? _lidarSubscription;
  StreamSubscription? _lidar2DSubscription;
  StreamSubscription? _obstacleSubscription;
  StreamSubscription? _imuSubscription;



  // Slider state
  int _currentPageIndex = 0;
  // NOTE: Total 3 slide (Trajectory Planning, Steering+CTE, Control System).
  // Slide 2D LiDAR disimpan/dinonaktifkan sementara dari dashboard.
  final int _totalPages = 3;

  // Sensor data
  List<double> lidarRanges = [];
  List<double> lidarIntensities = [];
  double lidarAngleMin = -math.pi;
  double lidarAngleMax = math.pi;
  double lidarAngleIncrement = 0.01745329; // ~1 degree
  double lidarRangeMax = 30.0;

  // Full-resolution ~270° scan for the "2D LiDAR" view (raw /scan data,
  // straight from the Hokuyo driver via rosbag/rosbridge — kept separate
  // from the downsampled `lidarRanges` above used by the other view modes).
  List<double> lidar2DRanges = [];
  double lidar2DAngleMin = -2.3561944901923448; // -135°
  double lidar2DAngleIncrement = 0.004363323129985824; // 0.25°
  double lidar2DRangeMin = 0.02;
  double lidar2DRangeMax = 30.0;

  double batterySoc = 85.0;
  double currentSpeed = 0.0;
  double distanceTraveled = 0.0;
  double nearestObstacle = 0.0;
  bool _hasReceivedDistance = false;
  bool _hasReceivedNearest = false;
  double imuYaw = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeROS();
  }

  void _initializeROS() {
    rosService.initialize();

    _speedSubscription = rosService.speedometerRosStream.listen((speed) {
      if (mounted) {
        setState(() {
          currentSpeed = speed;
        });
      }
    });

    _distanceSubscription = rosService.vehicleDistanceStream.listen((dist) {
      if (mounted) {
        setState(() {
          distanceTraveled = dist;
          _hasReceivedDistance = true;
        });
      }
    });

    _nearestSubscription = rosService.vehicleNearestStream.listen((nearest) {
      if (mounted) {
        setState(() {
          nearestObstacle = nearest;
          _hasReceivedNearest = true;
        });
      }
    });

    _lidarSubscription = rosService.lidarStream.listen((ranges) {
      setState(() {
        if (ranges.isNotEmpty) {
          lidarRanges = ranges;
          // Generate mock intensities if not available
          lidarIntensities = List.generate(
            ranges.length,
            (index) => math.Random().nextDouble(),
          );
        }
      });
    });

    // Full-resolution ~270° scan, dedicated to the "2D LiDAR" view.
    _lidar2DSubscription = rosService.lidar2DStream.listen((scan) {
      setState(() {
        lidar2DRanges = scan.ranges;
        lidar2DAngleMin = scan.angleMin;
        lidar2DAngleIncrement = scan.angleIncrement;
        lidar2DRangeMin = scan.rangeMin;
        lidar2DRangeMax = scan.rangeMax;
      });
    });

    // Monitor obstacle distance for collision warnings
    _obstacleSubscription = rosService.obstacleDistanceStream.listen((
      distance,
    ) {
      if (distance > 0 && distance < 5.0) {
        _vehicleNotificationService.showObstacleAlert(distance);
      }
    });

    // Subscribe to IMU data for yaw
    _imuSubscription = rosService.imuStream.listen((imuData) {
      setState(() {
        imuYaw = imuData['yaw'] ?? 0.0;
      });
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPageIndex = index;
    });
  }

  String _getPageTitle(int index) {
    switch (index) {
      // NOTE: 2D LiDAR disimpan untuk kebutuhan mendatang (dinonaktifkan dari dashboard).
      // case 0: return 'LiDAR Visualization';
      case 0:
        return 'Trajectory Planning';
      case 1:
        return 'Steering & CTE Analysis';
      case 2:
        return 'Control System Status';
      default:
        return 'Data Visualization';
    }
  }

  Widget _buildDotIndicator(bool isLight) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_totalPages, (index) {
          final isActive = _currentPageIndex == index;
          final activeDotColor = isLight
              ? const Color(0xFF2563EB)
              : const Color(0xFF7DB4FF);
          final inactiveDotColor = isLight
              ? const Color(0xFFCBD5E1)
              : Colors.white.withValues(alpha: 0.25);

          return GestureDetector(
            onTap: () {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: isActive ? activeDotColor : inactiveDotColor,
                borderRadius: BorderRadius.circular(4),
                boxShadow: isActive && !isLight
                    ? [
                        BoxShadow(
                          color: activeDotColor.withValues(alpha: 0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }

  // Widget visualisasi LiDAR 2D disimpan secara utuh (tidak dihapus)
  // agar dapat diaktifkan kembali jika sewaktu-waktu dibutuhkan.
  // ignore: unused_element
  Widget _buildLidarVisualizationPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 0),
          child: ChartContainer(
            icon: LucideIcons.radar,
            title: 'Enhanced LiDAR Visualization',
            child: EnhancedLidarVisualization(
              ranges: lidarRanges,
              intensities: lidarIntensities,
              angleMin: lidarAngleMin,
              angleMax: lidarAngleMax,
              angleIncrement: lidarAngleIncrement,
              rangeMax: lidarRangeMax,
              mode: LidarVisualizationMode.polar,
              lidar2DRanges: lidar2DRanges,
              lidar2DAngleMin: lidar2DAngleMin,
              lidar2DAngleIncrement: lidar2DAngleIncrement,
              lidar2DRangeMin: lidar2DRangeMin,
              lidar2DRangeMax: lidar2DRangeMax,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSteeringCteAnalysisPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;

        return isMobile
            ? Column(
                children: const [
                  Expanded(child: SteeringAngleChart()),
                  SizedBox(height: 10),
                  Expanded(child: CteChart()),
                ],
              )
            : Row(
                children: const [
                  Expanded(child: SteeringAngleChart()),
                  SizedBox(width: 12),
                  Expanded(child: CteChart()),
                ],
              );
      },
    );
  }

  Widget _buildTrajectoryPlanningPage() {
    return const ROSTrajectoryWidget();
  }

  Widget _buildControlSystemPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;

        return isMobile
            ? Column(
                children: const [
                  Expanded(child: SpeedChart()),
                  SizedBox(height: 10),
                  Expanded(child: ImuChart()),
                ],
              )
            : Row(
                children: const [
                  Expanded(child: SpeedChart()),
                  SizedBox(width: 12),
                  Expanded(child: ImuChart()),
                ],
              );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate metrics for sensor status row
        final frontDistance = _hasReceivedDistance
            ? distanceTraveled
            : (DataUtils.calculateFrontDistance([], lidarRanges) ?? 0.0);

        final nearestValue = _hasReceivedNearest
            ? nearestObstacle
            : (DataUtils.findNearestObstacle(lidarRanges) ?? 0.0);

        final isLight = Theme.of(context).brightness == Brightness.light;

        return Container(
          // REVISI: light mode → putih bersih; dark mode → navy gelap seperti semula.
          decoration: BoxDecoration(
            gradient: isLight
                ? null
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF12161F), Color(0xFF0A0D13)],
                  ),
            color: isLight ? const Color(0xFFF8FAFC) : null,
          ),
          padding: const EdgeInsets.only(left: 12, right: 12, top: 10, bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DataPageHeader(isConnected: true),
              const SizedBox(height: 8),
              SensorStatusRow(
                currentSpeed: currentSpeed,
                frontDistance: frontDistance,
                nearestObstacle: nearestValue,
                imuYaw: imuYaw,
                batterySoc: batterySoc,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _getPageTitle(_currentPageIndex),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: isLight
                          ? const Color(0xFF0F172A)
                          : AppColors.glassTextPrimary,
                    ),
                  ),
                  _buildDotIndicator(isLight),
                  Text(
                    '${_currentPageIndex + 1} / $_totalPages',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isLight
                          ? const Color(0xFF64748B)
                          : AppColors.glassTextSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // PageView with visualizations
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  children: [
                    // SIMPAN: Widget visualisasi LiDAR 2D dikomentari agar tidak tampil di dashboard,
                    // namun kodenya tetap utuh agar dapat digunakan kembali jika diperlukan:
                    // _buildLidarVisualizationPage(),

                    _buildTrajectoryPlanningPage(), // Slide 1 (Aktif pertama saat dibuka): Trajectory Planning
                    _buildSteeringCteAnalysisPage(), // Slide 2: Steering + CTE Analysis
                    _buildControlSystemPage(), // Slide 3: Control System Status
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _dataTimer?.cancel();
    _speedSubscription?.cancel();
    _distanceSubscription?.cancel();
    _nearestSubscription?.cancel();
    _lidarSubscription?.cancel();
    _lidar2DSubscription?.cancel();
    _obstacleSubscription?.cancel();
    _imuSubscription?.cancel();
    super.dispose();
  }
}
