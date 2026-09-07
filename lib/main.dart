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
import 'core/theme/theme_controller.dart';

Future<void> main() async {
  // Initialize Flutter bindings
  WidgetsFlutterBinding.ensureInitialized();

  // Register fvp for video_player on Linux/Windows desktop
  fvp.registerWith();

  // Start logging
  LoggingService.logStartup();

  try {
    // Load environment variables
    LoggingService.info('Loading environment variables', component: 'Main');
    await dotenv.load(fileName: ".env");

    // Get ROS WebSocket URL from environment or use default
    final rosWebSocketUrl =
        dotenv.env['ROS_WEBSOCKET_URL'] ?? 'ws://localhost:9090';
    LoggingService.info('ROS Bridge URL: $rosWebSocketUrl', component: 'Main');

    // Initialize ROS service with configurable ROS bridge URL
    LoggingService.info('Initializing ROS service', component: 'Main');
    final rosService = RosService();
    await rosService.initialize(
      rosBridgeUrl: rosWebSocketUrl,
      enableImuOnlyMode: true,
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
      LoggingService.info(
        'App lifecycle: $state - cleaning up rosbag',
        component: 'Main',
      );
      _rosbagService.cleanup();
    }
  }

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder merespons perubahan appThemeMode secara
    // reaktif — saat tombol di nav rail diketuk, ThemeMode berubah dan
    // MaterialApp di-rebuild otomatis dengan tema yang baru.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'MEVI Dashboard',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          scaffoldMessengerKey: NotificationService.scaffoldKey,
          home: const HomePage(title: 'MEVI'),
        );
      },
    );
  }
}
