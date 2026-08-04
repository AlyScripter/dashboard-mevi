import 'package:flutter/material.dart';
import 'widgets/videostream.dart';
import 'widgets/zed_camera_stream_widget.dart';
import 'package:dashboardmevi/services/data_source_service.dart';

/// Camera Page - Displays camera stream
///
/// Supports 2 sources:
/// - ROS: ZedCameraStreamWidget for ROS MJPEG stream (web_video_server)
/// - USB: LocalUvcWidget for physical USB camera
class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final DataSourceService _dataSourceService = DataSourceService();
  bool _useRosStream = true; // Toggle between USB camera and ROS stream

  @override
  void initState() {
    super.initState();
    _dataSourceService.addListener(_onDataSourceChanged);
  }

  @override
  void dispose() {
    _dataSourceService.removeListener(_onDataSourceChanged);
    super.dispose();
  }

  void _onDataSourceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          padding: const EdgeInsets.all(7.0),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(255, 255, 255, 255)
                    .withValues(alpha: 0.5),
                spreadRadius: 2,
                blurRadius: 30,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: _buildCameraContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraContent() {
    // Check if in live mode to show source toggle
    final showSourceToggle = _dataSourceService.mode == DataSourceMode.live;
    
    // Both live and rosbag mode use ZedCameraStreamWidget
    // web_video_server handles streaming from rosbag camera topics
    if (_useRosStream) {
      return ZedCameraStreamWidget(
        fit: BoxFit.cover,  // Fullscreen tanpa black bars
        rosImageTopic: '/zed2i/zed_node/left/image_rect_color',
        streamUrl: 'http://localhost:8080/stream?topic=/zed2i/zed_node/left/image_rect_color&type=mjpeg',
        showSourceToggle: showSourceToggle,
        isRosSource: true,
        onSourceChanged: (isRos) => setState(() => _useRosStream = isRos),
      );
    }

    // Fallback: USB camera
    return LocalUvcWidget(
      fit: BoxFit.cover,  // Fullscreen tanpa black bars
      showControls: true,
      defaultCropLeft: true,
      showSourceToggle: showSourceToggle,
      onSourceChanged: (isRos) => setState(() => _useRosStream = isRos),
    );
  }
}
