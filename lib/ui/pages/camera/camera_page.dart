import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
  bool _useRosStream = true;

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
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    // Card styles matching DataPage / LidarBevPage
    final cardBg = isLight ? Colors.white : AppColors.glassNavyTint;
    final cardBorder = isLight
        ? const Color(0xFFE2E8F0)
        : AppColors.glassBlueBorder.withValues(alpha: 0.65);
    final cardShadow = isLight
        ? const Color(0x0A0F172A)
        : Colors.black.withValues(alpha: 0.35);

    // Frame styling matching DataPage ChartContainer / LidarBevPage
    final frameBg = isLight ? Colors.white : AppColors.glassSurface;
    final frameBorder = isLight
        ? const Color(0xFFE2E8F0)
        : AppColors.glassBlueBorder.withValues(alpha: 0.45);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          color: isLight ? const Color(0xFFF8FAFC) : null,
          gradient: isLight
              ? null
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF12161F), Color(0xFF0A0D13)],
                ),
        ),
        padding: const EdgeInsets.only(left: 12, right: 12, top: 10, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── TOP BAR: Judul halaman bergaya Card LiDAR 3D BEV ────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder, width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: cardShadow,
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isLight
                                ? const Color(0xFFEFF6FF)
                                : const Color(0x1A7DB4FF),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            LucideIcons.camera,
                            size: 19,
                            color: isLight
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF7DB4FF),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'RGB Camera',
                              style: TextStyle(
                                fontSize: 14.0,
                                height: 1.15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                color: isLight
                                    ? const Color(0xFF0F172A)
                                    : AppColors.glassTextPrimary,
                              ),
                            ),
                            Text(
                              'Camera Vision',
                              style: TextStyle(
                                fontSize: 10.5,
                                height: 1.15,
                                fontWeight: FontWeight.w500,
                                color: isLight
                                    ? const Color(0xFF64748B)
                                    : AppColors.glassTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── CAMERA FRAME ───────────────────────────────────────────────
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(5.0),
                decoration: BoxDecoration(
                  color: frameBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: frameBorder, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: cardShadow,
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _buildCameraContent(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraContent() {
    final showSourceToggle = _dataSourceService.mode == DataSourceMode.live;

    // Depth & Segmentation belum ada aksi — fallback ke stream RGB yang
    // sama untuk sekarang (placeholder, sama seperti perilaku sebelumnya).

    if (_useRosStream) {
      return ZedCameraStreamWidget(
        fit: BoxFit.cover,
        rosImageTopic: '/zed2i/zed_node/left/image_rect_color',
        streamUrl:
            'http://localhost:8080/stream?topic=/zed2i/zed_node/left/image_rect_color&type=mjpeg',
        showSourceToggle: showSourceToggle,
        isRosSource: true,
        onSourceChanged: (isRos) => setState(() => _useRosStream = isRos),
        borderRadius: 14,
        showOwnBorder: false,
      );
    }

    return LocalUvcWidget(
      fit: BoxFit.cover,
      showControls: true,
      defaultCropLeft: true,
      showSourceToggle: showSourceToggle,
      onSourceChanged: (isRos) => setState(() => _useRosStream = isRos),
      borderRadius: 14,
      showOwnBorder: false,
    );
  }
}
