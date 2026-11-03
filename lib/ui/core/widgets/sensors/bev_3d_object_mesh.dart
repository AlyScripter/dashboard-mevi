import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../services/adas_mesh_service.dart';
import 'bev_3d_camera.dart';
import 'models/detected_3d_object.dart';

/// Helper untuk merender model 3D ADAS 3.0 skala industri di dalam 3D bounding box pada BEV.
/// Menghasilkan tampilan estetik studio clay grey (matte grey) mulus persis seperti
/// referensi resmi '3.0 ADAS 视觉识别模型':
/// - Bodi abu-abu studio clay elegan dengan gradasi pencahayaan halus bebas garis wireframe.
/// - Kaca depan & samping berwarna dark slate tinted yang rapi.
/// - 4 Roda & velg matte charcoal yang menapak sempurna di atas aspal.
/// - Zero loading delay & 60 FPS rendering.
class Bev3DObjectMesh {
  Bev3DObjectMesh._();

  // Vektor arah pencahayaan studio ADAS (dari atas-kanan-depan untuk bayangan kontur yang natural)
  static const double _lx = 0.288;
  static const double _ly = 0.906;
  static const double _lz = -0.311;

  /// Gambar model 3D solid ADAS studio clay grey di dalam bounding box objek
  static void drawObjectMesh({
    required Canvas canvas,
    required Size size,
    required Bev3DCamera camera,
    required Detected3DObject obj,
    required bool isLight,
  }) {
    if (obj.objectClass == Detected3DClass.trafficCone ||
        obj.objectClass == Detected3DClass.obstacle) {
      return; // Cukup 3D bounding box saja untuk rintangan generik / cone
    }

    final mesh = AdasMeshService.getMeshForClass(obj.objectClass);
    final rawVerts = mesh.vertices;
    final totalVerts = rawVerts.length ~/ 3;
    if (totalVerts == 0) return;

    final yawRad = (obj.yawDeg * math.pi) / 180.0;
    final cosY = math.cos(yawRad);
    final sinY = math.sin(yawRad);

    // 1. Transformasi & Proyeksi seluruh vertex sekaligus (Zero Allocation / Instant)
    final projectedPts = List<ProjectedPoint?>.filled(totalVerts, null);

    final scaleX = obj.width;
    final scaleY = obj.height;
    final scaleZ = obj.length;

    for (int i = 0; i < totalVerts; i++) {
      final vi = i * 3;
      final lx = rawVerts[vi] * scaleX;
      final ly = rawVerts[vi + 1] * scaleY;
      final lz = rawVerts[vi + 2] * scaleZ;

      // Rotasi yaw pada bidang horizontal X-Z
      final rotX = lx * cosY - lz * sinY;
      final rotZ = lx * sinY + lz * cosY;

      final worldX = obj.x + rotX;
      final worldY = obj.y + ly;
      final worldZ = obj.z + rotZ;

      projectedPts[i] = camera.project(worldX, worldY, worldZ, size);
    }

    // 2. Siapkan poligon terproyeksi dengan pencahayaan ADAS 3D
    final projectedFaces = <_ProjectedAdasFace>[];

    final double baseTone = isLight ? 210.0 : 155.0;
    final double ambient = isLight ? 0.40 : 0.46;

    for (final face in mesh.faces) {
      final indices = face.indices;
      if (indices.length < 3) continue;

      bool allVisible = true;
      double depthSum = 0.0;
      final screenPts = <Offset>[];

      for (final idx in indices) {
        if (idx < 0 || idx >= totalVerts) {
          allVisible = false;
          break;
        }
        final p = projectedPts[idx];
        if (p == null || !p.isVisible) {
          allVisible = false;
          break;
        }
        screenPts.add(p.screenOffset);
        depthSum += p.depth;
      }

      if (!allVisible) continue;

      // Rotasi normal face dengan sudut yaw
      final rnx = face.nx * cosY - face.nz * sinY;
      final rny = face.ny;
      final rnz = face.nx * sinY + face.nz * cosY;

      // Pencahayaan terarah (Lambertian diffuse n . L)
      final dot = (rnx * _lx + rny * _ly - rnz * _lz).clamp(0.0, 1.0);
      final intensity = ambient + (1.0 - ambient) * dot;

      final Color fillColor;

      if (face.isWheel) {
        // Ban / Roda: Matte dark graphite/charcoal dengan shading
        final v = (45 * intensity).round().clamp(20, 70);
        fillColor = Color.fromARGB(245, v, v + 2, v + 5);
      } else if (face.isGlass) {
        // Kaca Film Otomotif: Dark tinted dengan sentuhan warna kelas
        final classColor = obj.objectClass.primaryColor;
        final r = ((classColor.r * 255.0 * 0.35 + 40) * intensity).round().clamp(20, 90);
        final g = ((classColor.g * 255.0 * 0.35 + 50) * intensity).round().clamp(25, 110);
        final b = ((classColor.b * 255.0 * 0.35 + 70) * intensity).round().clamp(35, 130);
        fillColor = Color.fromARGB(220, r, g, b);
      } else if (face.isLightAccent) {
        // Aksen Lampu Halus (LED Frost White depan / Ruby Red belakang)
        final avgZ = indices.fold<double>(0.0, (acc, idx) => acc + rawVerts[idx * 3 + 2]) / indices.length;
        if (avgZ > 0) {
          fillColor = const Color(0xFFE0F2FE); // Lampu Depan: Frost LED White
        } else {
          fillColor = const Color(0xFFF43F5E); // Lampu Belakang: Ruby Red
        }
      } else {
        // Bodi 3D Model: Warna berbasis kelas objek dengan pencahayaan Lambertian
        // Menghasilkan tampilan 3D solid berwarna di dalam balok transparan sesuai gambar referensi
        final classColor = obj.objectClass.primaryColor;
        final baseR = (classColor.r * 255.0);
        final baseG = (classColor.g * 255.0);
        final baseB = (classColor.b * 255.0);

        final r = ((baseR * 0.82 + baseTone * 0.18) * intensity).round().clamp(0, 255);
        final g = ((baseG * 0.82 + baseTone * 0.18) * intensity).round().clamp(0, 255);
        final b = ((baseB * 0.82 + baseTone * 0.18) * intensity).round().clamp(0, 255);

        final alpha = isLight ? 235 : 220;
        fillColor = Color.fromARGB(alpha, r, g, b);
      }

      projectedFaces.add(_ProjectedAdasFace(
        points: screenPts,
        depth: depthSum / indices.length,
        fillColor: fillColor,
      ));
    }

    if (projectedFaces.isEmpty) return;

    // 3. Painter's Algorithm: Urutkan poligon dari terjauh ke terdekat
    projectedFaces.sort((a, b) => b.depth.compareTo(a.depth));

    // 4. Render permukaan poligon mulus tanpa garis kawat wireframe
    final fillPaint = Paint()..style = PaintingStyle.fill;

    for (final pf in projectedFaces) {
      final path = Path()..moveTo(pf.points[0].dx, pf.points[0].dy);
      for (int i = 1; i < pf.points.length; i++) {
        path.lineTo(pf.points[i].dx, pf.points[i].dy);
      }
      path.close();

      fillPaint.color = pf.fillColor;
      canvas.drawPath(path, fillPaint);
      // TIDAK menggambar strokePaint wireframe di setiap sisi!
      // Menghilangkan efek 'kandang kawat' sehingga bodi mobil menjadi mulus bersatu seperti clay CAD.
    }
  }
}

class _ProjectedAdasFace {
  final List<Offset> points;
  final double depth;
  final Color fillColor;

  const _ProjectedAdasFace({
    required this.points,
    required this.depth,
    required this.fillColor,
  });
}
