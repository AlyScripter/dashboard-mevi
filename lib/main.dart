import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fvp/fvp.dart' as fvp;
// import 'dart:io';
// import 'package:window_manager/window_manager.dart';
import 'services/ros_service.dart';
import 'services/rosbag_player_service.dart';
import 'services/notification_service.dart';
import 'services/logging_service.dart';
import 'ui/pages/home/home_page.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  // Initialize Flutter bindings
  WidgetsFlutterBinding.ensureInitialized();
  
  // Register fvp for video_player on Linux/Windows desktop
  fvp.registerWith();

  // Start logging
  LoggingService.logStartup();

  try {
    // Load environment variables
    // Load environment variables
    LoggingService.info('Loading environment variables', component: 'Main');
    await dotenv.load(fileName: ".env");

    // Get ROS WebSocket URL from environment or use default
    // For Jetson AGX Xavier connection, set ROS_WEBSOCKET_URL in .env file
    // Example: ROS_WEBSOCKET_URL=ws://192.168.1.100:9090
    final rosWebSocketUrl =
        dotenv.env['ROS_WEBSOCKET_URL'] ?? 'ws://localhost:9090';
    LoggingService.info('ROS Bridge URL: $rosWebSocketUrl', component: 'Main');

    // TODO: Initialize map tile caching later
    // For now using simple NetworkTileProvider to avoid database issues

    // Initialize ROS service with configurable ROS bridge URL
    // Connect to Jetson AGX Xavier via rosbridge_websocket
    LoggingService.info('Initializing ROS service', component: 'Main');
    final rosService = RosService();
    await rosService.initialize(
      rosBridgeUrl: rosWebSocketUrl,
      enableImuOnlyMode: true, // Enable IMU-only mode for testing speedometer
    );

    // Initialize Rosbag Player Service
    LoggingService.info(
      'Initializing Rosbag Player service',
      component: 'Main',
    );
    final rosbagService = RosbagPlayerService();
    await rosbagService.initialize();

    LoggingService.info(
      'Starting MEVI Dashboard application',
      component: 'Main',
    );
    runApp(const MyApp());
  } catch (e, stackTrace) {
    LoggingService.error(
      'Failed to start application',
      component: 'Main',
      error: e,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final RosbagPlayerService _rosbagService = RosbagPlayerService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.paused) {
      // App is closing or going to background - cleanup rosbag
      LoggingService.info(
        'App lifecycle: $state - cleaning up rosbag',
        component: 'Main',
      );
      _rosbagService.cleanup();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MEVI Dashboard',
      // Use light theme only
      theme: AppTheme.lightTheme,
      scaffoldMessengerKey: NotificationService.scaffoldKey,
      home: const HomePage(title: 'MEVI'),
    );
  }
}
