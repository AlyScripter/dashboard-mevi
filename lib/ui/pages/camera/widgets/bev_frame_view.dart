import 'package:flutter/material.dart';
import 'package:dashboardmevi/services/ros_service.dart';

/// BEV/SDC view — Tahap 6a proof-of-concept.
///
/// Dipasang di slot "kamera" (CameraPage) saat dropdown tipe kamera
/// diganti ke 'BEV/SDC'. Belum ada rendering point cloud/kubus 3D —
/// itu Tahap 6b. Untuk sekarang, widget ini cuma membuktikan jalur
/// ROS → Dart sudah beres: JSON di topic `/bev/frame` (hasil Fase 4/5,
/// republish oleh node Python) berhasil di-decode oleh [RosService] dan
/// jumlah titik occupancy + jumlah objek terklasifikasi ditampilkan
/// live, menggantikan frame RGB tanpa mengubah jalur ROS/rosbridge yang
/// sudah ada.
///
/// Kalau belum ada pesan masuk sama sekali di `/bev/frame`, widget ini
/// menampilkan state "No signal" — konsisten dengan tampilan slot
/// kamera lain (RGB/Depth/Segmentation) saat stream belum aktif.
class BevFrameView extends StatelessWidget {
  final double borderRadius;

  const BevFrameView({super.key, this.borderRadius = 23});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF0A0D13),
      alignment: Alignment.center,
      child: StreamBuilder<Map<String, dynamic>>(
        stream: RosService().bevFrameStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return _buildNoSignal();
          }
          return _buildFrameSummary(snapshot.data!);
        },
      ),
    );
  }

  Widget _buildNoSignal() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.videocam_off_rounded, color: Colors.blue.shade300, size: 40),
        const SizedBox(height: 12),
        const Text(
          'No signal',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          'Menunggu topic /bev/frame...',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildFrameSummary(Map<String, dynamic> f) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.grid_view_rounded,
            color: Color(0xFF4FC3F7),
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            'BEV/SDC — frame_idx ${f['frame_idx']}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            't=${f['t']}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'titik: ${f['point_count']}   objek: ${f['object_count']}',
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 14,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '(Tahap 6a: proof-of-concept — belum render point cloud)',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
