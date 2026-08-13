// lib/ui/core/widgets/dashboard/birdeye_overlay_widget.dart
//
// FIX: BackdropFilter tidak boleh ikut dianimasikan lewat ScaleTransition /
// AnimatedSwitcher (widget-nya di-destroy & dibuat ulang tiap transisi),
// itu penyebab crash "'debugNeedsLayout': is not true".
// Solusi: widget kaca tetap hidup terus di render tree, yang berubah
// cuma opacity-nya (AnimatedOpacity) + IgnorePointer saat tidak aktif.

import 'package:flutter/material.dart';
import '../../../../services/ros_service.dart';
import '../../../pages/data/widgets/sensors/enhanced_lidar_visualization.dart';
import '../../../../core/theme/glass_container.dart';

class BirdEyeOverlayWidget extends StatelessWidget {
  final bool active;

  const BirdEyeOverlayWidget({super.key, this.active = false});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !active,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        opacity: active ? 1.0 : 0.0,
        // Widget kaca (BackdropFilter) SELALU dibangun, tidak pernah
        // di-swap dengan SizedBox.shrink() supaya RenderObject-nya stabil.
        child: _buildPanel(),
      ),
    );
  }

  Widget _buildPanel() {
    return GlassContainer(
      width: 320,
      height: 320,
      borderRadius: 28,
      // GlassContainer punya "variant" secara implisit lewat `tint`:
      // tint hitam = varian gelap, tint putih = varian terang.
      tint: Colors.black,
      tintOpacity: 0.35,
      blurSigma: 22,
      padding: const EdgeInsets.all(10),
      child: StreamBuilder<List<double>>(
        stream: RosService().lidarStream,
        builder: (context, snapshot) {
          final ranges = snapshot.data ?? const <double>[];

          if (ranges.isEmpty) {
            return const Center(
              child: Text(
                'Menunggu data LiDAR…',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            );
          }

          return EnhancedLidarVisualization(
            ranges: ranges,
            mode: LidarVisualizationMode.birdEye,
          );
        },
      ),
    );
  }
}
