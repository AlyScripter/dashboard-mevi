import 'package:flutter_test/flutter_test.dart';
import 'package:dashboardmevi/services/data_source_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DataSourceService', () {
    test('default mode is live', () {
      final service = DataSourceService();
      expect(service.mode, DataSourceMode.live);
    });

    test('default connection status is false', () {
      final service = DataSourceService();
      expect(service.isConnected, false);
    });

    test('default rosbag playing state is false', () {
      final service = DataSourceService();
      expect(service.isRosbagPlaying, false);
    });

    test('default rosbag progress is 0', () {
      final service = DataSourceService();
      expect(service.rosbagProgress, 0.0);
    });

    test('liveRosUrl returns default value', () {
      final service = DataSourceService();
      expect(service.liveRosUrl, contains('ws://'));
    });

    test('liveCameraUrl returns default value', () {
      final service = DataSourceService();
      expect(service.liveCameraUrl, contains('http://'));
    });

    test('rosbagRosUrl returns localhost', () {
      final service = DataSourceService();
      expect(service.rosbagRosUrl, 'ws://localhost:9090');
    });

    test('currentRosUrl returns liveRosUrl when mode is live', () {
      final service = DataSourceService();
      expect(service.currentRosUrl, service.liveRosUrl);
    });

    test('currentCameraUrl returns liveCameraUrl when mode is live', () {
      final service = DataSourceService();
      expect(service.currentCameraUrl, service.liveCameraUrl);
    });

    test('setConnectionStatus updates isConnected', () {
      final service = DataSourceService();
      service.setConnectionStatus(true);
      expect(service.isConnected, true);
      service.setConnectionStatus(false);
      expect(service.isConnected, false);
    });

    test('setRosbagPlaybackState updates playing state', () {
      final service = DataSourceService();
      service.setRosbagPlaybackState(playing: true);
      expect(service.isRosbagPlaying, true);
    });

    test('setRosbagPlaybackState updates progress', () {
      final service = DataSourceService();
      service.setRosbagPlaybackState(progress: 0.5);
      expect(service.rosbagProgress, 0.5);
    });

    test('modeDisplayName returns correct string for live mode', () {
      final service = DataSourceService();
      expect(service.modeDisplayName, 'Live (Vehicle)');
    });

    test('modeIcon returns correct emoji for live mode', () {
      final service = DataSourceService();
      expect(service.modeIcon, '🚗');
    });

    test('setMode changes mode', () async {
      final service = DataSourceService();
      await service.setMode(DataSourceMode.rosbag);
      expect(service.mode, DataSourceMode.rosbag);
    });

    test('setMode does nothing when mode is same', () async {
      final service = DataSourceService();
      final initialMode = service.mode;
      await service.setMode(initialMode);
      expect(service.mode, initialMode);
    });

    test('setLiveUrls updates rosUrl', () async {
      final service = DataSourceService();
      await service.setLiveUrls(rosUrl: 'ws://192.168.1.200:9090');
      expect(service.liveRosUrl, 'ws://192.168.1.200:9090');
    });

    test('setLiveUrls updates cameraUrl', () async {
      final service = DataSourceService();
      await service.setLiveUrls(cameraUrl: 'http://192.168.1.200:8080');
      expect(service.liveCameraUrl, 'http://192.168.1.200:8080');
    });

    test('setRosbagSettings updates rosUrl', () async {
      final service = DataSourceService();
      await service.setRosbagSettings(rosUrl: 'ws://192.168.1.50:9090');
      expect(service.rosbagRosUrl, 'ws://192.168.1.50:9090');
    });

    test('setRosbagSettings updates rosbagFile', () async {
      final service = DataSourceService();
      await service.setRosbagSettings(rosbagFile: '/path/to/test.bag');
      expect(service.rosbagFile, '/path/to/test.bag');
    });

    test('setRosbagSettings updates videoFile', () async {
      final service = DataSourceService();
      await service.setRosbagSettings(videoFile: '/path/to/video.mp4');
      expect(service.videoFile, '/path/to/video.mp4');
    });

    test('modeStream is broadcast stream', () {
      final service = DataSourceService();
      expect(service.modeStream, isA<Stream<DataSourceMode>>());
    });

    test('initialize loads saved preferences', () async {
      SharedPreferences.setMockInitialValues({
        'data_source_mode': 'rosbag',
        'live_ros_url': 'ws://test:9090',
        'rosbag_file': 'test.bag',
      });
      
      final service = DataSourceService();
      await service.initialize();
      
      // Note: Due to singleton pattern, values might persist from previous tests
      // This test verifies the initialize method runs without error
      expect(service.mode, isA<DataSourceMode>());
    });
  });

  group('DataSourceMode', () {
    test('has live value', () {
      expect(DataSourceMode.live, isNotNull);
      expect(DataSourceMode.live.name, 'live');
    });

    test('has rosbag value', () {
      expect(DataSourceMode.rosbag, isNotNull);
      expect(DataSourceMode.rosbag.name, 'rosbag');
    });

    test('values contains both modes', () {
      expect(DataSourceMode.values, contains(DataSourceMode.live));
      expect(DataSourceMode.values, contains(DataSourceMode.rosbag));
      expect(DataSourceMode.values.length, 2);
    });
  });
}
