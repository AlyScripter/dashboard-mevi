import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'ros_service.dart';

/// Recording mode for data capture
enum RecordingMode {
  auto, // Record when navigating to goal
  manual, // Start/Stop via button
  continuous, // Record while connected
}

/// Data record model for CSV export
/// Only includes fields that have actual data from ROS topics
class SensorDataRecord {
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double speed;
  final double steeringAngle;
  final double imuYaw;
  final double imuPitch;
  final double imuRoll;
  final double accelerationX;
  final double accelerationY;
  final double accelerationZ;
  final double nearestObstacle;
  final double cte;
  final double headingError;
  // Lidar data
  final List<double> lidarRanges;
  final double lidarMinRange;
  final double lidarMaxRange;
  final int lidarPointCount;
  final String obstaclePosition;

  SensorDataRecord({
    required this.timestamp,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.speed = 0.0,
    this.steeringAngle = 0.0,
    this.imuYaw = 0.0,
    this.imuPitch = 0.0,
    this.imuRoll = 0.0,
    this.accelerationX = 0.0,
    this.accelerationY = 0.0,
    this.accelerationZ = 0.0,
    this.nearestObstacle = 0.0,
    this.cte = 0.0,
    this.headingError = 0.0,
    this.lidarRanges = const [],
    this.lidarMinRange = 0.0,
    this.lidarMaxRange = 0.0,
    this.lidarPointCount = 0,
    this.obstaclePosition = 'none',
  });

  String toCsvRow() {
    final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(timestamp);
    // Convert lidar ranges to semicolon-separated string (to avoid CSV comma conflicts)
    final lidarStr = lidarRanges.isNotEmpty
        ? lidarRanges.map((r) => r.toStringAsFixed(3)).join(';')
        : '';
    return '$timeStr,$latitude,$longitude,$speed,$steeringAngle,'
        '$imuYaw,$imuPitch,$imuRoll,$accelerationX,$accelerationY,$accelerationZ,'
        '$nearestObstacle,$cte,$headingError,'
        '$lidarMinRange,$lidarMaxRange,$lidarPointCount,$obstaclePosition,"$lidarStr"';
  }

  static String csvHeader() {
    return 'timestamp,latitude,longitude,speed_kmh,steering_angle_deg,'
        'imu_yaw_deg,imu_pitch_deg,imu_roll_deg,accel_x,accel_y,accel_z,'
        'nearest_obstacle_m,cte_m,heading_error_deg,'
        'lidar_min_m,lidar_max_m,lidar_point_count,obstacle_position,lidar_ranges';
  }
}

/// Service for recording sensor data to CSV files
class DataRecorderService extends ChangeNotifier {
  static final DataRecorderService _instance = DataRecorderService._internal();
  factory DataRecorderService() => _instance;
  DataRecorderService._internal();

  final RosService _rosService = RosService();

  // Recording state
  bool _isRecording = false;
  RecordingMode _mode = RecordingMode.manual;
  DateTime? _recordingStartTime;
  int _recordCount = 0;
  String? _currentFileName;
  String? _destinationName;

  // Data buffer and file
  final List<SensorDataRecord> _dataBuffer = [];
  File? _currentFile;
  IOSink? _fileSink;
  Timer? _recordingTimer;

  // Subscriptions
  StreamSubscription? _speedSubscription;
  StreamSubscription? _imuSubscription;
  StreamSubscription? _gpsSubscription;
  StreamSubscription? _lidarSubscription;
  StreamSubscription? _steeringSubscription;
  StreamSubscription? _cteSubscription;
  StreamSubscription? _headingErrorSubscription;
  StreamSubscription? _connectionSubscription;

  // Current sensor values (updated via streams)
  double _currentSpeed = 0.0;
  double _currentLatitude = 0.0;
  double _currentLongitude = 0.0;
  double _currentYaw = 0.0;
  double _currentPitch = 0.0;
  double _currentRoll = 0.0;
  double _currentAccelX = 0.0;
  double _currentAccelY = 0.0;
  double _currentAccelZ = 0.0;
  double _currentSteeringAngle = 0.0;
  double _currentCte = 0.0;
  double _currentHeadingError = 0.0;
  double _nearestObstacle = 0.0;
  // Removed unused fields: _frontDistance, _batterySoc (no ROS topic source)

