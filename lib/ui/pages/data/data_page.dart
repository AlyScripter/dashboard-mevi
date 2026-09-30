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

  // Animation controllers
  late AnimationController _dotAnimationController;
  late Animation<double> _dotAnimation;

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
    _initializeAnimations();
    _initializeROS();
  }

  void _initializeAnimations() {
    _dotAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _dotAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _dotAnimationController, curve: Curves.easeInOut),
    );
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
    _dotAnimationController.forward().then((_) {
      _dotAnimationController.reverse();
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_totalPages, (index) {
          return AnimatedBuilder(
            animation: _dotAnimation,
            builder: (context, child) {
              final isActive = _currentPageIndex == index;
              final animationValue = isActive ? _dotAnimation.value : 0.0;

              // REVISI: light → dot aktif biru nav, inaktif abu tua; dark → neon
              final activeDotColor = isLight
                  ? const Color(0xFF1565C0)
                  : AppColors.glassBlueBorder;
              final inactiveDotColor = isLight
                  ? Colors.black38
                  : Colors.white.withValues(alpha: 0.25);
              final glowColor = isLight
                  ? const Color(0xFF1565C0).withValues(alpha: 0.50)
                  : AppColors.glassBlueGlow.withValues(alpha: 0.7);

              return GestureDetector(
                onTap: () {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background dot — blue-black glass theme: active
                      // dot glows neon blue instead of solid black.
                      Container(
                        width: isActive ? 10 : 10,
                        height: isActive ? 10 : 10,
                        decoration: BoxDecoration(
                          color: isActive ? activeDotColor : inactiveDotColor,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: glowColor,
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      if (isActive)
                        Transform.scale(
                          scale: 1.0 + (animationValue * 0.3),
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: activeDotColor.withValues(
                                  alpha: 0.3 + (animationValue * 0.4),
                                ),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
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
        final isMobile = constraints.maxWidth < 600;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
          child: isMobile
              ? Column(
                  children: [
                    // Steering Angle Chart
                    Expanded(
                      flex: 1,
                      child: ChartContainer(
                        icon: LucideIcons.rotate3d,
                        title: 'Steering Angle',
                        child: const SteeringAngleChart(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // CTE Chart
                    Expanded(
                      flex: 1,
                      child: ChartContainer(
                        icon: LucideIcons.navigation,
                        title: 'Cross Track Error',
                        child: const CteChart(),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    // Steering Angle Chart
                    Expanded(
                      flex: 1,
                      child: ChartContainer(
                        icon: LucideIcons.rotate3d,
                        title: 'Steering Angle Analysis',
                        child: const SteeringAngleChart(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // CTE Chart
                    Expanded(
                      flex: 1,
                      child: ChartContainer(
                        icon: LucideIcons.navigation,
                        title: 'Cross Track Error Analysis',
                        child: const CteChart(),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildTrajectoryPlanningPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: const ROSTrajectoryWidget(),
        );
      },
    );
  }

  Widget _buildControlSystemPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
          child: Row(
            children: [
              const Expanded(child: SpeedChart()),
              const SizedBox(width: 8),
              const Expanded(child: ImuChart()),
            ],
          ),
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
            color: isLight ? Colors.white : null,
          ),
          padding: const EdgeInsets.only(left: 8, right: 8, top: 10, bottom: 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DataPageHeader(isConnected: true),
              const SizedBox(height: 6),
              SensorStatusRow(
                currentSpeed: currentSpeed,
                frontDistance: frontDistance,
                nearestObstacle: nearestValue,
                imuYaw: imuYaw,
                batterySoc: batterySoc,
              ),
              const SizedBox(height: 4),
              // REVISI: judul slide & dot indicator digabung dalam 1 Row
              // agar sejajar — judul di kiri, dot di tengah, counter di kanan.
              // Font judul diperbesar dari 12 → 14.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _getPageTitle(_currentPageIndex),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isLight
                          ? Colors.black87
                          : AppColors.glassTextPrimary,
                    ),
                  ),
                  _buildDotIndicator(isLight),
                  Text(
                    '${_currentPageIndex + 1} / $_totalPages',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isLight
                          ? Colors.black54
                          : AppColors.glassTextSecondary,
                    ),
                  ),
                ],
              ),

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
    _dotAnimationController.dispose();
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
