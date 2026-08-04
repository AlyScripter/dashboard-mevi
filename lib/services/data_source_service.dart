import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Data source modes for the dashboard
enum DataSourceMode {
  /// Live data from vehicle (Jetson AGX Xavier)
  live,
  
  /// Rosbag playback for testing
  rosbag,
}

/// Service to manage data source switching
/// Allows switching between live vehicle data and rosbag playback
class DataSourceService extends ChangeNotifier {
  static final DataSourceService _instance = DataSourceService._internal();
  factory DataSourceService() => _instance;
  DataSourceService._internal();

  // Current data source mode
  DataSourceMode _mode = DataSourceMode.live;
  DataSourceMode get mode => _mode;

  // Connection status
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // Rosbag playback state
  bool _isRosbagPlaying = false;
  bool get isRosbagPlaying => _isRosbagPlaying;
  
  double _rosbagProgress = 0.0;
  double get rosbagProgress => _rosbagProgress;

  String _rosbagFile = '';
  String get rosbagFile => _rosbagFile;

  // Video file for camera playback (when using rosbag mode)
  String _videoFile = '';
  String get videoFile => _videoFile;

  // Stream controllers for mode changes
  final _modeController = StreamController<DataSourceMode>.broadcast();
  Stream<DataSourceMode> get modeStream => _modeController.stream;

  // URLs for different modes
  // Jetson IP for ROS Bridge (vehicle data, navigation)
  String _liveRosUrl = 'ws://192.168.1.100:9090';
  // Camera IP for web_video_server (ZED 2i from laptop)
  String _liveCameraUrl = 'http://192.168.1.100:8080/video_feed';
  // Separate IP storage for camera (allows camera on different device than ROS)
  String _liveCameraIp = '192.168.1.100';
  String _rosbagRosUrl = 'ws://localhost:9090';
  
  String get liveRosUrl => _liveRosUrl;
  String get liveCameraUrl => _liveCameraUrl;
  String get liveCameraIp => _liveCameraIp;
  String get rosbagRosUrl => _rosbagRosUrl;

  // Get current ROS URL based on mode
  String get currentRosUrl {
    switch (_mode) {
      case DataSourceMode.live:
        return _liveRosUrl;
      case DataSourceMode.rosbag:
        return _rosbagRosUrl;
    }
  }

  // Get current camera URL based on mode
  String? get currentCameraUrl {
    switch (_mode) {
      case DataSourceMode.live:
        return _liveCameraUrl;
      case DataSourceMode.rosbag:
        return null; // Use local video file
    }
  }

  /// Initialize service and load saved preferences
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load saved mode
    final savedMode = prefs.getString('data_source_mode');
    if (savedMode != null) {
      _mode = DataSourceMode.values.firstWhere(
        (e) => e.name == savedMode,
        orElse: () => DataSourceMode.live,
      );
    }

    // Load saved URLs
    _liveRosUrl = prefs.getString('live_ros_url') ?? _liveRosUrl;
    _liveCameraUrl = prefs.getString('live_camera_url') ?? _liveCameraUrl;
    _liveCameraIp = prefs.getString('live_camera_ip') ?? _liveCameraIp;
    _rosbagRosUrl = prefs.getString('rosbag_ros_url') ?? _rosbagRosUrl;
    _rosbagFile = prefs.getString('rosbag_file') ?? '';
    _videoFile = prefs.getString('video_file') ?? '';

    notifyListeners();
  }

  /// Save current settings to preferences
  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('data_source_mode', _mode.name);
    await prefs.setString('live_ros_url', _liveRosUrl);
    await prefs.setString('live_camera_url', _liveCameraUrl);
    await prefs.setString('live_camera_ip', _liveCameraIp);
    await prefs.setString('rosbag_ros_url', _rosbagRosUrl);
    await prefs.setString('rosbag_file', _rosbagFile);
    await prefs.setString('video_file', _videoFile);
  }

  /// Switch data source mode
  Future<void> setMode(DataSourceMode newMode) async {
    if (_mode == newMode) return;
    
    _mode = newMode;
    _modeController.add(newMode);
    await _savePreferences();
    notifyListeners();
  }

  /// Update live connection URLs
  /// - rosUrl: WebSocket URL for Jetson ROS Bridge (e.g., ws://192.168.1.101:9090)
  /// - cameraUrl: HTTP URL for camera stream (auto-generated from cameraIp)
  /// - cameraIp: IP address for camera web_video_server (e.g., 192.168.1.100)
  Future<void> setLiveUrls({String? rosUrl, String? cameraUrl, String? cameraIp}) async {
    if (rosUrl != null) _liveRosUrl = rosUrl;
    if (cameraUrl != null) _liveCameraUrl = cameraUrl;
    if (cameraIp != null) {
      _liveCameraIp = cameraIp;
      // Auto-generate camera URL from IP
      _liveCameraUrl = 'http://$cameraIp:8080/video_feed';
    }
    await _savePreferences();
    notifyListeners();
  }

  /// Update rosbag settings
  Future<void> setRosbagSettings({
    String? rosUrl,
    String? rosbagFile,
    String? videoFile,
  }) async {
    if (rosUrl != null) _rosbagRosUrl = rosUrl;
    if (rosbagFile != null) _rosbagFile = rosbagFile;
    if (videoFile != null) _videoFile = videoFile;
    await _savePreferences();
    notifyListeners();
  }

  /// Set connection status
  void setConnectionStatus(bool connected) {
    _isConnected = connected;
    notifyListeners();
  }

  /// Set rosbag playback state
  void setRosbagPlaybackState({bool? playing, double? progress}) {
    if (playing != null) _isRosbagPlaying = playing;
    if (progress != null) _rosbagProgress = progress;
    notifyListeners();
  }

  /// Get display name for current mode
  String get modeDisplayName {
    switch (_mode) {
      case DataSourceMode.live:
        return 'Live (Vehicle)';
      case DataSourceMode.rosbag:
        return 'Rosbag Playback';
    }
  }

  /// Get icon for current mode
  String get modeIcon {
    switch (_mode) {
      case DataSourceMode.live:
        return '🚗';
      case DataSourceMode.rosbag:
        return '📼';
    }
  }

  @override
  void dispose() {
    _modeController.close();
    super.dispose();
  }
}