  // Lidar data
  List<double> _currentLidarRanges = [];
  String _obstaclePosition = 'none';

  // Recording settings
  int _recordingIntervalMs = 100; // 10 Hz default

  // Getters
  bool get isRecording => _isRecording;
  RecordingMode get mode => _mode;
  int get recordCount => _recordCount;
  String? get currentFileName => _currentFileName;
  Duration get recordingDuration => _recordingStartTime != null
      ? DateTime.now().difference(_recordingStartTime!)
      : Duration.zero;
  int get recordingIntervalMs => _recordingIntervalMs;

  /// Initialize the service and subscribe to ROS streams
  void initialize() {
    _subscribeToStreams();

    // Auto-start recording in continuous mode when connected
    _connectionSubscription = _rosService.connectionStream.listen((connected) {
      if (_mode == RecordingMode.continuous) {
        if (connected && !_isRecording) {
          startRecording();
        } else if (!connected && _isRecording) {
          stopRecording();
        }
      }
    });

    debugPrint('[DataRecorder] 📊 Data recorder initialized');
  }

  void _subscribeToStreams() {
    _speedSubscription = _rosService.speedometerRosStream.listen((speed) {
      _currentSpeed = speed;
    });

    _imuSubscription = _rosService.imuStream.listen((imuData) {
      _currentYaw = imuData['yaw'] ?? 0.0;
      _currentPitch = imuData['pitch'] ?? 0.0;
      _currentRoll = imuData['roll'] ?? 0.0;
      _currentAccelX = imuData['acceleration_x'] ?? 0.0;
      _currentAccelY = imuData['acceleration_y'] ?? 0.0;
      _currentAccelZ = imuData['acceleration_z'] ?? 0.0;
    });

    _gpsSubscription = _rosService.gpsStream.listen((gpsData) {
      // ROS service uses 'lat' and 'lng' keys
      _currentLatitude = gpsData['lat'] ?? 0.0;
      _currentLongitude = gpsData['lng'] ?? 0.0;
    });

    _steeringSubscription = _rosService.steeringAngleStream.listen((angle) {
      _currentSteeringAngle = angle;
    });

    _cteSubscription = _rosService.crossTrackErrorStream.listen((cte) {
      _currentCte = cte;
    });

    _headingErrorSubscription = _rosService.headingErrorStream.listen((error) {
      _currentHeadingError = error;
    });

    _lidarSubscription = _rosService.obstacleDistanceStream.listen((distance) {
      _nearestObstacle = distance;
    });

    // Subscribe to full lidar ranges
    _rosService.lidarStream.listen((ranges) {
      _currentLidarRanges = ranges;
    });

    // Subscribe to obstacle position
    _rosService.obstaclePositionStream.listen((position) {
      _obstaclePosition = position;
    });
  }

  /// Set recording mode
  void setMode(RecordingMode mode) {
    _mode = mode;
    notifyListeners();
    debugPrint('[DataRecorder] 📊 Recording mode set to: ${mode.name}');
  }

  /// Set recording interval in milliseconds
  void setRecordingInterval(int intervalMs) {
    _recordingIntervalMs = intervalMs.clamp(50, 1000);
    notifyListeners();
  }

  /// Check and request storage permissions based on Android version
  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      debugPrint('[DataRecorder] 📱 Android SDK: $sdkInt');

