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
  StreamSubscription? _lidarSubscription;
  StreamSubscription? _obstacleSubscription;
  StreamSubscription? _imuSubscription;

  // Animation controllers
  late AnimationController _dotAnimationController;
  late Animation<double> _dotAnimation;

  // Slider state
  int _currentPageIndex = 0;
  final int _totalPages = 4; // LiDAR, Trajectory, Steering+CTE, Control System

  // Sensor data
  List<double> lidarRanges = [];
  List<double> lidarIntensities = [];
  double lidarAngleMin = -math.pi;
  double lidarAngleMax = math.pi;
  double lidarAngleIncrement = 0.01745329; // ~1 degree
  double lidarRangeMax = 30.0;
  double batterySoc = 85.0;
  double currentSpeed = 0.0;
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
      setState(() {
        currentSpeed = speed;
      });
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
      case 0:
        return 'LiDAR Visualization';
      case 1:
        return 'Trajectory Planning';
      case 2:
        return 'Steering & CTE Analysis';
      case 3:
        return 'Control System Status';
      default:
        return 'Data Visualization';
    }
  }

  Widget _buildDotIndicator() {
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
                      // Background dot
                      Container(
                        width: isActive ? 10 : 10,
                        height: isActive ? 10 : 10,
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.black.withValues(alpha: 0.8)
                              : Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      // Animated overlay for active dot
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
                                color: Colors.black.withValues(
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
        final frontDistance =
            DataUtils.calculateFrontDistance([], lidarRanges) ?? 0.0;

        final nearestObstacle =
            DataUtils.findNearestObstacle(lidarRanges) ?? 0.0;

        return Container(
          color: const Color(0xFFF2F2F2),
          padding: const EdgeInsets.only(left: 8, right: 8, top: 10, bottom: 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DataPageHeader(isConnected: true),
              const SizedBox(height: 6),
              SensorStatusRow(
                currentSpeed: currentSpeed,
                frontDistance: frontDistance,
                nearestObstacle: nearestObstacle,
                imuYaw: imuYaw,
                batterySoc: batterySoc,
              ),
              const SizedBox(height: 2),
              // Page indicator with slide titles
              Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _getPageTitle(_currentPageIndex),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${_currentPageIndex + 1} / $_totalPages',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.black.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Dot indicator
              _buildDotIndicator(),

              // PageView with visualizations
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  children: [
                    _buildLidarVisualizationPage(), // LiDAR Only
                    _buildTrajectoryPlanningPage(), // Trajectory Planning
                    _buildSteeringCteAnalysisPage(), // Steering + CTE Analysis
                    _buildControlSystemPage(), // Control System Status
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
    _lidarSubscription?.cancel();
    _obstacleSubscription?.cancel();
    _imuSubscription?.cancel();
    super.dispose();
  }
}
