import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'logging_service.dart';

class RosService {
  static final RosService _instance = RosService._internal();
  factory RosService() => _instance;
  RosService._internal();

  // Connection management
  WebSocketChannel? _channel;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  String _rosBridgeUrl = 'ws://127.0.0.1:9090';

  // Track subscribed topics dynamically
  final Set<String> _subscribedTopics = {};

  // Speed calculation mode
  bool _useImuOnlyMode = false; // true = IMU only, false = GPS+IMU fusion
  bool _enableGyroSpeedCorrection =
      false; // Experimental: use gyro for speed correction

  // Legacy fusion variables - commented out since we use /velocity topic
  /*
  // Advanced IMU+GPS Fusion with Kalman-like approach
  double _fusedVelocityMs = 0.0; // Fused velocity estimate (m/s)
  double _velocityVariance = 1.0; // Uncertainty estimate

  // IMU velocity integration
  double _imuVelocityMs = 0.0;
  double _imuVariance = 0.1; // IMU process noise (increases over time)
  DateTime? _lastImuUpdate;
  double _imuBias = 0.0; // Estimated acceleration bias

  // Kalman filter parameters
  double _processNoise = 0.01; // System model uncertainty
  double _maxImuDrift = 2.0; // Max IMU velocity before reset (m/s)
  double _gpsTimeout = 3.0; // GPS timeout threshold (seconds)

  // Quality metrics
  double _gpsQuality = 0.5;
  double _imuQuality = 0.5;
  int _consecutiveGpsUpdates = 0;
  */

  // Stream controllers
  final StreamController<double> _speedometerController =
      StreamController<double>.broadcast();
  final StreamController<double> _speedometerRosController =
      StreamController<double>.broadcast();
  final StreamController<double> _ultrasonicController =
      StreamController<double>.broadcast();
  final StreamController<Map<String, double>> _gpsController =
      StreamController<Map<String, double>>.broadcast();
  final StreamController<List<double>> _lidarController =
      StreamController<List<double>>.broadcast();
  final StreamController<Map<String, dynamic>> _lidarSummaryController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, double>> _imuController =
      StreamController<Map<String, double>>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  // CBF/navigation streams
  final StreamController<double> _linearVelocityController =
      StreamController<double>.broadcast();
  final StreamController<double> _steeringAngleController =
      StreamController<double>.broadcast();
  final StreamController<double> _crossTrackErrorController =
      StreamController<double>.broadcast();
  final StreamController<double> _cbfValueController =
      StreamController<double>.broadcast();
  final StreamController<double> _boundaryDistanceController =
      StreamController<double>.broadcast();
  final StreamController<double> _cbfCorrectionController =
      StreamController<double>.broadcast();
  final StreamController<bool> _cbfActiveController =
      StreamController<bool>.broadcast();
  final StreamController<double> _headingErrorController =
      StreamController<double>.broadcast();
  final StreamController<double> _totalErrorController =
      StreamController<double>.broadcast();
  final StreamController<double> _obstacleDistanceController =
      StreamController<double>.broadcast();
  final StreamController<String> _obstaclePositionController =
      StreamController<String>.broadcast();
  final StreamController<double> _waypointIndexController =
      StreamController<double>.broadcast();

  // Witmotion IMU streams
  final StreamController<double> _witmotionYawController =
      StreamController<double>.broadcast();
  final StreamController<double> _witmotionAccelerationController =
      StreamController<double>.broadcast();
  final StreamController<double> _witmotionAngularVelocityController =
      StreamController<double>.broadcast();

  // Navigation status streams (from cbf_navigation_ros.py)
  final StreamController<Map<String, dynamic>> _navigationStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _tripStatusController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Public streams
  Stream<double> get speedometerStream => _speedometerController.stream;
  Stream<double> get speedometerRosStream => _speedometerRosController.stream;
  Stream<double> get ultrasonicStream => _ultrasonicController.stream;
  Stream<Map<String, double>> get gpsStream => _gpsController.stream;
  Stream<List<double>> get lidarStream => _lidarController.stream;
  Stream<Map<String, dynamic>> get lidarSummaryStream =>
      _lidarSummaryController.stream;
  Stream<Map<String, double>> get imuStream => _imuController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  Stream<double> get linearVelocityStream => _linearVelocityController.stream;
  Stream<double> get steeringAngleStream => _steeringAngleController.stream;
  Stream<double> get crossTrackErrorStream => _crossTrackErrorController.stream;
  Stream<double> get cbfValueStream => _cbfValueController.stream;
  Stream<double> get boundaryDistanceStream =>
      _boundaryDistanceController.stream;
  Stream<double> get cbfCorrectionStream => _cbfCorrectionController.stream;
  Stream<bool> get cbfActiveStream => _cbfActiveController.stream;
  Stream<double> get headingErrorStream => _headingErrorController.stream;
  Stream<double> get totalErrorStream => _totalErrorController.stream;
  Stream<double> get obstacleDistanceStream =>
      _obstacleDistanceController.stream;
  Stream<String> get obstaclePositionStream =>
      _obstaclePositionController.stream;
  Stream<double> get waypointIndexStream => _waypointIndexController.stream;

  Stream<double> get witmotionYawStream => _witmotionYawController.stream;
  Stream<double> get witmotionAccelerationStream =>
      _witmotionAccelerationController.stream;
  Stream<double> get witmotionAngularVelocityStream =>
      _witmotionAngularVelocityController.stream;

  // Navigation status streams
  Stream<Map<String, dynamic>> get navigationStatusStream =>
      _navigationStatusController.stream;
  Stream<Map<String, dynamic>> get tripStatusStream =>
      _tripStatusController.stream;

  // Get number of subscribed topics
  int get subscribedTopicsCount {
    // Return dynamic count of subscribed topics
    return _subscribedTopics.length;
  }

  // Timing trackers for data source priority
  DateTime? _lastWitmotionYawUpdate;
  // Note: _lastQuaternionYawUpdate removed since we simplified IMU handling

  // Data cache
  double _currentSpeed = 0.0;
  double _currentUltrasonicDistance = 0.0;
  final Map<String, double> _currentGPS = {'lat': -6.2088, 'lng': 106.8456};
  final Map<String, double> _currentImu = {
    'roll': 0.0,
    'pitch': 0.0,
    'yaw': 0.0,
  };
  List<double> _currentLidarRanges = [];

  // Getters - simplified for /velocity topic
  double get currentSpeed => _currentSpeed; // km/h for dashboard
  double get currentUltrasonicDistance => _currentUltrasonicDistance;
  Map<String, double> get currentGPS => Map.from(_currentGPS);
  Map<String, double> get currentImu => Map.from(_currentImu);
  List<double> get currentLidarRanges => List.from(_currentLidarRanges);
  bool get isConnected => _isConnected;

  // Legacy speed getters - return 0 since we use /velocity topic
  double get gpsSpeed => 0.0; // No longer calculated
  double get imuSpeed => 0.0; // No longer calculated
  double get fusedSpeed => 0.0; // No longer calculated
  double get gpsQuality => 0.5; // Default value
  double get imuQuality => 0.5; // Default value

  // Speed calculation mode control
  bool get useImuOnlyMode => _useImuOnlyMode;
  bool get enableGyroSpeedCorrection => _enableGyroSpeedCorrection;

  void setSpeedCalculationMode({bool? imuOnly, bool? gyroCorrection}) {
    if (imuOnly != null) {
      _useImuOnlyMode = imuOnly;
      _log(
        '📊 Speed Mode: ${imuOnly ? "IMU Only" : "GPS+IMU Fusion"} (Note: Using /velocity topic for speed)',
        level: 'INFO',
      );

      // Note: Reset logic disabled since we use /velocity topic
      /*
      if (imuOnly) {
        _imuVelocityMs = 0.0;
        _imuVariance = 0.1;
        _imuBias = 0.0;
        _log('🔄 IMU state reset for IMU-only mode', level: 'INFO');
      }
      */
    }
    if (gyroCorrection != null) {
      _enableGyroSpeedCorrection = gyroCorrection;
      _log(
        '🔄 Gyro Speed Correction: ${gyroCorrection ? "Enabled" : "Disabled"}',
        level: 'INFO',
      );
    }
  }

