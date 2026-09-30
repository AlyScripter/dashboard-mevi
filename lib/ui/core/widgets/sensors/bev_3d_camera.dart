import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Hasil proyeksi koordinat 3D ke 2D viewport layar.
class ProjectedPoint {
  final Offset screenOffset;
  final double depth; // Jarak Z kamera untuk sorting dan scaling
  final bool isVisible; // Di depan kamera dan dalam batas wajar

  const ProjectedPoint({
    required this.screenOffset,
    required this.depth,
    required this.isVisible,
  });
}

/// Engine proyeksi kamera perspektif 3D untuk BEV Autonomous Dashboard.
/// Dikonfigurasi dengan sudut pandang drone / elevated BEV yang sangat luas (seperti visual 9.jpg)
/// sehingga pemandangan jalan membentang luas dan objek di sekeliling tidak bertumpang tindih.
class Bev3DCamera {
  /// Ketinggian kamera dari permukaan jalan (meter)
  final double cameraHeight;

  /// Jarak kamera di belakang mobil ego (meter, nilai negatif)
  final double cameraDistance;

  /// Sudut kemiringan kamera ke bawah (derajat, 0 = lurus ke horizon, 90 = top-down)
  final double pitchDeg;

  /// Sudut yaw kamera (derajat, mengikuti belokan)
  final double yawDeg;

  /// Posisi horizon relatif terhadap tinggi viewport (0.32 = sepertiga atas viewport)
  final double horizonFraction;

  /// Faktor skala FOV lensa (nilai lebih rendah = bidang pandang lebih luas / panoramic wide BEV)
  final double fovScale;

  const Bev3DCamera({
    this.cameraHeight = 10.5,
    this.cameraDistance = -6.5,
    this.pitchDeg = 32.0,
    this.yawDeg = 0.0,
    this.horizonFraction = 0.52,
    this.fovScale = 0.88,
  });

  /// Melakukan proyeksi titik 3D (x, y, z) dunia ke koordinat piksel layar 2D (x_s, y_s).
  ProjectedPoint project(
    double x,
    double y,
    double z,
    Size viewportSize, {
    double lateralOffset = 0.0,
  }) {
    final cx = viewportSize.width / 2.0 + lateralOffset;
    final cy = viewportSize.height * horizonFraction;

    // Relatif terhadap posisi kamera
    final dx = x;
    final dy = y - cameraHeight;
    final dz = z - cameraDistance;

    // Konversi sudut ke radian
    final pitchRad = (pitchDeg * math.pi) / 180.0;
    final yawRad = (yawDeg * math.pi) / 180.0;

    // Rotasi Yaw (horizontal)
    final cosYaw = math.cos(yawRad);
    final sinYaw = math.sin(yawRad);
    final x1 = dx * cosYaw - dz * sinYaw;
    final z1 = dx * sinYaw + dz * cosYaw;

    // Rotasi Pitch (vertikal ke bawah untuk elevated drone BEV seperti visual 9.jpg)
    final cosPitch = math.cos(pitchRad);
    final sinPitch = math.sin(pitchRad);
    final y2 = dy * cosPitch + z1 * sinPitch;
    final z2 = z1 * cosPitch - dy * sinPitch;

    // Jika objek berada di belakang kamera / bidang kliping dekat
    if (z2 <= 0.20) {
      return ProjectedPoint(
        screenOffset: Offset(cx, viewportSize.height * 2),
        depth: z2,
        isVisible: false,
      );
    }

    // Proyeksi Perspektif
    final focal = (viewportSize.height * 0.90) * fovScale;
    final screenX = cx + (x1 / z2) * focal;
    final screenY = cy - (y2 / z2) * focal;

    final isVisible =
        z2 > 0.2 &&
        screenX >= -viewportSize.width * 0.8 &&
        screenX <= viewportSize.width * 1.8 &&
        screenY >= cy * 0.2 &&
        screenY <= viewportSize.height * 1.5;

    return ProjectedPoint(
      screenOffset: Offset(screenX, screenY),
      depth: z2,
      isVisible: isVisible,
    );
  }

  /// Menghitung proyeksi 8 titik sudut (vertices) untuk 3D Bounding Box.
  List<ProjectedPoint> projectBoundingBoxVertices({
    required double centerX,
    required double baseY,
    required double centerZ,
    required double width,
    required double height,
    required double length,
    double yawDeg = 0.0,
    required Size viewportSize,
  }) {
    final hw = width / 2.0;
    final hl = length / 2.0;
    final yawRad = (yawDeg * math.pi) / 180.0;
    final cosY = math.cos(yawRad);
    final sinY = math.sin(yawRad);

    // 8 Titik Lokal dalam meter
    final localPoints = [
      // Base (Y = baseY)
      Offset(-hw, hl), // 0: Front-Left
      Offset(hw, hl), // 1: Front-Right
      Offset(hw, -hl), // 2: Back-Right
      Offset(-hw, -hl), // 3: Back-Left
      // Top (Y = baseY + height)
      Offset(-hw, hl), // 4: Front-Left
      Offset(hw, hl), // 5: Front-Right
      Offset(hw, -hl), // 6: Back-Right
      Offset(-hw, -hl), // 7: Back-Left
    ];

    final projected = <ProjectedPoint>[];

    for (int i = 0; i < 8; i++) {
      final lp = localPoints[i];
      final rotX = lp.dx * cosY - lp.dy * sinY;
      final rotZ = lp.dx * sinY + lp.dy * cosY;

      final worldX = centerX + rotX;
      final worldY = (i < 4) ? baseY : (baseY + height);
      final worldZ = centerZ + rotZ;

      projected.add(project(worldX, worldY, worldZ, viewportSize));
    }

    return projected;
  }
}