      if (sdkInt >= 33) {
        // Android 13+ (API 33+): Use app-specific directory, no permission needed
        debugPrint(
          '[DataRecorder] ✅ Android 13+: Using app-specific storage (no permission needed)',
        );
        return true;
      } else if (sdkInt >= 30) {
        // Android 11-12 (API 30-32): Check MANAGE_EXTERNAL_STORAGE or use scoped storage
        final status = await Permission.manageExternalStorage.status;
        if (status.isGranted) {
          debugPrint('[DataRecorder] ✅ MANAGE_EXTERNAL_STORAGE granted');
          return true;
        }

        // Try requesting permission
        final result = await Permission.manageExternalStorage.request();
        if (result.isGranted) {
          debugPrint(
            '[DataRecorder] ✅ MANAGE_EXTERNAL_STORAGE granted after request',
          );
          return true;
        }

        // Fall back to app-specific directory (always allowed)
        debugPrint(
          '[DataRecorder] ⚠️ MANAGE_EXTERNAL_STORAGE denied, using app-specific storage',
        );
        return true;
      } else {
        // Android 10 and below (API <= 29): Use legacy storage permission
        PermissionStatus status = await Permission.storage.status;
        if (!status.isGranted) {
          debugPrint('[DataRecorder] 📋 Requesting storage permission...');
          status = await Permission.storage.request();
          if (!status.isGranted) {
            debugPrint('[DataRecorder] ❌ Storage permission denied');
            return false;
          }
        }
        debugPrint('[DataRecorder] ✅ Storage permission granted');
        return true;
      }
    } catch (e) {
      debugPrint('[DataRecorder] ⚠️ Error checking permissions: $e');
      // Fall back to app-specific directory
      return true;
    }
  }

  /// Start recording with optional destination name
  Future<bool> startRecording({String? destination}) async {
    if (_isRecording) {
      debugPrint('[DataRecorder] ⚠️ Already recording');
      return false;
    }

    try {
      // Check storage permission on Android
      if (Platform.isAndroid) {
        final hasPermission = await _requestStoragePermission();
        if (!hasPermission) {
          debugPrint('[DataRecorder] ❌ Storage permission denied');
          return false;
        }
      }

      _destinationName = destination;
      _recordingStartTime = DateTime.now();
      _recordCount = 0;
      _dataBuffer.clear();

      // Create file
      debugPrint('[DataRecorder] 📂 Getting recording directory...');
      final dir = await _getRecordingDirectory();
      debugPrint('[DataRecorder] 📂 Recording directory: ${dir.path}');

      final timestamp = DateFormat(
        'yyyy-MM-dd_HH-mm-ss',
      ).format(_recordingStartTime!);
      final destSuffix = destination != null
          ? '_${_sanitizeFileName(destination)}'
          : '';
      _currentFileName = 'trip_$timestamp$destSuffix.csv';

      _currentFile = File('${dir.path}/$_currentFileName');
      debugPrint('[DataRecorder] 📝 Creating file: ${_currentFile!.path}');

      _fileSink = _currentFile!.openWrite();

      // Write CSV header
      _fileSink!.writeln(SensorDataRecord.csvHeader());
      await _fileSink!.flush();
      debugPrint('[DataRecorder] ✅ CSV header written');

      // Start periodic recording
      _recordingTimer = Timer.periodic(
        Duration(milliseconds: _recordingIntervalMs),
        (_) => _recordDataPoint(),
      );

      _isRecording = true;
      notifyListeners();

      debugPrint('[DataRecorder] 🔴 Recording started: $_currentFileName');
      debugPrint('[DataRecorder] 💾 Full path: ${_currentFile!.path}');
      return true;
    } catch (e, stackTrace) {
      debugPrint('[DataRecorder] ❌ Failed to start recording: $e');
      debugPrint('[DataRecorder] 📚 Stack trace: $stackTrace');
      return false;
    }
  }

  /// Stop recording and finalize file
  Future<String?> stopRecording() async {
    if (!_isRecording) {
      return null;
    }

    try {
      _recordingTimer?.cancel();
      _recordingTimer = null;

      // Flush remaining buffer
      for (final record in _dataBuffer) {
        _fileSink?.writeln(record.toCsvRow());
      }
      _dataBuffer.clear();

      await _fileSink?.flush();
      await _fileSink?.close();
      _fileSink = null;

      final savedPath = _currentFile?.path;
      _isRecording = false;

      debugPrint(
        '[DataRecorder] ⏹️ Recording stopped: $_recordCount records saved',
      );
      debugPrint('[DataRecorder] 💾 File saved to: $savedPath');

      // Verify file exists
      if (_currentFile != null && await _currentFile!.exists()) {
        final fileSize = await _currentFile!.length();
        debugPrint('[DataRecorder] ✅ File verified: ${fileSize} bytes');
      } else {
        debugPrint('[DataRecorder] ⚠️ Warning: File may not exist after save');
      }

      _currentFileName = null;
      _currentFile = null;
      _recordingStartTime = null;
      _destinationName = null;

      notifyListeners();
      return savedPath;
    } catch (e, stackTrace) {
      debugPrint('[DataRecorder] ❌ Failed to stop recording: $e');
      debugPrint('[DataRecorder] 📚 Stack trace: $stackTrace');
      _isRecording = false;
      notifyListeners();
      return null;
    }
  }

  /// Record a single data point
  void _recordDataPoint() {
    if (!_isRecording) return;

    // Calculate lidar statistics
    final validRanges = _currentLidarRanges
        .where((r) => r > 0.01 && r < 30.0)
        .toList();
    final lidarMin = validRanges.isNotEmpty
        ? validRanges.reduce((a, b) => a < b ? a : b)
        : 0.0;
    final lidarMax = validRanges.isNotEmpty
        ? validRanges.reduce((a, b) => a > b ? a : b)
        : 0.0;

    final record = SensorDataRecord(
      timestamp: DateTime.now(),
      latitude: _currentLatitude,
      longitude: _currentLongitude,
      speed: _currentSpeed,
      steeringAngle: _currentSteeringAngle,
      imuYaw: _currentYaw,
      imuPitch: _currentPitch,
      imuRoll: _currentRoll,
      accelerationX: _currentAccelX,
      accelerationY: _currentAccelY,
      accelerationZ: _currentAccelZ,
      nearestObstacle: _nearestObstacle,
      cte: _currentCte,
      headingError: _currentHeadingError,
      // Lidar data
      lidarRanges: List.from(_currentLidarRanges),
      lidarMinRange: lidarMin,
      lidarMaxRange: lidarMax,
      lidarPointCount: validRanges.length,
      obstaclePosition: _obstaclePosition,
    );

    // Write directly to file for efficiency
    _fileSink?.writeln(record.toCsvRow());
    _recordCount++;

    // Notify every 10 records to reduce UI updates
    if (_recordCount % 10 == 0) {
      notifyListeners();
    }
  }

  /// Called when navigation goal is set (for auto mode)
  void onGoalSet(String destination) {
    if (_mode == RecordingMode.auto && !_isRecording) {
      startRecording(destination: destination);
    }
  }

  /// Called when navigation goal is reached (for auto mode)
  void onGoalReached() {
    if (_mode == RecordingMode.auto && _isRecording) {
      stopRecording();
    }
  }

  /// Get the directory for storing recordings
  Future<Directory> _getRecordingDirectory() async {
    Directory appDir;

    if (Platform.isAndroid) {
      // On Android, use external storage for user-accessible files
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        debugPrint(
          '[DataRecorder] ❌ External storage not available, falling back to app directory',
        );
        appDir = await getApplicationDocumentsDirectory();
      } else {
        // Use /storage/emulated/0/Android/data/com.example.dashboardmevi/files/MEVI_Recordings
        appDir = externalDir;
        debugPrint('[DataRecorder] 📂 Using external storage: ${appDir.path}');
      }
    } else {
      // On iOS/Desktop, use application documents directory
      appDir = await getApplicationDocumentsDirectory();
      debugPrint('[DataRecorder] 📂 Using app documents: ${appDir.path}');
    }

    final recordingsDir = Directory('${appDir.path}/MEVI_Recordings');

    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
      debugPrint(
        '[DataRecorder] 📁 Created recordings directory: ${recordingsDir.path}',
      );
    }

    return recordingsDir;
  }

  /// Sanitize filename by removing special characters
  String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        .replaceAll(' ', '_')
        .toLowerCase()
        .substring(0, name.length.clamp(0, 30));
  }

  /// Get list of recorded files
  Future<List<FileSystemEntity>> getRecordedFiles() async {
    final dir = await _getRecordingDirectory();
    if (!await dir.exists()) return [];

    return dir.listSync().where((f) => f.path.endsWith('.csv')).toList()
      ..sort((a, b) => b.path.compareTo(a.path)); // Newest first
  }

  /// Delete a recording file
  Future<bool> deleteRecording(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[DataRecorder] 🗑️ Deleted: $filePath');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[DataRecorder] ❌ Failed to delete: $e');
      return false;
    }
  }

  @override
  void dispose() {
    stopRecording();
    _recordingTimer?.cancel();
    _speedSubscription?.cancel();
    _imuSubscription?.cancel();
    _gpsSubscription?.cancel();
    _lidarSubscription?.cancel();
    _steeringSubscription?.cancel();
    _cteSubscription?.cancel();
    _headingErrorSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }
}