  // Force enable IMU-only mode for testing
  void enableImuOnlyForTesting() {
    setSpeedCalculationMode(imuOnly: true);
    _log('🧪 IMU-Only mode enabled for testing', level: 'INFO');
  }

  // Legacy methods - disabled since we use /velocity topic
  /*
  bool _detectZeroVelocity() {
    final ax = _currentImu['acceleration_x'] ?? 0.0;
    final ay = _currentImu['acceleration_y'] ?? 0.0;
    final az = _currentImu['acceleration_z'] ?? 0.0;
    final gx = _currentImu['angular_velocity_x'] ?? 0.0;
    final gy = _currentImu['angular_velocity_y'] ?? 0.0;
    final gz = _currentImu['angular_velocity_z'] ?? 0.0;

    final aMag = math.sqrt(ax * ax + ay * ay + az * az);
    final gMag = math.sqrt(gx * gx + gy * gy + gz * gz);

    return aMag < 0.15 && gMag < 0.08 && _imuVelocityMs.abs() < 2.78;
  }

  void _applyZeroVelocityUpdate() {
    if (_detectZeroVelocity()) {
      if (_imuVelocityMs.abs() < 2.78) {
        final prevVel = _imuVelocityMs * 3.6; // Store for logging
        _imuVelocityMs *= 0.7; // Gradual decay instead of immediate reset
        _imuVariance = 0.1; // Reset uncertainty

        // Update bias to prevent recurrence
        final currentAccel = _currentImu['acceleration_x'] ?? 0.0;
        if (currentAccel.abs() > 0.02) {
          _imuBias += currentAccel * 0.05; // Moderate bias correction
          _imuBias = _imuBias.clamp(-0.5, 0.5); // Limit bias range
        }

        if (kDebugMode) {
          _log(
            '🛑 Zero Velocity Update: IMU velocity ${prevVel.toStringAsFixed(2)} → ${(_imuVelocityMs * 3.6).toStringAsFixed(2)} km/h, bias=${_imuBias.toStringAsFixed(4)}',
            level: 'DEBUG',
          );
        }
      }
    }
  }

  void _emitFusedSpeed() {
    // Choose speed source based on mode
    double selectedSpeedMs;
    String speedSource;

    if (_useImuOnlyMode) {
      selectedSpeedMs = _imuVelocityMs;
      speedSource = "IMU-Only";
    } else {
      selectedSpeedMs = _fusedVelocityMs;
      speedSource = "Fused";
    }

    final speedKmh = _msToKmh(selectedSpeedMs);

    // Reduce noise by setting minimum speed threshold
    final finalSpeedKmh = speedKmh.abs() < 0.1 ? 0.0 : speedKmh;

    if ((finalSpeedKmh - _currentSpeed).abs() > 0.02) {
      _currentSpeed = finalSpeedKmh; // Dashboard gets km/h
      _safeAdd<double>(_speedometerController, finalSpeedKmh); // UI gets km/h
      _publishSpeedometerToRos(finalSpeedKmh); // ROS gets km/h

      if (kDebugMode) {
        _log(
          '🚀 $speedSource Speed: ${finalSpeedKmh.toStringAsFixed(2)} km/h (raw: ${speedKmh.toStringAsFixed(2)}) (GPS: ${(_gpsQuality * 100).toStringAsFixed(0)}%, IMU: ${(_imuQuality * 100).toStringAsFixed(0)}%)',
          level: 'DEBUG',
        );
      }
    }
  }

  Future<void> calibrateImuBias({int seconds = 8}) async {
    _log(
      '🔧 Calibrating IMU bias for ${seconds}s (assume stationary)...',
      level: 'INFO',
    );
    final samples = <double>[];
    final start = DateTime.now();
    while (DateTime.now().difference(start).inSeconds < seconds) {
      samples.add((_currentImu['acceleration_x'] ?? 0.0));
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (samples.isNotEmpty) {
      final avg = samples.reduce((a, b) => a + b) / samples.length;
      _imuBias = avg.clamp(-0.3, 0.3);
      _imuVelocityMs = 0.0;
      _imuVariance = 0.05;
      _log(
        '✅ IMU bias set to ${_imuBias.toStringAsFixed(6)} m/s²',
        level: 'INFO',
      );
    }
  }

  void resetImuIntegration() {
    _imuVelocityMs = 0.0;
    _imuBias = 0.0;
    _imuVariance = 0.1;
    _fusedVelocityMs = 0.0;
    _velocityVariance = 1.0;
    _lastImuUpdate = null;
    // Note: _lastGpsUpdate removed since we use /linear topic
    _log('🔄 IMU integration reset completed (using /linear for speed)', level: 'INFO');
  }
  */

  // Helper methods
  void _safeAdd<T>(StreamController<T> controller, T value) {
    try {
      if (!controller.isClosed) controller.add(value);
    } catch (e) {
      _log(
        '⚠️ Attempted to add event to closed controller: $e',
        level: 'WARNING',
      );
    }
  }

  double _wrapDeg(double d) => ((d + 180.0) % 360.0) - 180.0;

  // Legacy GPS distance calculation - not used with /velocity topic
  /*
  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0; // Earth radius in meters
    final latRad1 = lat1 * (math.pi / 180);
    final latRad2 = lat2 * (math.pi / 180);
    final dLat = (lat2 - lat1) * (math.pi / 180);
    final dLon = (lon2 - lon1) * (math.pi / 180);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(latRad1) *
            math.cos(latRad2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }
  */

  // Legacy GPS velocity calculation - no longer used with /velocity topic
  /*
  void _updateGpsVelocity() {
    final now = DateTime.now();
    if (_prevGpsLat != null && _prevGpsLng != null && _lastGpsUpdate != null) {
      final distanceM = _haversine(
        _prevGpsLat!,
        _prevGpsLng!,
        _currentGPS['lat']!,
        _currentGPS['lng']!,
      );
      final dtSeconds = now.difference(_lastGpsUpdate!).inMilliseconds / 1000.0;

      if (dtSeconds > 0.3 && dtSeconds < 5.0) {
        _gpsVelocityMs = distanceM / dtSeconds; // Store in m/s
        _consecutiveGpsUpdates++;

        // Adaptive GPS quality based on consistency and update rate
        final speedChangeRate =
            (_gpsVelocityMs -
                    (_fusedVelocityMs == 0 ? _gpsVelocityMs : _fusedVelocityMs))
                .abs();
        _gpsQuality = math.max(
          0.1,
          math.min(
            1.0,
            0.8 -
                (speedChangeRate * 0.1) +
                (_consecutiveGpsUpdates > 5 ? 0.2 : 0.0),
          ),
        );

        // Lower GPS variance when quality is high
        _gpsVariance = 0.1 + (1.0 - _gpsQuality) * 0.4;

        _performKalmanUpdate();
        _lastGpsUpdate = now;

        if (kDebugMode) {
          _log(
            '🌍 GPS: ${(_gpsVelocityMs * 3.6).toStringAsFixed(2)} km/h, quality: ${(_gpsQuality * 100).toStringAsFixed(1)}%',
            level: 'DEBUG',
          );
        }
      }
    } else {
      _lastGpsUpdate = now;
    }
    _prevGpsLat = _currentGPS['lat'];
    _prevGpsLng = _currentGPS['lng'];
  }
  */

