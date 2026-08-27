import 'package:flutter/material.dart';
import 'widgets/videostream.dart';
import 'widgets/zed_camera_stream_widget.dart';
import 'package:dashboardmevi/services/data_source_service.dart';
import 'package:dashboardmevi/core/theme/colors.dart';

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

  // REVISI: radius outer frame & inner clip disatukan di sini sebagai satu
  // sumber kebenaran, lalu diteruskan ke ZedCameraStreamWidget/LocalUvcWidget
  // (parameter `borderRadius`) supaya border biru di dalam widget kamera
  // memakai radius yang PERSIS SAMA dengan ClipRRect di luar. Sebelumnya
  // outer clip pakai 23 sementara border widget kamera hardcoded 12 —
  // beda radius inilah yang membuat outline biru terlihat "putus"/tidak
  // menyesuaikan sudut, karena dua lengkungan berbeda ditumpuk.
  static const double _outerRadius = 30;
  static const double _innerRadius = 23;

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
            // REVISI: dulu `color: Colors.black` + boxShadow PUTIH —
            // sekarang gradient navy gelap yang sama dengan panel kiri,
            // dan bingkai luarnya dikasih border biru neon juga (bukan
            // cuma widget kamera di dalamnya), supaya seluruh frame kamera
            // (luar + dalam) senada "glass hitam-biru".
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF12161F), Color(0xFF0A0D13)],
            ),
            borderRadius: BorderRadius.circular(_outerRadius),
            border: Border.all(
              color: AppColors.glassBlueBorder.withValues(alpha: 0.85),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.glassBlueGlow.withValues(alpha: 0.18),
                spreadRadius: 1,
                blurRadius: 24,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_innerRadius),
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
        fit: BoxFit.cover, // Fullscreen tanpa black bars
        rosImageTopic: '/zed2i/zed_node/left/image_rect_color',
        streamUrl:
            'http://localhost:8080/stream?topic=/zed2i/zed_node/left/image_rect_color&type=mjpeg',
        showSourceToggle: showSourceToggle,
        isRosSource: true,
        onSourceChanged: (isRos) => setState(() => _useRosStream = isRos),
        // REVISI: radius disamakan dengan ClipRRect di atas, dan border
        // milik widget ini dimatikan (outer frame sudah punya border biru
        // sendiri) supaya tidak dobel border dengan radius berbeda.
        borderRadius: _innerRadius,
        showOwnBorder: false,
      );
    }

    // Fallback: USB camera
    return LocalUvcWidget(
      fit: BoxFit.cover, // Fullscreen tanpa black bars
      showControls: true,
      defaultCropLeft: true,
      showSourceToggle: showSourceToggle,
      onSourceChanged: (isRos) => setState(() => _useRosStream = isRos),
      borderRadius: _innerRadius,
      showOwnBorder: false,
    );
  }
}
