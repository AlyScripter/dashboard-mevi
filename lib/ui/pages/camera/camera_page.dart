import 'package:flutter/material.dart';
import 'widgets/videostream.dart';
import 'widgets/zed_camera_stream_widget.dart';
import 'widgets/bev_frame_view.dart';
import 'widgets/bev_point_cloud_view.dart';
import 'package:dashboardmevi/services/data_source_service.dart';
import 'package:dashboardmevi/core/theme/colors.dart';

/// Camera Page - Displays camera stream
///
/// Supports 2 sources:
/// - ROS: ZedCameraStreamWidget for ROS MJPEG stream (web_video_server)
/// - USB: LocalUvcWidget for physical USB camera
///
/// REVISI:
/// 1. Light/dark theme-aware.
/// 2. WeatherTimeWidget TIDAK dipanggil di sini — sudah ditangani oleh
///    dashboard_layout.dart via _buildTopOverlay() yang selalu muncul
///    sebagai Stack overlay di atas semua halaman. Memanggil lagi di sini
///    menyebabkan widget muncul 2x.
/// 3. Dropdown pilihan tipe kamera (RGB/Depth/Segmentation/BEV·SDC) di
///    kiri atas.
///    - RGB: tetap ZED ROS stream / USB (seperti sebelumnya).
///    - BEV/SDC: Tahap 6b — slot frame diganti [BevPointCloudView],
///      yang subscribe ke RosService().bevFrameStream (topic
///      /bev/frame) dan me-render point cloud LiDAR beneran pakai
///      flutter_cube (downsample + reuse buffer, lihat komentar di
///      file itu). [BevFrameView] (Tahap 6a, ringkasan angka doang)
///      masih ada di project sebagai fallback kalau BevPointCloudView
///      kena masalah compile/performa di device kamu — tinggal ganti
///      baris di bawah balik ke `BevFrameView(...)`.
///    - Depth/Segmentation: belum ada aksi (placeholder di masa depan).
class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final DataSourceService _dataSourceService = DataSourceService();
  bool _useRosStream = true;

  // Dropdown state — hanya UI, belum ada aksi
  String _selectedCameraType = 'RGB';
  static const List<String> _cameraTypes = [
    'RGB',
    'Depth',
    'Segmentation',
    'BEV/SDC',
  ];

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
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    // --- THEME-AWARE COLORS ---
    final outerBgColors = isLight
        ? [const Color(0xFFF0F4FA), const Color(0xFFE4EAF5)]
        : [const Color(0xFF12161F), const Color(0xFF0A0D13)];
    final outerBorderColor = isLight
        ? AppColors.primary.withValues(alpha: 0.30)
        : AppColors.glassBlueBorder.withValues(alpha: 0.85);
    final outerGlowColor = isLight
        ? AppColors.primary.withValues(alpha: 0.08)
        : AppColors.glassBlueGlow.withValues(alpha: 0.18);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── TOP BAR: hanya dropdown kiri ──────────────────────────────
            // WeatherTimeWidget TIDAK ada di sini — sudah dirender oleh
            // dashboard_layout.dart sebagai Positioned overlay di Stack
            // utama. Menambahkan lagi di sini akan menampilkan 2 widget.
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, left: 4, right: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Dropdown tipe kamera (hanya UI, belum ada aksi)
                  _CameraTypeDropdown(
                    value: _selectedCameraType,
                    items: _cameraTypes,
                    isLight: isLight,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCameraType = val);
                      }
                    },
                  ),
                  // Spacer sengaja tidak diisi weather widget
                ],
              ),
            ),

            // ── CAMERA FRAME ───────────────────────────────────────────────
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(7.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: outerBgColors,
                  ),
                  borderRadius: BorderRadius.circular(_outerRadius),
                  border: Border.all(color: outerBorderColor, width: 1.6),
                  boxShadow: [
                    BoxShadow(
                      color: outerGlowColor,
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
          ],
        ),
      ),
    );
  }

  Widget _buildCameraContent() {
    final showSourceToggle = _dataSourceService.mode == DataSourceMode.live;

    // Tahap 6b: dropdown BEV/SDC gantiin frame kamera dengan point cloud
    // LiDAR beneran (proof-of-concept Tahap 6a ada di BevFrameView, masih
    // disimpan sebagai fallback).
    if (_selectedCameraType == 'BEV/SDC') {
      return const BevPointCloudView();
    }

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
        borderRadius: _innerRadius,
        showOwnBorder: false,
      );
    }

    return LocalUvcWidget(
      fit: BoxFit.cover,
      showControls: true,
      defaultCropLeft: true,
      showSourceToggle: showSourceToggle,
      onSourceChanged: (isRos) => setState(() => _useRosStream = isRos),
      borderRadius: _innerRadius,
      showOwnBorder: false,
    );
  }
}

// ── Dropdown widget ─────────────────────────────────────────────────────────
class _CameraTypeDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final bool isLight;
  final ValueChanged<String?> onChanged;

  const _CameraTypeDropdown({
    required this.value,
    required this.items,
    required this.isLight,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // REVISI: light mode dropdown memakai gradient PERSIS sama dengan nav rail
    // (0xFF1565C0 → 0xFF1976D2), border 0xFF1E88E5, teks & icon putih.
    // Dark mode tetap navy gelap seperti semula.
    final bgColor = isLight ? null : AppColors.glassNavyTint;
    final bgGradient = isLight
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
          )
        : null;
    final borderColor = isLight
        ? const Color(0xFF1E88E5)
        : AppColors.glassBlueBorder.withValues(alpha: 0.85);
    final textColor = isLight ? Colors.white : AppColors.glassTextPrimary;
    final iconColor = isLight ? Colors.white : const Color(0xFF7DB4FF);
    final shadowColor = isLight
        ? const Color(0xFF1565C0).withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.35);
    // Popup menu: biru nav juga, teks putih
    final dropdownBg = isLight
        ? const Color(0xFF1565C0)
        : const Color(0xFF10151F);
    final dropdownTextColor = isLight
        ? Colors.white
        : AppColors.glassTextPrimary;

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        gradient: bgGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: Icon(Icons.expand_more_rounded, size: 18, color: iconColor),
          dropdownColor: dropdownBg,
          style: TextStyle(
            color: dropdownTextColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          borderRadius: BorderRadius.circular(14),
          onChanged: onChanged,
          items: items.map((type) {
            return DropdownMenuItem<String>(
              value: type,
              child: Text(
                type,
                style: TextStyle(
                  color: dropdownTextColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