  // Gravity compensation for linear acceleration (use roll/pitch)
  Map<String, double> _compensateGravity(
    double accX,
    double accY,
    double accZ,
    double rollRad,
    double pitchRad,
  ) {
    const g = 9.80665; // m/s^2
    final gravityBodyX = g * math.sin(pitchRad);
    final gravityBodyY = -g * math.sin(rollRad) * math.cos(pitchRad);
    final gravityBodyZ = -g * math.cos(rollRad) * math.cos(pitchRad);
    return {
      'x': accX - gravityBodyX,
      'y': accY - gravityBodyY,
      'z': accZ - gravityBodyZ,
    };
  }

  // Legacy IMU velocity integration - disabled since we use /velocity topic
  /*
  void _updateImuVelocity(double accelX) {
    final now = DateTime.now();
    if (_lastImuUpdate != null) {
      final dtSeconds = now.difference(_lastImuUpdate!).inMilliseconds / 1000.0;
      if (dtSeconds > 0.001 && dtSeconds < 0.5) {
        // Bias-corrected acceleration integration (result in m/s)
        final correctedAccel = accelX - _imuBias;
        _imuVelocityMs += correctedAccel * dtSeconds; // Store in m/s

        // **CRITICAL FIX**: Cap velocity to realistic vehicle speeds
        // Maximum 50 km/h = 13.89 m/s for testing safety
        const maxVelocityMs = 13.89; // 50 km/h
        if (_imuVelocityMs.abs() > maxVelocityMs) {
          _imuVelocityMs = _imuVelocityMs.isNegative
              ? -maxVelocityMs
              : maxVelocityMs;
          _imuBias += (accelX.abs() > 0.1 ? accelX * 0.1 : 0.0);
          if (kDebugMode) {
            _log(
              '🛑 VELOCITY CAPPED: Exceeded ${maxVelocityMs * 3.6} km/h, bias updated to ${_imuBias.toStringAsFixed(4)}',
              level: 'WARNING',
            );
          }
        }

        // **Enhanced drift detection**: Reset if velocity is clearly unrealistic
        if (_imuVelocityMs.abs() > 8.33) {
          // 30 km/h threshold for drift reset
          final accelMagnitude = accelX.abs();
          // If acceleration is small but velocity is high, likely drift
          if (accelMagnitude < 0.5) {
            _imuVelocityMs *= 0.8; // Decay unrealistic velocity
            _imuBias += accelX * 0.02; // Update bias more aggressively
            if (kDebugMode) {
              _log(
                '⚠️ DRIFT CORRECTION: Vel=${(_imuVelocityMs * 3.6).toStringAsFixed(1)} km/h, Accel=${accelX.toStringAsFixed(3)} m/s²',
                level: 'WARNING',
              );
            }
          }
        }

        // Increase IMU uncertainty over time (drift modeling) - but less aggressively
        _imuVariance = math.min(
          2.0,
          _imuVariance + _processNoise * dtSeconds * 0.5,
        );

        // Adaptive IMU quality based on variance and time since GPS
        final timeSinceGps = _lastGpsUpdate != null
            ? now.difference(_lastGpsUpdate!).inSeconds.toDouble()
            : 10.0;
        _imuQuality = math.max(
          0.1,
          math.min(
            1.0,
            1.0 - (_imuVariance * 0.3) - (timeSinceGps / 15.0),
          ), // Less penalty
        );

        // Reset IMU if drift becomes excessive (only in fusion mode) - higher threshold
        if (!_useImuOnlyMode &&
            (_imuVelocityMs - _gpsVelocityMs).abs() >
                (_maxImuDrift * 2.0) && // 4 m/s threshold instead of 2 m/s
            _lastGpsUpdate != null &&
            timeSinceGps < _gpsTimeout) {
          _resetImuToGps();
        }

        // In IMU-only mode, always emit speed. In fusion mode, do Kalman prediction
        if (_useImuOnlyMode) {
          // **More aggressive zero velocity detection** for IMU-only mode
          final currentAccelX = _currentImu['acceleration_x'] ?? 0.0;
          final currentAngVel = _currentImu['angular_velocity_y'] ?? 0.0;

          // More lenient zero velocity conditions
          if (_imuVelocityMs.abs() < 2.78 && // Less than 10 km/h
              currentAccelX.abs() < 0.1 && // Small acceleration
              currentAngVel.abs() < 0.05) {
            // Small angular velocity
            _applyZeroVelocityUpdate();
          }

          // **Periodic bias reset** in IMU-only mode to prevent long-term drift
          if (timeSinceGps > 30.0 && _imuVelocityMs.abs() > 5.56) {
            // 20 km/h after 30s
            _imuBias += (accelX) * 0.1; // Strong bias correction
            _imuVelocityMs *= 0.5; // Decay velocity significantly
            if (kDebugMode) {
              _log(
                '🔄 PERIODIC RESET: Long-term drift detected, bias=${_imuBias.toStringAsFixed(4)}',
                level: 'WARNING',
              );
            }
          }

          _emitFusedSpeed(); // Always emit IMU-only speed
        } else {
          _performKalmanPrediction(); // ENHANCED: now uses IMU as input too
        }
      }
    }
    _lastImuUpdate = now;
  }
  */

  // Legacy Kalman filter methods - not used with /velocity topic
  /*
  void _performKalmanPrediction() {
    if (_lastImuUpdate != null) {
      final now = DateTime.now();
      final dt = now.difference(_lastImuUpdate!).inMilliseconds / 1000.0;
      if (dt > 0 && dt < 0.5) {
        final a = (_currentImu['acceleration_x'] ?? 0.0) - _imuBias;
        _fusedVelocityMs += a * dt; // state prediction with IMU
      }
    }
    _velocityVariance += _processNoise * 0.01;
  }

  void _performKalmanUpdate() {
    if (_lastGpsUpdate == null) return;

    final now = DateTime.now();
    final timeSinceGps = now.difference(_lastGpsUpdate!).inSeconds.toDouble();

    // Skip update if GPS is too stale
    if (timeSinceGps > _gpsTimeout) {
      _consecutiveGpsUpdates = 0;
      return;
    }

    // Kalman gain calculation
    final totalVariance = _velocityVariance + _gpsVariance;
    final kalmanGain = _velocityVariance / totalVariance;

    // State update (weighted fusion) - all calculations in m/s
    final innovation = _gpsVelocityMs - _fusedVelocityMs;
    _fusedVelocityMs += kalmanGain * innovation;

    // Covariance update
    _velocityVariance = (1.0 - kalmanGain) * _velocityVariance;

    // Bias estimation (simple approach) - reduced aggressiveness
    if (_consecutiveGpsUpdates > 5) {
      final velocityError = _imuVelocityMs - _gpsVelocityMs;
      _imuBias += velocityError * 0.005;
      _imuBias = _imuBias.clamp(-0.3, 0.3);
    }

    // Reset IMU integration to fused estimate to prevent drift
    _imuVelocityMs = _fusedVelocityMs;
    _imuVariance = math.max(0.1, _imuVariance * 0.8);

    _emitFusedSpeed();
  }

  void _resetImuToGps() {
    _imuVelocityMs = _gpsVelocityMs; // Reset in m/s
    _imuVariance = 0.2;
    _imuBias = 0.0;
    if (kDebugMode) {
      _log('🔄 IMU reset to GPS velocity', level: 'DEBUG');
    }
  }
  */

