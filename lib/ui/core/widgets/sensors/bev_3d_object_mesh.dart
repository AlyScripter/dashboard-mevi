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

    // 2. Siapkan poligon terproyeksi dengan pencahayaan studio clay grey
    final projectedFaces = <_ProjectedAdasFace>[];

    // Warna dasar abu-abu clay studio (Sesuai referensi '3.0 ADAS 视觉识别模型')
    // Mode terang: abu-abu perak studio cerah (#CBD5E1 - #E2E8F0)
    // Mode gelap: abu-abu titanium matte (#8A95A5 - #94A3B8)
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
        // Ban / Roda: Matte dark graphite/charcoal (#242B35) dengan shading
        final v = (42 * intensity).round().clamp(18, 65);
        fillColor = Color.fromARGB(245, v, v + 2, v + 5);
      } else if (face.isGlass) {
        // Kaca Film Otomotif: Dark tinted slate (#334155 / #475569)
        final r = (50 * intensity).round().clamp(25, 80);
        final g = (65 * intensity).round().clamp(35, 100);
        final b = (85 * intensity).round().clamp(45, 125);
        fillColor = Color.fromARGB(225, r, g, b);
      } else if (face.isLightAccent) {
        // Aksen Lampu Halus (tidak mencolok, tetap elegan bernuansa studio)
        final avgZ = indices.fold<double>(0.0, (acc, idx) => acc + rawVerts[idx * 3 + 2]) / indices.length;
        if (avgZ > 0) {
          // Lampu Depan: Frost LED White
          fillColor = const Color(0xFFF1F5F9);
        } else {
          // Lampu Belakang: Dark Ruby Red
          fillColor = const Color(0xFFE11D48);
        }
      } else {
        // Bodi Studio Clay Grey (Persis gambar referensi abu-abu)
        final val = (baseTone * intensity).round().clamp(0, 255);
        final alpha = isLight ? 245 : 225;
        // Memberi sedikit nuansa perak netral dingin khas CAD
        fillColor = Color.fromARGB(alpha, val, (val * 1.01).round().clamp(0, 255), (val * 1.03).round().clamp(0, 255));
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