  // Legacy _emitFusedSpeed method - disabled since we use /velocity topic
  /*
  void _emitFusedSpeed() {
    // Choose speed source based on mode
    double selectedSpeedMs;
    String speedSource;

    if (_useImuOnlyMode) {
      selectedSpeedMs = _imuVelocityMs;
      speedSource = "IMU-Only";
    } else {
      selectedSpeedMs = _fusedVelocityMs;
      speedSource = "Fused";
    }

    final speedKmh = _msToKmh(selectedSpeedMs);

    // Reduce noise by setting minimum speed threshold
    final finalSpeedKmh = speedKmh.abs() < 0.1 ? 0.0 : speedKmh;

    if ((finalSpeedKmh - _currentSpeed).abs() > 0.02) {
      _currentSpeed = finalSpeedKmh; // Dashboard gets km/h
      _safeAdd<double>(_speedometerController, finalSpeedKmh); // UI gets km/h
      _publishSpeedometerToRos(finalSpeedKmh); // ROS gets km/h

      if (kDebugMode) {
        _log(
          '🚀 $speedSource Speed: ${finalSpeedKmh.toStringAsFixed(2)} km/h (raw: ${speedKmh.toStringAsFixed(2)}) (GPS: ${(_gpsQuality * 100).toStringAsFixed(0)}%, IMU: ${(_imuQuality * 100).toStringAsFixed(0)}%)',
          level: 'DEBUG',
        );
      }
    }
  }
  */

  // API
  Future<void> initialize({
    String? rosBridgeUrl,
    bool? enableImuOnlyMode,
  }) async {
    if (rosBridgeUrl != null) _rosBridgeUrl = rosBridgeUrl;

    // Enable IMU-only mode if requested
    if (enableImuOnlyMode == true) {
      _useImuOnlyMode = true;
      _log('🧪 IMU-Only mode enabled during initialization', level: 'INFO');
    }

    LoggingService.info(
      'Initializing ROS Service with /velocity topic for speed data (simplified from GPS+IMU fusion)',
      component: 'RosService',
    );
    await _connectToRosBridge();
  }

  Future<void> _connectToRosBridge() async {
    try {
      LoggingService.info(
        'Connecting to ROS Bridge at $_rosBridgeUrl',
        component: 'RosService',
      );

      // Create WebSocket channel
      _channel = IOWebSocketChannel.connect(
        _rosBridgeUrl,
        pingInterval: const Duration(seconds: 5),
      );

      // Wait for connection to be ready
      await _channel!.ready.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Connection timeout to $_rosBridgeUrl');
        },
      );

      // Connection successful - now set up listeners
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleConnectionError,
        onDone: _handleConnectionClosed,
      );

      _isConnected = true;
      _safeAdd<bool>(_connectionController, true);
      _subscribeToAllTopics();
      LoggingService.rosConnection('Successfully connected', connected: true);
      _log('🟢 ROS: Successfully connected to $_rosBridgeUrl', level: 'INFO');
    } on TimeoutException catch (e) {
      LoggingService.error(
        'Connection timeout to ROS Bridge',
        component: 'RosService',
        error: e,
      );
      _log('⏱️ Connection timeout to $_rosBridgeUrl', level: 'WARNING');
      _handleConnectionError(e);
    } catch (e) {
      LoggingService.error(
        'Failed to connect to ROS Bridge',
        component: 'RosService',
        error: e,
      );
      _log('❌ Failed to connect: $e', level: 'ERROR');
      _handleConnectionError(e);
    }
  }

  void _handleConnectionError(dynamic error) {
    LoggingService.error(
      'WebSocket Error',
      component: 'RosService',
      error: error,
    );
    _isConnected = false;
    _subscribedTopics.clear(); // Clear subscribed topics on error
    _safeAdd<bool>(_connectionController, false);

    // Only schedule auto-reconnect if not doing a manual reconnect
    if (!_isReconnecting) {
      _scheduleReconnection();
    }
  }

  void _handleConnectionClosed() {
    _log('🔌 WebSocket connection closed', level: 'WARNING');
    _isConnected = false;
    _subscribedTopics.clear(); // Clear subscribed topics on close
    _safeAdd<bool>(_connectionController, false);

    // Only schedule auto-reconnect if not doing a manual reconnect
    if (!_isReconnecting) {
      _scheduleReconnection();
    }
  }

  void _scheduleReconnection() {
    // Don't schedule if manual reconnection is in progress
    if (_isReconnecting) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isReconnecting && !_isConnected) {
        _log('🔄 Attempting to reconnect to ROS Bridge...', level: 'INFO');
        _connectToRosBridge();
      }
    });
  }

  void _subscribeToAllTopics() {
    if (!_isConnected || _channel == null) return;

    // Clear previous subscriptions tracking
    _subscribedTopics.clear();

    final topics = [
      {'topic': '/ultrasonic_data', 'type': 'std_msgs/Float64'},
      {'topic': '/latitude', 'type': 'std_msgs/Float64'},
      {'topic': '/longitude', 'type': 'std_msgs/Float64'},
      {'topic': '/velocity', 'type': 'std_msgs/Float32'},
      {'topic': '/scan', 'type': 'sensor_msgs/LaserScan'},

      // Navigation/CBF
      {'topic': '/steering_angle', 'type': 'std_msgs/Float32'},
      {'topic': '/yaw', 'type': 'std_msgs/Float32'},
      {'topic': '/yaw_imu', 'type': 'std_msgs/Float32'},
      {'topic': '/yaw_gps', 'type': 'std_msgs/Float32'},
      {'topic': '/cte', 'type': 'std_msgs/Float32'},
      {'topic': '/cbf_value', 'type': 'std_msgs/Float32'},
      {'topic': '/boundary_dist', 'type': 'std_msgs/Float32'},
      {'topic': '/cbf_correction', 'type': 'std_msgs/Float32'},
      {'topic': '/cbf_active', 'type': 'std_msgs/Float32'},
      {'topic': '/heading_error', 'type': 'std_msgs/Float32'},
      {'topic': '/total_error', 'type': 'std_msgs/Float32'},
      {'topic': '/obstacle_distance', 'type': 'std_msgs/Float32'},
      {'topic': '/obstacle_position', 'type': 'std_msgs/String'},
      {'topic': '/wp_index', 'type': 'std_msgs/Float32'},
      {'topic': '/dist_to_nearest', 'type': 'std_msgs/Float32'},
      {'topic': '/dist_to_next', 'type': 'std_msgs/Float32'},

      // Navigation status from cbf_navigation_ros.py (No Firebase!)
      {'topic': '/navigation_status', 'type': 'std_msgs/String'},
      {'topic': '/trip_status', 'type': 'std_msgs/String'},

      // IMU sensors
      {'topic': '/sensor/imu', 'type': 'sensor_msgs/Imu'},
      {'topic': '/imu/data', 'type': 'sensor_msgs/Imu'},
      {'topic': '/imu', 'type': 'sensor_msgs/Imu'},
      {'topic': '/imu/data_raw', 'type': 'sensor_msgs/Imu'},
      {'topic': '/0dataz', 'type': 'std_msgs/Float32'},
      {'topic': '/0dataa', 'type': 'std_msgs/Float32'},
      {'topic': '/0datav', 'type': 'std_msgs/Float32'},

      // Velodyne 3D Lidar (PointCloud2)
      {'topic': '/velodyne_points', 'type': 'sensor_msgs/PointCloud2'},
    ];

    for (final t in topics) {
      _sendMessage({'op': 'subscribe', 'topic': t['topic'], 'type': t['type']});
      // Track subscribed topic
      _subscribedTopics.add(t['topic'] as String);
    }

    _sendMessage({
      'op': 'advertise',
      'topic': '/destination_coordinate',
      'type': 'std_msgs/String',
    });
    _sendMessage({
      'op': 'advertise',
      'topic': '/destination_lat',
      'type': 'std_msgs/Float64',
    });
    _sendMessage({
      'op': 'advertise',
      'topic': '/destination_lon',
      'type': 'std_msgs/Float64',
    });
    _sendMessage({
      'op': 'advertise',
      'topic': '/waypoints_array',
      'type': 'std_msgs/String',
    });
    _sendMessage({
      'op': 'advertise',
      'topic': '/trip_data',
      'type': 'std_msgs/String',
    });
    _sendMessage({
      'op': 'advertise',
      'topic': '/navigation_command',
      'type': 'std_msgs/String',
    });
    _sendMessage({
      'op': 'advertise',
      'topic': '/speedometer',
      'type': 'std_msgs/Float32',
    });
    _sendMessage({
      'op': 'advertise',
      'topic': '/yaw_imu',
      'type': 'std_msgs/Float32',
    });
    _sendMessage({
      'op': 'advertise',
      'topic': '/sensor/lidar',
      'type': 'std_msgs/Float64MultiArray',
    });
    _sendMessage({
      'op': 'advertise',
      'topic': '/waypoints_array',
      'type': 'std_msgs/String',
    });
    _sendMessage({
      'op': 'advertise',
      'topic': '/trip_data',
      'type': 'std_msgs/String',
    });
    _sendMessage({
      'op': 'advertise',
      'topic': '/navigation_command',
      'type': 'std_msgs/String',
    });

    _log(
      '📡 Subscribed to navigation status topics from cbf_navigation_ros.py',
      level: 'INFO',
    );
  }

  void _sendMessage(Map<String, dynamic> message) {
    if (!_isConnected || _channel == null) {
      _log(
        '⚠️ Cannot send message: Not connected to ROS Bridge',
        level: 'WARNING',
      );
      return;
    }
    try {
      final jsonMessage = jsonEncode(message);
      _channel!.sink.add(jsonMessage);
      if (kDebugMode) {
        _log(
          '📤 Sent: ${message['op']} for ${message['topic']}',
          level: 'DEBUG',
        );
      }
    } catch (e) {
      _log('❌ Failed to send message: $e', level: 'ERROR');
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      if (data['op'] == 'publish') {
        final topic = data['topic'] as String;
        final msg = data['msg'] as Map<String, dynamic>;

        // Debug logging untuk melihat topic yang masuk
        if (kDebugMode) {
          _log('📥 Received message from topic: $topic', level: 'DEBUG');
        }

        if (topic == '/scan') {
          _handleLaserScan(msg);
          return;
        }
        if (topic == '/velodyne_points') {
          _handleVelodynePointCloud2(msg);
          return;
        }
        _processTopicMessage(topic, msg);
      }
    } catch (e) {
      _log('❌ Error parsing ROS message: $e', level: 'ERROR');
    }
  }

  void _processTopicMessage(String topic, Map<String, dynamic> msg) {
    if (kDebugMode) {
      _log(
        '🔄 Processing topic: $topic with data: ${msg.toString().length > 100 ? "${msg.toString().substring(0, 100)}..." : msg.toString()}',
        level: 'DEBUG',
      );
    }

    switch (topic) {
      case '/velocity':
        _handleVelocitySpeedData(msg);
        break;
      case '/speedometer':
        _handleSpeedometerRosData(msg);
        break;
      case '/ultrasonic_data':
        _handleUltrasonicData(msg);
        break;
      case '/latitude':
        _handleLatitudeData(msg);
        break;
      case '/longitude':
        _handleLongitudeData(msg);
        break;
      case '/sensor/imu':
      case '/imu/data':
      case '/imu':
      case '/imu/data_raw':
        _handleImuData(msg);
        break;
      case '/steering_angle':
        _handleSteeringAngleData(msg);
        break;
      case '/yaw':
        _handleSteeringAngleData(msg);
        break;
      case '/cte':
        _handleCrossTrackErrorData(msg);
        break;
      case '/cbf_value':
        _handleCbfValueData(msg);
        break;
      case '/boundary_dist':
        _handleBoundaryDistanceData(msg);
        break;
      case '/cbf_correction':
        _handleCbfCorrectionData(msg);
        break;
      case '/cbf_active':
        _handleCbfActiveData(msg);
        break;
      case '/heading_error':
        _handleHeadingErrorData(msg);
        break;
      case '/total_error':
        _handleTotalErrorData(msg);
        break;
      case '/obstacle_distance':
        _handleObstacleDistanceData(msg);
        break;
      case '/obstacle_position':
        _handleObstaclePositionData(msg);
        break;
      case '/wp_index':
        _handleWaypointIndexData(msg);
        break;
      case '/0dataz':
        _handleWitmotionYawData(msg);
        break;
      case '/0dataa':
        _handleWitmotionAccelerationData(msg);
        break;
      case '/0datav':
        _handleWitmotionAngularVelocityData(msg);
        break;
      case '/navigation_status':
        _handleNavigationStatusData(msg);
        break;
      case '/trip_status':
        _handleTripStatusData(msg);
        break;
      default:
        if (kDebugMode) _log('🔍 Unknown topic: $topic', level: 'DEBUG');
    }
  }

  // Navigation status handler from cbf_navigation_ros.py
  void _handleNavigationStatusData(Map<String, dynamic> msg) {
    try {
      final dataStr = msg['data'] as String?;
      if (dataStr != null && dataStr.isNotEmpty) {
        final statusData = jsonDecode(dataStr) as Map<String, dynamic>;
        _safeAdd<Map<String, dynamic>>(_navigationStatusController, statusData);
        if (kDebugMode) {
          _log(
            '🚗 Navigation Status: ${statusData['state']} - WP ${statusData['waypoint_index']}/${statusData['total_waypoints']}',
            level: 'INFO',
          );
        }
      }
    } catch (e) {
      _log('❌ Error parsing navigation status: $e', level: 'ERROR');
    }
  }

  // Trip status handler from cbf_navigation_ros.py
  void _handleTripStatusData(Map<String, dynamic> msg) {
    try {
      final dataStr = msg['data'] as String?;
      if (dataStr != null && dataStr.isNotEmpty) {
        final tripData = jsonDecode(dataStr) as Map<String, dynamic>;
        _safeAdd<Map<String, dynamic>>(_tripStatusController, tripData);
        if (kDebugMode) {
          _log(
            '📍 Trip Status: ${tripData['trip_name']} - Progress: ${tripData['progress_percent']}%',
            level: 'INFO',
          );
        }
      }
    } catch (e) {
      _log('❌ Error parsing trip status: $e', level: 'ERROR');
    }
  }

  // Enhanced GPS handler - simplified since we use /velocity for speed
  void _handleLatitudeData(Map<String, dynamic> msg) {
    final lat = (msg['data'] as num).toDouble();
    _currentGPS['lat'] = lat;
    // No longer updating GPS velocity since we use /velocity topic
    _safeAdd<Map<String, double>>(_gpsController, Map.from(_currentGPS));
  }

  void _handleLongitudeData(Map<String, dynamic> msg) {
    final lng = (msg['data'] as num).toDouble();
    _currentGPS['lng'] = lng;
    // No longer updating GPS velocity since we use /velocity topic
    _safeAdd<Map<String, double>>(_gpsController, Map.from(_currentGPS));
    if (kDebugMode) {
      _log(
        '🌍 GPS: (${_currentGPS['lat']?.toStringAsFixed(6)}, ${_currentGPS['lng']?.toStringAsFixed(6)})',
        level: 'DEBUG',
      );
    }
  }

  // Enhanced IMU handler with gravity compensation and multi-axis capture
  void _handleImuData(Map<String, dynamic> msg) {
    try {
      double yaw = 0.0, pitch = 0.0, roll = 0.0;
      if (msg.containsKey('orientation')) {
        final orient = msg['orientation'] as Map<String, dynamic>;
        final double qx = (orient['x'] as num?)?.toDouble() ?? 0.0;
        final double qy = (orient['y'] as num?)?.toDouble() ?? 0.0;
        final double qz = (orient['z'] as num?)?.toDouble() ?? 0.0;
        final double qw = (orient['w'] as num?)?.toDouble() ?? 1.0;
        yaw = math.atan2(
          2.0 * (qw * qz + qx * qy),
          1.0 - 2.0 * (qy * qy + qz * qz),
        );
        pitch = math.asin((2.0 * (qw * qy - qz * qx)).clamp(-1.0, 1.0));
        roll = math.atan2(
          2.0 * (qw * qx + qy * qz),
          1.0 - 2.0 * (qx * qx + qy * qy),
        );
        yaw = _wrapDeg(yaw * 180.0 / math.pi);
        pitch = pitch * 180.0 / math.pi;
        roll = roll * 180.0 / math.pi;
      }

      // Extract linear acceleration and compensate gravity
      if (msg.containsKey('linear_acceleration')) {
        final linAcc = msg['linear_acceleration'] as Map<String, dynamic>;
        final ax = (linAcc['x'] as num?)?.toDouble() ?? 0.0;
        final ay = (linAcc['y'] as num?)?.toDouble() ?? 0.0;
        final az = (linAcc['z'] as num?)?.toDouble() ?? 0.0;

        final comp = _compensateGravity(
          ax,
          ay,
          az,
          roll * math.pi / 180.0,
          pitch * math.pi / 180.0,
        );

        _currentImu['acceleration_x'] = comp['x']!;
        _currentImu['acceleration_y'] = comp['y']!;
        _currentImu['acceleration_z'] = comp['z']!;

        // Note: IMU velocity integration disabled since we use /velocity topic
        // _updateImuVelocity(comp['x']!);
      }

      // Extract angular velocity for multi-axis ZUPT
      if (msg.containsKey('angular_velocity')) {
        final angVel = msg['angular_velocity'] as Map<String, dynamic>;
        _currentImu['angular_velocity_x'] =
            (angVel['x'] as num?)?.toDouble() ?? 0.0;
        _currentImu['angular_velocity_y'] =
            (angVel['y'] as num?)?.toDouble() ?? 0.0;
        _currentImu['angular_velocity_z'] =
            (angVel['z'] as num?)?.toDouble() ?? 0.0;
      }

      _currentImu['roll'] = roll;
      _currentImu['pitch'] = pitch;

      // Only update yaw from quaternion if we don't have recent Witmotion yaw data
      final now = DateTime.now();
      final witmotionAge = _lastWitmotionYawUpdate != null
          ? now.difference(_lastWitmotionYawUpdate!).inMilliseconds
          : 999999;

      if (witmotionAge > 500) {
        // Use quaternion yaw if Witmotion data is >500ms old
        _currentImu['yaw'] = yaw;
        // Note: _lastQuaternionYawUpdate tracking removed since we simplified the logic
        if (kDebugMode) {
          _log('🧭 IMU(quat): yaw=${yaw.toStringAsFixed(1)}°', level: 'DEBUG');
        }
      } else {
        if (kDebugMode) {
          _log(
            '🧭 IMU(quat): yaw=${yaw.toStringAsFixed(1)}° [IGNORED - using Witmotion]',
            level: 'DEBUG',
          );
        }
      }

      _safeAdd<Map<String, double>>(_imuController, Map.from(_currentImu));
    } catch (e) {
      if (kDebugMode) {
        _log('⚠️ Error parsing IMU message: $e', level: 'WARNING');
      }
    }
  }

  void _handleWitmotionAccelerationData(Map<String, dynamic> msg) {
    final acceleration = (msg['data'] as num).toDouble();
    // treat as body X, but let _handleImuData be main path for gravity comp
    _currentImu['acceleration_x'] = acceleration;
    _safeAdd<Map<String, double>>(_imuController, Map.from(_currentImu));
    _safeAdd<double>(_witmotionAccelerationController, acceleration);

    // Note: IMU velocity integration disabled since we use /velocity topic
    // _updateImuVelocity(acceleration);

    if (kDebugMode) {
      _log(
        '⚡ Witmotion Accel: ${acceleration.toStringAsFixed(4)} m/s² (IMU velocity integration disabled - using /velocity)',
        level: 'DEBUG',
      );
    }
  }

  void _handleWitmotionYawData(Map<String, dynamic> msg) {
    final rawYaw = (msg['data'] as num).toDouble();
    // Negate the yaw data as requested (-1 multiplication)
    final yaw = -rawYaw;

    // Update timestamp for data source priority
    _lastWitmotionYawUpdate = DateTime.now();

    // Update the main IMU stream with the corrected yaw
    _currentImu['yaw'] = yaw;
    _safeAdd<Map<String, double>>(_imuController, Map.from(_currentImu));

    // Also add to Witmotion-specific stream for debugging
    _safeAdd<double>(_witmotionYawController, yaw);

    if (kDebugMode) {
      _log(
        '🧭 Witmotion Yaw: ${rawYaw.toStringAsFixed(1)}° → ${yaw.toStringAsFixed(1)}° (negated)',
        level: 'DEBUG',
      );
    }
  }

  void _handleWitmotionAngularVelocityData(Map<String, dynamic> msg) {
    final angVel = (msg['data'] as num).toDouble();
    _currentImu['angular_velocity_y'] = angVel;
    _safeAdd<Map<String, double>>(_imuController, Map.from(_currentImu));
    _safeAdd<double>(_witmotionAngularVelocityController, angVel);
  }

  void _handleVelocitySpeedData(Map<String, dynamic> msg) {
    final speedMs = (msg['data'] as num).toDouble(); // Data dari ROS dalam m/s
    final speedKmh = speedMs * 3.6; // Konversi ke km/h

    // Update current speed untuk dashboard
    _currentSpeed = speedKmh;

    // Emit ke stream controller
    _safeAdd<double>(_speedometerController, speedKmh);
    _safeAdd<double>(_speedometerRosController, speedKmh);

    // Publish back to ROS untuk logging atau monitoring
    _publishSpeedometerToRos(speedKmh);

    if (kDebugMode) {
      _log(
        '🚗 Velocity Speed (/velocity): ${speedMs.toStringAsFixed(2)} m/s → ${speedKmh.toStringAsFixed(2)} km/h',
        level: 'DEBUG',
      );
    }
  }

  void _handleSpeedometerRosData(Map<String, dynamic> msg) {
    final speedKmh = (msg['data'] as num).toDouble();
    _safeAdd<double>(_speedometerRosController, speedKmh);
    if (kDebugMode) {
      _log(
        '🚗 Speedometer (/speedometer): ${speedKmh.toStringAsFixed(1)} km/h',
        level: 'DEBUG',
      );
    }
  }

  void _handleUltrasonicData(Map<String, dynamic> msg) {
    final distance = (msg['data'] as num).toDouble();
    _currentUltrasonicDistance = distance;
    _safeAdd<double>(_ultrasonicController, distance);
    if (kDebugMode) {
      _log('📡 Ultrasonic: ${distance.toStringAsFixed(2)} m', level: 'DEBUG');
    }
  }

  void _handleLaserScan(Map<String, dynamic> msg) {
    final double angleMin = (msg['angle_min'] as num).toDouble();
    final double angleInc = (msg['angle_increment'] as num).toDouble();
    final double angleMax = (msg['angle_max'] as num).toDouble();
    final double rangeMin = (msg['range_min'] as num).toDouble();
    final double rangeMax = (msg['range_max'] as num).toDouble();

    final List<dynamic> raw = (msg['ranges'] as List<dynamic>? ?? const []);
    if (raw.isEmpty || angleInc == 0) {
      if (kDebugMode) {
        _log('⚠️ /scan empty or angle_increment=0', level: 'WARNING');
      }
      return;
    }

    int invalidCount = 0;
    final filtered = List<double>.generate(raw.length, (i) {
      final v = raw[i];
      if (v == null) {
        invalidCount++;
        return double.nan;
      }
      final d = (v as num).toDouble();
      if (d < rangeMin || d > rangeMax || d.isNaN || d.isInfinite) {
        invalidCount++;
        return double.nan;
      }
      return d;
    });

    final step = math.max(1, (filtered.length / 360).floor());
    final processed = <double>[];
    for (int i = 0; i < filtered.length; i += step) {
      final d = filtered[i];
      processed.add(d.isNaN ? rangeMax : d);
    }

    _currentLidarRanges = processed;
    _safeAdd<List<double>>(_lidarController, List.from(processed));
    _safeAdd<Map<String, dynamic>>(_lidarSummaryController, {
      'invalid_count': invalidCount,
      'total': raw.length,
      'step': step,
      'angle_min': angleMin,
      'angle_max': angleMax,
      'range_min': rangeMin,
      'range_max': rangeMax,
    });
  }

  /// Handle Velodyne PointCloud2 messages
  /// Projects 3D point cloud to 2D laser scan format for unified visualization
  void _handleVelodynePointCloud2(Map<String, dynamic> msg) {
    try {
      // PointCloud2 structure:
      // - height: number of rows (1 for unordered cloud)
      // - width: number of points per row
      // - point_step: bytes per point
      // - row_step: bytes per row
      // - fields: array describing each field (x, y, z, intensity, etc.)
      // - data: base64 encoded binary data
      
      final int width = (msg['width'] as num?)?.toInt() ?? 0;
      final int height = (msg['height'] as num?)?.toInt() ?? 1;
      final int pointStep = (msg['point_step'] as num?)?.toInt() ?? 0;
      final List<dynamic>? fields = msg['fields'] as List<dynamic>?;
      final String? dataBase64 = msg['data'] as String?;
      
      if (width == 0 || pointStep == 0 || dataBase64 == null || dataBase64.isEmpty) {
        if (kDebugMode) {
          _log('⚠️ /velodyne_points: Invalid PointCloud2 structure', level: 'WARNING');
        }
        return;
      }
      
      // Parse field offsets (find x, y, z offsets in point data)
      int xOffset = -1, yOffset = -1, zOffset = -1;
      if (fields != null) {
        for (final field in fields) {
          final name = field['name'] as String?;
          final offset = (field['offset'] as num?)?.toInt() ?? 0;
          if (name == 'x') xOffset = offset;
          if (name == 'y') yOffset = offset;
          if (name == 'z') zOffset = offset;
        }
      }
      
      // Default Velodyne offsets if not specified
      if (xOffset < 0) xOffset = 0;
      if (yOffset < 0) yOffset = 4;
      if (zOffset < 0) zOffset = 8;
      
      // Decode base64 data
      final bytes = base64Decode(dataBase64);
      final data = bytes.buffer.asByteData();
      final totalPoints = width * height;
      
      // Configuration for 2D projection
      const double minZ = 0.2;  // Minimum height from ground (meters)
      const double maxZ = 1.5;  // Maximum height (meters)
      const double maxRange = 5.6; // Maximum range for Velodyne
      const int numBins = 360;  // Angular resolution (360 bins = 1 degree each)
      
      // Initialize range bins (360 degrees, -180 to +180)
      final ranges = List<double>.filled(numBins, maxRange);
      
      // Process each point
      for (int i = 0; i < totalPoints && (i * pointStep + zOffset + 4) <= bytes.length; i++) {
        final int offset = i * pointStep;
        
        // Read x, y, z as floats (little endian)
        final double x = data.getFloat32(offset + xOffset, Endian.little);
        final double y = data.getFloat32(offset + yOffset, Endian.little);
        final double z = data.getFloat32(offset + zOffset, Endian.little);
        
        // Skip invalid or NaN points
        if (x.isNaN || y.isNaN || z.isNaN) continue;
        if (x == 0.0 && y == 0.0) continue;
        
        // Filter by height (project only points in relevant height range)
        if (z < minZ || z > maxZ) continue;
        
        // Calculate 2D distance and angle
        final double distance = math.sqrt(x * x + y * y);
        if (distance < 0.1 || distance > maxRange) continue;
        
        // Calculate angle in degrees (-180 to +180)
        // Velodyne: x=forward, y=left
        final double angleDeg = math.atan2(y, x) * 180.0 / math.pi;
        
        // Convert angle to bin index (0-359)
        int binIndex = ((angleDeg + 180.0) * numBins / 360.0).round() % numBins;
        
        // Keep minimum distance for each angle bin
        if (distance < ranges[binIndex]) {
          ranges[binIndex] = distance;
        }
      }
      
      // Update lidar stream with projected ranges
      _currentLidarRanges = ranges;
      _safeAdd<List<double>>(_lidarController, List.from(ranges));
      _safeAdd<Map<String, dynamic>>(_lidarSummaryController, {
        'source': 'velodyne',
        'total': totalPoints,
        'filtered': ranges.where((r) => r < maxRange).length,
        'angle_min': -180.0 * math.pi / 180.0,
        'angle_max': 180.0 * math.pi / 180.0,
        'range_min': 0.1,
        'range_max': maxRange,
      });
      
      if (kDebugMode) {
        final validCount = ranges.where((r) => r < maxRange).length;
        _log('📡 Velodyne: $totalPoints pts → $validCount valid ranges', level: 'DEBUG');
      }
    } catch (e) {
      if (kDebugMode) {
        _log('❌ Error processing Velodyne PointCloud2: $e', level: 'ERROR');
      }
    }
  }

  void _handleSteeringAngleData(Map<String, dynamic> msg) {
    final steeringAngle = (msg['data'] as num).toDouble();
    _safeAdd<double>(_steeringAngleController, steeringAngle);
    if (kDebugMode) {
      _log(
        '🎯 Steering Angle: ${steeringAngle.toStringAsFixed(2)}°',
        level: 'DEBUG',
      );
    }
  }

  void _handleCrossTrackErrorData(Map<String, dynamic> msg) {
    final cte = (msg['data'] as num).toDouble();
    _safeAdd<double>(_crossTrackErrorController, cte);
  }

  void _handleCbfValueData(Map<String, dynamic> msg) {
    final v = (msg['data'] as num).toDouble();
    _safeAdd<double>(_cbfValueController, v);
  }

  void _handleBoundaryDistanceData(Map<String, dynamic> msg) {
    final v = (msg['data'] as num).toDouble();
    _safeAdd<double>(_boundaryDistanceController, v);
  }

  void _handleCbfCorrectionData(Map<String, dynamic> msg) {
    final v = (msg['data'] as num).toDouble();
    _safeAdd<double>(_cbfCorrectionController, v);
  }

  void _handleCbfActiveData(Map<String, dynamic> msg) {
    final v = (msg['data'] as num).toDouble();
    _safeAdd<bool>(_cbfActiveController, v != 0);
  }

  void _handleHeadingErrorData(Map<String, dynamic> msg) {
    final v = (msg['data'] as num).toDouble();
    _safeAdd<double>(_headingErrorController, v);
  }

  void _handleTotalErrorData(Map<String, dynamic> msg) {
    final v = (msg['data'] as num).toDouble();
    _safeAdd<double>(_totalErrorController, v);
  }

  void _handleObstacleDistanceData(Map<String, dynamic> msg) {
    final v = (msg['data'] as num).toDouble();
    _safeAdd<double>(_obstacleDistanceController, v);
  }

  void _handleObstaclePositionData(Map<String, dynamic> msg) {
    final v = (msg['data'] as String? ?? '');
    _safeAdd<String>(_obstaclePositionController, v);
  }

  void _handleWaypointIndexData(Map<String, dynamic> msg) {
    final v = (msg['data'] as num).toDouble();
    _safeAdd<double>(_waypointIndexController, v);
  }

  // Publish speed to ROS as km/h
  void _publishSpeedometerToRos(double speedKmh) {
    _sendMessage({
      'op': 'publish',
      'topic': '/speedometer',
      'msg': {'data': speedKmh},
    });
  }

  // Legacy calibration utilities - disabled since we use /velocity topic
  /*
  Future<void> calibrateImuBias({int seconds = 8}) async {
    _log(
      '🔧 Calibrating IMU bias for ${seconds}s (assume stationary)...',
      level: 'INFO',
    );
    final samples = <double>[];
    final start = DateTime.now();
    while (DateTime.now().difference(start).inSeconds < seconds) {
      samples.add((_currentImu['acceleration_x'] ?? 0.0));
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (samples.isNotEmpty) {
      final avg = samples.reduce((a, b) => a + b) / samples.length;
      _imuBias = avg.clamp(-0.3, 0.3);
      _imuVelocityMs = 0.0;
      _imuVariance = 0.05;
      _log(
        '✅ IMU bias set to ${_imuBias.toStringAsFixed(6)} m/s²',
        level: 'INFO',
      );
    }
  }

  void resetImuIntegration() {
    _imuVelocityMs = 0.0;
    _imuBias = 0.0;
    _imuVariance = 0.1;
    _fusedVelocityMs = 0.0;
    _velocityVariance = 1.0;
    _lastImuUpdate = null;
    // Note: _lastGpsUpdate removed since we use /linear topic
    _log('🔄 IMU integration reset completed (using /linear for speed)', level: 'INFO');
  }
  */

  // Publish destination coordinates to ROS
  void publishDestinationCoordinates(double latitude, double longitude) {
    // Send as JSON string for cbf_navigation_ros.py compatibility
    final jsonData = jsonEncode({'x': longitude, 'y': latitude, 'z': 0.0});
    _sendMessage({
      'op': 'publish',
      'topic': '/destination_coordinate',
      'msg': {'data': jsonData},
    });

    // Also publish as separate Float64 topics for simple navigation simulator
    _sendMessage({
      'op': 'publish',
      'topic': '/destination_lat',
      'msg': {'data': latitude},
    });
    _sendMessage({
      'op': 'publish',
      'topic': '/destination_lon',
      'msg': {'data': longitude},
    });

    _log(
      '📍 Published destination: (${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)})',
      level: 'INFO',
    );
  }

  // Publish waypoints array to ROS as JSON string
  void publishWaypoints(List<Map<String, dynamic>> waypoints) {
    if (!_isConnected) {
      _log('❌ Cannot publish waypoints: Not connected to ROS', level: 'ERROR');
      return;
    }

    final waypointsData = {
      'waypoints': waypoints,
      'total_count': waypoints.length,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    final jsonData = jsonEncode(waypointsData);

    // Send as JSON string for cbf_navigation_ros.py compatibility
    _sendMessage({
      'op': 'publish',
      'topic': '/waypoints_array',
      'msg': {'data': jsonData},
    });

    _log('🗺️ Published ${waypoints.length} waypoints to ROS', level: 'INFO');
    _log(
      '📤 Waypoints JSON: ${jsonData.substring(0, jsonData.length > 200 ? 200 : jsonData.length)}...',
      level: 'DEBUG',
    );
  }

  // Publish complete trip data to ROS as JSON string
  void publishTripData(Map<String, dynamic> tripJson) {
    if (!_isConnected) {
      _log('❌ Cannot publish trip data: Not connected to ROS', level: 'ERROR');
      return;
    }

    final jsonData = jsonEncode(tripJson);

    // Send as JSON string for cbf_navigation_ros.py compatibility
    _sendMessage({
      'op': 'publish',
      'topic': '/trip_data',
      'msg': {'data': jsonData},
    });

    _log(
      '🚗 Published trip data: ${tripJson['mission_name']} (${tripJson['total_waypoints']} waypoints)',
      level: 'INFO',
    );
    _log('📤 Trip JSON length: ${jsonData.length} bytes', level: 'DEBUG');
  }

  // Publish navigation command to ROS (start, stop, pause, resume)
  void publishNavigationCommand(String command) {
    if (!_isConnected) {
      _log('❌ Cannot publish command: Not connected to ROS', level: 'ERROR');
      return;
    }

    _sendMessage({
      'op': 'publish',
      'topic': '/navigation_command',
      'msg': {'data': command},
    });
    _log('🎮 Published navigation command: $command', level: 'INFO');
  }

  /// Disconnect from ROS Bridge
  /// Clean disconnect without auto-reconnect
  void disconnect() {
    _log('🔌 Disconnecting from ROS Bridge...', level: 'INFO');

    // Cancel any pending reconnection
    _reconnectTimer?.cancel();

    // Close existing connection
    if (_channel != null) {
      try {
        _channel!.sink.close();
      } catch (e) {
        _log('⚠️ Error closing connection: $e', level: 'WARNING');
      }
      _channel = null;
    }

    _isConnected = false;
    _subscribedTopics.clear();
    _safeAdd<bool>(_connectionController, false);

    _log('✅ Disconnected from ROS Bridge', level: 'INFO');
  }

  /// Reconnect to ROS Bridge with a new URL
  /// Used when switching between Live/Rosbag/Simulation modes
  Future<void> reconnect(String newUrl) async {
    // Avoid multiple reconnection attempts at once
    if (_isReconnecting) {
      _log('⏳ Reconnection already in progress, skipping...', level: 'WARNING');
      return;
    }

    _isReconnecting = true;
    _log('🔄 Reconnecting to new URL: $newUrl', level: 'INFO');

    try {
      // Cancel any pending reconnection
      _reconnectTimer?.cancel();

      // Close existing connection gracefully
      if (_channel != null) {
        try {
          await _channel!.sink.close().timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              _log('⏱️ Timeout closing old connection', level: 'WARNING');
            },
          );
        } catch (e) {
          _log('⚠️ Error closing old connection: $e', level: 'WARNING');
        }
        _channel = null;
      }

      _isConnected = false;
      _subscribedTopics.clear();
      _safeAdd<bool>(_connectionController, false);

      // Small delay to ensure clean disconnection
      await Future.delayed(const Duration(milliseconds: 500));

      // Update URL and reconnect
      _rosBridgeUrl = newUrl;
      await _connectToRosBridge();
    } finally {
      _isReconnecting = false;
    }
  }

  // Flag to prevent multiple simultaneous reconnection attempts
  bool _isReconnecting = false;

  /// Get current connection URL
  String get currentUrl => _rosBridgeUrl;

  // Dispose method for cleanup
  Future<void> dispose() async {
    _reconnectTimer?.cancel();
    await _channel?.sink.close();

    // Close all stream controllers
    await _speedometerController.close();
    await _speedometerRosController.close();
    await _ultrasonicController.close();
    await _gpsController.close();
    await _lidarController.close();
    await _lidarSummaryController.close();
    await _imuController.close();
    await _connectionController.close();
    await _linearVelocityController.close();
    await _steeringAngleController.close();
    await _crossTrackErrorController.close();
    await _cbfValueController.close();
    await _boundaryDistanceController.close();
    await _cbfCorrectionController.close();
    await _cbfActiveController.close();
    await _headingErrorController.close();
    await _totalErrorController.close();
    await _obstacleDistanceController.close();
    await _obstaclePositionController.close();
    await _waypointIndexController.close();
    await _witmotionYawController.close();
    await _witmotionAccelerationController.close();
    await _witmotionAngularVelocityController.close();

    _isConnected = false;
    _log('🛑 RosService disposed', level: 'INFO');
  }

  // Logging
  void _log(String message, {String level = 'INFO'}) {
    developer.log(message, name: 'RosService/$level');
    if (level == 'ERROR') {
      LoggingService.error(message, component: 'RosService');
    } else if (level == 'WARNING') {
      LoggingService.warning(message, component: 'RosService');
    } else if (level == 'DEBUG') {
      LoggingService.debug(message, component: 'RosService');
    } else {
      LoggingService.info(message, component: 'RosService');
    }
  }
}
