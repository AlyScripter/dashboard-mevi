import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'bev_3d_camera.dart';
import 'models/detected_3d_object.dart';

/// Representasi titik 3D lokal relatif terhadap titik tengah dasar objek.
class _Vec3 {
  final double x; // meter (kiri -, kanan +)
  final double y; // meter (alas 0, atas +)
  final double z; // meter (belakang -, depan +)

  const _Vec3(this.x, this.y, this.z);
}

/// Sisi poligon 3D dengan warna fill pencahayaan mulus.
class _MeshFace {
  final List<_Vec3> vertices;
  final Color fillColor;

  const _MeshFace({
    required this.vertices,
    required this.fillColor,
  });
}

/// Helper untuk merender model 3D procedural (mobil sedan mewah aerodinamis,
/// pejalan kaki humanoid, pesepeda, truk, dan cone) di dalam 3D bounding box pada BEV.
/// Menghasilkan siluet bodi mulus (curved aerodynamic CAD shell) tanpa polygon kaku/kasar.
class Bev3DObjectMesh {
  /// Gambar model 3D solid hologram di dalam bounding box objek
  static void drawObjectMesh({
    required Canvas canvas,
    required Size size,
    required Bev3DCamera camera,
    required Detected3DObject obj,
    required bool isLight,
  }) {
    final faces = _generateFacesForObject(obj, isLight);
    if (faces.isEmpty) return;

    final yawRad = (obj.yawDeg * math.pi) / 180.0;
    final cosY = math.cos(yawRad);
    final sinY = math.sin(yawRad);

    // Siapkan daftar poligon terproyeksi yang akan di-depth sort (Painter's Algorithm)
    final projectedFaces = <_ProjectedFace>[];

    for (final face in faces) {
      final projectedPts = <ProjectedPoint>[];
      bool allVisible = true;

      for (final v in face.vertices) {
        // Rotasi Yaw pada bidang X-Z
        final rotX = v.x * cosY - v.z * sinY;
        final rotZ = v.x * sinY + v.z * cosY;

        final worldX = obj.x + rotX;
        final worldY = obj.y + v.y;
        final worldZ = obj.z + rotZ;

        final proj = camera.project(worldX, worldY, worldZ, size);
        if (!proj.isVisible) {
          allVisible = false;
          break;
        }
        projectedPts.add(proj);
      }

      if (allVisible && projectedPts.length >= 3) {
        final avgDepth =
            projectedPts.fold<double>(0.0, (acc, p) => acc + p.depth) /
                projectedPts.length;

        projectedFaces.add(_ProjectedFace(
          face: face,
          points: projectedPts.map((p) => p.screenOffset).toList(),
          depth: avgDepth,
        ));
      }
    }

    // Urutkan dari yang terjauh ke terdekat (Painter's Algorithm)
    projectedFaces.sort((a, b) => b.depth.compareTo(a.depth));

    // Render setiap poligon dengan rendering halus bebas artefak
    for (final pf in projectedFaces) {
      final path = Path()..moveTo(pf.points[0].dx, pf.points[0].dy);
      for (int i = 1; i < pf.points.length; i++) {
        path.lineTo(pf.points[i].dx, pf.points[i].dy);
      }
      path.close();

      // 1. Gambar permukaan poligon mulus (Smooth Shaded Fill)
      final fillPaint = Paint()
        ..color = pf.face.fillColor
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);
    }

    // Indikator haluan otonom (Autonomous trajectory chevron di kap mesin)
    if (obj.objectClass == Detected3DClass.car) {
      _drawAutonomousHeadingChevron(
        canvas: canvas,
        size: size,
        camera: camera,
        obj: obj,
        isLight: isLight,
        cosY: cosY,
        sinY: sinY,
      );
    }
  }

  /// Menghasilkan kumpulan poligon 3D berdasarkan kelas objek
  static List<_MeshFace> _generateFacesForObject(
    Detected3DObject obj,
    bool isLight,
  ) {
    switch (obj.objectClass) {
      case Detected3DClass.car:
        return _buildCurvedCarFaces(obj, isLight);
      case Detected3DClass.motorcycle:
        return _buildSmoothMotorcycleFaces(obj, isLight);
      case Detected3DClass.truck:
        return _buildCurvedTruckFaces(obj, isLight);
      case Detected3DClass.pedestrian:
        return _buildSmoothPedestrianFaces(obj, isLight);
      case Detected3DClass.bicycle:
        return _buildSmoothBicycleFaces(obj, isLight);
      case Detected3DClass.trafficCone:
        return _buildTrafficConeFaces(obj, isLight);
      case Detected3DClass.obstacle:
        return _buildObstacleFaces(obj, isLight);
    }
  }

  // ===========================================================================
  // 1. MODEL 3D MOBIL SEDAN AERODINAMIS & CURVED (PERSIS GAMBAR REFERENSI)
  // ===========================================================================
  static List<_MeshFace> _buildCurvedCarFaces(
    Detected3DObject obj,
    bool isLight,
  ) {
    final faces = <_MeshFace>[];

    // Dimensi bodi mobil yang pas di dalam bounding box
    final hw = (obj.width / 2.0) * 0.90;
    final hl = (obj.length / 2.0) * 0.92;
    final h = obj.height * 0.88;

    final primary = obj.objectClass.primaryColor;

    // 11 Stasiun Penampang Melintang di Sepanjang Sumbu Panjang Mobil (Z)
    // Menghasilkan kelengkungan bodi sedan aerodinamis yang mulus (Coupe/Sedan Silhouette)
    final stations = <_CarStation>[
      // 0: Ujung Hidung Bumper Depan (membulat)
      _CarStation(u: 1.00, yTopCenter: 0.25, yTopShoulder: 0.22, wTop: 0.32, yBelt: 0.18, wBelt: 0.48, yRocker: 0.08, wRocker: 0.42),
      // 1: Grille / Bumper Fascia Depan
      _CarStation(u: 0.88, yTopCenter: 0.36, yTopShoulder: 0.33, wTop: 0.60, yBelt: 0.28, wBelt: 0.78, yRocker: 0.08, wRocker: 0.72),
      // 2: Kap Depan / Spatbor Depan
      _CarStation(u: 0.70, yTopCenter: 0.44, yTopShoulder: 0.41, wTop: 0.76, yBelt: 0.36, wBelt: 0.94, yRocker: 0.09, wRocker: 0.90),
      // 3: Kap Mesin Tengah
      _CarStation(u: 0.50, yTopCenter: 0.49, yTopShoulder: 0.46, wTop: 0.82, yBelt: 0.42, wBelt: 0.98, yRocker: 0.10, wRocker: 0.94),
      // 4: Pangkal Kaca Depan (Cowl / A-Pillar Base)
      _CarStation(u: 0.32, yTopCenter: 0.56, yTopShoulder: 0.52, wTop: 0.84, yBelt: 0.45, wBelt: 1.00, yRocker: 0.10, wRocker: 0.96, isWindshield: true),
      // 5: Atap Depan (A-Pillar Header)
      _CarStation(u: 0.10, yTopCenter: 0.96, yTopShoulder: 0.92, wTop: 0.68, yBelt: 0.46, wBelt: 1.00, yRocker: 0.10, wRocker: 0.96, isRoof: true),
      // 6: Puncak Lengkungan Atap (B-Pillar / Crown of Roof)
      _CarStation(u: -0.12, yTopCenter: 0.98, yTopShoulder: 0.95, wTop: 0.70, yBelt: 0.46, wBelt: 1.00, yRocker: 0.10, wRocker: 0.96, isRoof: true),
      // 7: Atap Belakang (C-Pillar Top)
      _CarStation(u: -0.36, yTopCenter: 0.92, yTopShoulder: 0.88, wTop: 0.68, yBelt: 0.46, wBelt: 1.00, yRocker: 0.10, wRocker: 0.96, isRearGlass: true),
      // 8: Pangkal Kaca Belakang / Dek Bagasi Depan
      _CarStation(u: -0.62, yTopCenter: 0.54, yTopShoulder: 0.51, wTop: 0.80, yBelt: 0.45, wBelt: 0.98, yRocker: 0.10, wRocker: 0.95),
      // 9: Bibir Bagasi Belakang (Ducktail / Fascia Belakang)
      _CarStation(u: -0.86, yTopCenter: 0.47, yTopShoulder: 0.44, wTop: 0.72, yBelt: 0.40, wBelt: 0.88, yRocker: 0.09, wRocker: 0.84),
      // 10: Ujung Bumper Belakang (membulat)
      _CarStation(u: -1.00, yTopCenter: 0.35, yTopShoulder: 0.30, wTop: 0.42, yBelt: 0.25, wBelt: 0.62, yRocker: 0.08, wRocker: 0.58),
    ];

    // Bangun titik 3D untuk setiap stasiun
    final rings = <List<_Vec3>>[];
    for (final s in stations) {
      final z = s.u * hl;
      rings.add([
        _Vec3(0.0, s.yTopCenter * h, z), // 0: Spine Top Center
        _Vec3(s.wTop * hw, s.yTopShoulder * h, z), // 1: Right Top Shoulder
        _Vec3(s.wBelt * hw, s.yBelt * h, z), // 2: Right Beltline
        _Vec3(s.wRocker * hw, s.yRocker * h, z), // 3: Right Rocker
        _Vec3(-s.wRocker * hw, s.yRocker * h, z), // 4: Left Rocker
        _Vec3(-s.wBelt * hw, s.yBelt * h, z), // 5: Left Beltline
        _Vec3(-s.wTop * hw, s.yTopShoulder * h, z), // 6: Left Top Shoulder
      ]);
    }

    // Bangun permukaan kulit (Skinning Quads) antar stasiun melintang
    for (int i = 0; i < stations.length - 1; i++) {
      final sCurr = stations[i];
      final sNext = stations[i + 1];
      final r0 = rings[i];
      final r1 = rings[i + 1];

      final isGlassSection = (sCurr.isWindshield && sNext.isRoof) ||
          (sCurr.isRoof && sNext.isRoof) ||
          (sCurr.isRoof && sNext.isRearGlass) ||
          (sCurr.isRearGlass);

      // A. Panel Atas Kanan
      _addShadedQuad(
        faces: faces,
        v0: r0[0],
        v1: r1[0],
        v2: r1[1],
        v3: r0[1],
        baseColor: primary,
        isGlass: isGlassSection,
        isLight: isLight,
      );

      // B. Panel Kaca / Bahu Kanan
      _addShadedQuad(
        faces: faces,
        v0: r0[1],
        v1: r1[1],
        v2: r1[2],
        v3: r0[2],
        baseColor: primary,
        isGlass: isGlassSection,
        isLight: isLight,
      );

      // C. Panel Pintu Samping Bawah Kanan (Door Flank)
      _addShadedQuad(
        faces: faces,
        v0: r0[2],
        v1: r1[2],
        v2: r1[3],
        v3: r0[3],
        baseColor: primary,
        isGlass: false,
        isLight: isLight,
      );

      // D. Lantai Kolong Bawah (Underside Shadow)
      _addShadedQuad(
        faces: faces,
        v0: r0[3],
        v1: r1[3],
        v2: r1[4],
        v3: r0[4],
        baseColor: primary,
        isGlass: false,
        isLight: isLight,
        isUnderbody: true,
      );

      // E. Panel Pintu Samping Bawah Kiri (Door Flank)
      _addShadedQuad(
        faces: faces,
        v0: r0[4],
        v1: r1[4],
        v2: r1[5],
        v3: r0[5],
        baseColor: primary,
        isGlass: false,
        isLight: isLight,
      );

      // F. Panel Kaca / Bahu Kiri
      _addShadedQuad(
        faces: faces,
        v0: r0[5],
        v1: r1[5],
        v2: r1[6],
        v3: r0[6],
        baseColor: primary,
        isGlass: isGlassSection,
        isLight: isLight,
      );

      // G. Panel Atas Kiri
      _addShadedQuad(
        faces: faces,
        v0: r0[6],
        v1: r1[6],
        v2: r1[0],
        v3: r0[0],
        baseColor: primary,
        isGlass: isGlassSection,
        isLight: isLight,
      );
    }

    // Tutup Hidung Depan (Curved Front Fascia Cap)
    final rFront = rings[0];
    final noseCenter = _Vec3(0.0, 0.15 * h, hl * 1.01);
    faces.add(_MeshFace(
      vertices: [noseCenter, rFront[1], rFront[0], rFront[6]],
      fillColor: _shadeFace(v0: noseCenter, v1: rFront[1], v2: rFront[0], baseColor: primary, isGlass: false, isLight: isLight),
    ));
    faces.add(_MeshFace(
      vertices: [noseCenter, rFront[2], rFront[1]],
      fillColor: _shadeFace(v0: noseCenter, v1: rFront[2], v2: rFront[1], baseColor: primary, isGlass: false, isLight: isLight),
    ));
    faces.add(_MeshFace(
      vertices: [noseCenter, rFront[6], rFront[5]],
      fillColor: _shadeFace(v0: noseCenter, v1: rFront[6], v2: rFront[5], baseColor: primary, isGlass: false, isLight: isLight),
    ));

    // Tutup Buritan Belakang (Curved Rear Fascia Cap)
    final rRear = rings.last;
    final tailCenter = _Vec3(0.0, 0.18 * h, -hl * 1.01);
    faces.add(_MeshFace(
      vertices: [tailCenter, rRear[6], rRear[0], rRear[1]],
      fillColor: _shadeFace(v0: tailCenter, v1: rRear[6], v2: rRear[0], baseColor: primary, isGlass: false, isLight: isLight),
    ));
    faces.add(_MeshFace(
      vertices: [tailCenter, rRear[5], rRear[6]],
      fillColor: _shadeFace(v0: tailCenter, v1: rRear[5], v2: rRear[6], baseColor: primary, isGlass: false, isLight: isLight),
    ));
    faces.add(_MeshFace(
      vertices: [tailCenter, rRear[1], rRear[2]],
      fillColor: _shadeFace(v0: tailCenter, v1: rRear[1], v2: rRear[2], baseColor: primary, isGlass: false, isLight: isLight),
    ));

    // 4 Roda 3D Stylized Terselubung Rapi di Kolong Spatbor
    final wheelColor = isLight
        ? const Color(0xFF0F2537).withValues(alpha: 0.70)
        : const Color(0xFF03101C).withValues(alpha: 0.85);
    _addCurvedWheel(faces, hw * 0.94, hl * 0.58, 0.20 * h, wheelColor);
    _addCurvedWheel(faces, -hw * 0.94, hl * 0.58, 0.20 * h, wheelColor);
    _addCurvedWheel(faces, hw * 0.94, -hl * 0.58, 0.20 * h, wheelColor);
    _addCurvedWheel(faces, -hw * 0.94, -hl * 0.58, 0.20 * h, wheelColor);

    return faces;
  }

  // ===========================================================================
  // 2. MODEL 3D TRUK LISTRIK AERODINAMIS (EV TRUCK)
  // ===========================================================================
  static List<_MeshFace> _buildCurvedTruckFaces(
    Detected3DObject obj,
    bool isLight,
  ) {
    final faces = <_MeshFace>[];
    final hw = (obj.width / 2.0) * 0.90;
    final hl = (obj.length / 2.0) * 0.92;
    final h = obj.height * 0.88;

    final primary = obj.objectClass.primaryColor;
    final cabZ = hl * 0.32;

    // A. Kabin Truk Aerodinamis (Curved Windshield & Nose)
    final vNoseL = _Vec3(-hw * 0.88, 0.12 * h, hl);
    final vNoseR = _Vec3(hw * 0.88, 0.12 * h, hl);
    final vHoodL = _Vec3(-hw * 0.88, 0.42 * h, hl * 0.96);
    final vHoodR = _Vec3(hw * 0.88, 0.42 * h, hl * 0.96);
    final vRoofL = _Vec3(-hw * 0.82, 0.96 * h, cabZ + 0.15);
    final vRoofR = _Vec3(hw * 0.82, 0.96 * h, cabZ + 0.15);
    final vCabBackL = _Vec3(-hw * 0.85, 0.12 * h, cabZ);
    final vCabBackR = _Vec3(hw * 0.85, 0.12 * h, cabZ);

    // Bumper Depan Truk
    _addShadedQuad(faces: faces, v0: vNoseL, v1: vNoseR, v2: vHoodR, v3: vHoodL, baseColor: primary, isGlass: false, isLight: isLight);
    // Kaca Depan Kabin Truk Besar
    _addShadedQuad(faces: faces, v0: vHoodL, v1: vHoodR, v2: vRoofR, v3: vRoofL, baseColor: primary, isGlass: true, isLight: isLight);
    // Sisi Kiri & Kanan Kabin
    _addShadedQuad(faces: faces, v0: vNoseL, v1: vHoodL, v2: vRoofL, v3: vCabBackL, baseColor: primary, isGlass: false, isLight: isLight);
    _addShadedQuad(faces: faces, v0: vHoodR, v1: vNoseR, v2: vCabBackR, v3: vRoofR, baseColor: primary, isGlass: false, isLight: isLight);

    // B. Boks Kargo Belakang (Clean Streamlined Box)
    final boxRoofL = _Vec3(-hw * 0.96, h, cabZ);
    final boxRoofR = _Vec3(hw * 0.96, h, cabZ);
    final boxRearRoofL = _Vec3(-hw * 0.96, h, -hl);
    final boxRearRoofR = _Vec3(hw * 0.96, h, -hl);
    final boxRearBotL = _Vec3(-hw * 0.96, 0.15 * h, -hl);
    final boxRearBotR = _Vec3(hw * 0.96, 0.15 * h, -hl);
    final boxBotL = _Vec3(-hw * 0.96, 0.15 * h, cabZ);
    final boxBotR = _Vec3(hw * 0.96, 0.15 * h, cabZ);

    // Atap Boks Kargo
    _addShadedQuad(faces: faces, v0: boxRoofL, v1: boxRoofR, v2: boxRearRoofR, v3: boxRearRoofL, baseColor: primary, isGlass: false, isLight: isLight);
    // Sisi Kiri Boks
    _addShadedQuad(faces: faces, v0: boxBotL, v1: boxRoofL, v2: boxRearRoofL, v3: boxRearBotL, baseColor: primary, isGlass: false, isLight: isLight);
    // Sisi Kanan Boks
    _addShadedQuad(faces: faces, v0: boxRoofR, v1: boxBotR, v2: boxRearBotR, v3: boxRearRoofR, baseColor: primary, isGlass: false, isLight: isLight);
    // Pintu Belakang Boks
    _addShadedQuad(faces: faces, v0: boxRearRoofL, v1: boxRearRoofR, v2: boxRearBotR, v3: boxRearBotL, baseColor: primary, isGlass: false, isLight: isLight);

    return faces;
  }

  // ===========================================================================
  // 3. MODEL 3D PEJALAN KAKI HUMANOID (SMOOTH SILHOUETTE)
  // ===========================================================================
  static List<_MeshFace> _buildSmoothPedestrianFaces(
    Detected3DObject obj,
    bool isLight,
  ) {
    final faces = <_MeshFace>[];
    final hw = (obj.width / 2.0) * 0.80;
    final hl = (obj.length / 2.0) * 0.80;
    final h = obj.height * 0.92;

    final primary = obj.objectClass.primaryColor;

    // A. Kepala Membulat (Hexagonal Prismatic Head)
    const segments = 6;
    final headRadius = hw * 0.48;
    final headCenterY = 0.86 * h;
    final headHeight = 0.14 * h;

    final headTop = <_Vec3>[];
    final headBot = <_Vec3>[];

    for (int i = 0; i < segments; i++) {
      final ang = (i * 2.0 * math.pi) / segments;
      final x = headRadius * math.cos(ang);
      final z = headRadius * math.sin(ang);
      headTop.add(_Vec3(x, headCenterY + headHeight / 2.0, z));
      headBot.add(_Vec3(x, headCenterY - headHeight / 2.0, z));
    }

    for (int i = 0; i < segments; i++) {
      final next = (i + 1) % segments;
      _addShadedQuad(
        faces: faces,
        v0: headBot[i],
        v1: headBot[next],
        v2: headTop[next],
        v3: headTop[i],
        baseColor: primary,
        isGlass: false,
        isLight: isLight,
      );
    }
    faces.add(_MeshFace(
      vertices: headTop,
      fillColor: primary.withValues(alpha: isLight ? 0.75 : 0.85),
    ));

    // B. Torso Bahu Membulat Melandai ke Pinggul
    final shoulderW = hw * 0.82;
    final waistW = hw * 0.58;
    final torsoHl = hl * 0.48;

    final vShL = _Vec3(-shoulderW, 0.74 * h, torsoHl * 0.8);
    final vShR = _Vec3(shoulderW, 0.74 * h, torsoHl * 0.8);
    final vWsR = _Vec3(waistW, 0.40 * h, torsoHl * 0.6);
    final vWsL = _Vec3(-waistW, 0.40 * h, torsoHl * 0.6);

    final vShBackL = _Vec3(-shoulderW, 0.74 * h, -torsoHl * 0.8);
    final vShBackR = _Vec3(shoulderW, 0.74 * h, -torsoHl * 0.8);
    final vWsBackR = _Vec3(waistW, 0.40 * h, -torsoHl * 0.6);
    final vWsBackL = _Vec3(-waistW, 0.40 * h, -torsoHl * 0.6);

    _addShadedQuad(faces: faces, v0: vShL, v1: vShR, v2: vWsR, v3: vWsL, baseColor: primary, isGlass: false, isLight: isLight);
    _addShadedQuad(faces: faces, v0: vShBackR, v1: vShBackL, v2: vWsBackL, v3: vWsBackR, baseColor: primary, isGlass: false, isLight: isLight);
    _addShadedQuad(faces: faces, v0: vShBackL, v1: vShL, v2: vWsL, v3: vWsBackL, baseColor: primary, isGlass: false, isLight: isLight);
    _addShadedQuad(faces: faces, v0: vShR, v1: vShBackR, v2: vWsBackR, v3: vWsR, baseColor: primary, isGlass: false, isLight: isLight);

    // C. Kaki Kiri & Kanan Berjalan Mulus
    final legW = waistW * 0.42;
    _addSmoothLeg(faces, -waistW * 0.60, legW, 0.04 * h, 0.40 * h, hl * 0.35, primary, isLight);
    _addSmoothLeg(faces, waistW * 0.60, legW, 0.04 * h, 0.40 * h, -hl * 0.35, primary, isLight);

    return faces;
  }

  static void _addSmoothLeg(
    List<_MeshFace> faces,
    double cx,
    double w,
    double y1,
    double y2,
    double zOffset,
    Color baseColor,
    bool isLight,
  ) {
    final v0 = _Vec3(cx - w, y1, zOffset + w);
    final v1 = _Vec3(cx + w, y1, zOffset + w);
    final v2 = _Vec3(cx + w, y2, zOffset * 0.5 + w);
    final v3 = _Vec3(cx - w, y2, zOffset * 0.5 + w);

    final vb0 = _Vec3(cx - w, y1, zOffset - w);
    final vb1 = _Vec3(cx + w, y1, zOffset - w);
    final vb2 = _Vec3(cx + w, y2, zOffset * 0.5 - w);
    final vb3 = _Vec3(cx - w, y2, zOffset * 0.5 - w);

    _addShadedQuad(faces: faces, v0: v0, v1: v1, v2: v2, v3: v3, baseColor: baseColor, isGlass: false, isLight: isLight);
    _addShadedQuad(faces: faces, v0: vb1, v1: vb0, v2: vb3, v3: vb2, baseColor: baseColor, isGlass: false, isLight: isLight);
    _addShadedQuad(faces: faces, v0: vb0, v1: v0, v2: v3, v3: vb3, baseColor: baseColor, isGlass: false, isLight: isLight);
    _addShadedQuad(faces: faces, v0: v1, v1: vb1, v2: vb2, v3: v2, baseColor: baseColor, isGlass: false, isLight: isLight);
  }

  // ===========================================================================
  // 4. MODEL 3D SEPEDA & PENGENDARA (BICYCLE & RIDER)
  // ===========================================================================
  static List<_MeshFace> _buildSmoothBicycleFaces(
    Detected3DObject obj,
    bool isLight,
  ) {
    final faces = <_MeshFace>[];
    final hw = (obj.width / 2.0) * 0.65;
    final hl = (obj.length / 2.0) * 0.85;
    final h = obj.height * 0.88;

    final primary = obj.objectClass.primaryColor;

    // 1. Roda Depan & Roda Belakang 3D
    _addCurvedWheel(faces, 0.0, hl * 0.65, 0.24 * h, primary);
    _addCurvedWheel(faces, 0.0, -hl * 0.65, 0.24 * h, primary);

    // 2. Rangka Bodi Sepeda
    final frameColor = primary.withValues(alpha: isLight ? 0.75 : 0.85);
    faces.add(_MeshFace(
      vertices: [
        _Vec3(-hw * 0.18, 0.24 * h, -hl * 0.65),
        _Vec3(hw * 0.18, 0.24 * h, -hl * 0.65),
        _Vec3(hw * 0.18, 0.52 * h, hl * 0.35),
        _Vec3(-hw * 0.18, 0.52 * h, hl * 0.35),
      ],
      fillColor: frameColor,
    ));

    // Stang
    faces.add(_MeshFace(
      vertices: [
        _Vec3(-hw * 0.85, 0.62 * h, hl * 0.38),
        _Vec3(hw * 0.85, 0.62 * h, hl * 0.38),
        _Vec3(hw * 0.85, 0.66 * h, hl * 0.35),
        _Vec3(-hw * 0.85, 0.66 * h, hl * 0.35),
      ],
      fillColor: frameColor,
    ));

    // 3. Figur Pengendara
    final riderW = hw * 0.50;
    _addShadedQuad(
      faces: faces,
      v0: _Vec3(-riderW, 0.45 * h, -hl * 0.20),
      v1: _Vec3(riderW, 0.45 * h, -hl * 0.20),
      v2: _Vec3(riderW * 0.9, 0.78 * h, hl * 0.08),
      v3: _Vec3(-riderW * 0.9, 0.78 * h, hl * 0.08),
      baseColor: primary,
      isGlass: false,
      isLight: isLight,
    );

    // Helm / Kepala Pengendara
    final headRadius = riderW * 0.65;
    faces.add(_MeshFace(
      vertices: [
        _Vec3(-headRadius, 0.80 * h, hl * 0.12),
        _Vec3(headRadius, 0.80 * h, hl * 0.12),
        _Vec3(headRadius, 0.95 * h, hl * 0.12),
        _Vec3(-headRadius, 0.95 * h, hl * 0.12),
      ],
      fillColor: primary.withValues(alpha: isLight ? 0.80 : 0.90),
    ));

    return faces;
  }

  // ===========================================================================
  // 5. MODEL 3D SEPEDA MOTOR & PENGENDARA (MOTORCYCLE & RIDER)
  // ===========================================================================
  static List<_MeshFace> _buildSmoothMotorcycleFaces(
    Detected3DObject obj,
    bool isLight,
  ) {
    final faces = <_MeshFace>[];
    final hw = (obj.width / 2.0) * 0.82;
    final hl = (obj.length / 2.0) * 0.88;
    final h = obj.height * 0.90;

    final primary = obj.objectClass.primaryColor;
    final wheelColor = isLight
        ? const Color(0xFF0F2537).withValues(alpha: 0.75)
        : const Color(0xFF03101C).withValues(alpha: 0.88);

    // 1. Roda Depan & Roda Belakang 3D
    _addCurvedWheel(faces, 0.0, hl * 0.62, 0.26 * h, wheelColor);
    _addCurvedWheel(faces, 0.0, -hl * 0.62, 0.26 * h, wheelColor);

    // 2. Blok Mesin & Rangka Bawah (Engine Block & Lower Chassis)
    final engineW = hw * 0.60;
    final e0 = _Vec3(-engineW, 0.12 * h, hl * 0.35);
    final e1 = _Vec3(engineW, 0.12 * h, hl * 0.35);
    final e2 = _Vec3(engineW, 0.45 * h, -hl * 0.40);
    final e3 = _Vec3(-engineW, 0.45 * h, -hl * 0.40);
    _addShadedQuad(faces: faces, v0: e0, v1: e1, v2: e2, v3: e3, baseColor: primary, isGlass: false, isLight: isLight, isUnderbody: true);

    // 3. Tangki Bensin & Bodi Depan (Fuel Tank & Front Fairing)
    final tankW = hw * 0.75;
    final tFwdL = _Vec3(-tankW * 0.8, 0.68 * h, hl * 0.45);
    final tFwdR = _Vec3(tankW * 0.8, 0.68 * h, hl * 0.45);
    final tMidR = _Vec3(tankW, 0.65 * h, 0.0);
    final tMidL = _Vec3(-tankW, 0.65 * h, 0.0);
    final tRearR = _Vec3(tankW * 0.5, 0.52 * h, -hl * 0.55);
    final tRearL = _Vec3(-tankW * 0.5, 0.52 * h, -hl * 0.55);

    // Bagian Atas Tangki & Jok
    _addShadedQuad(faces: faces, v0: tFwdL, v1: tFwdR, v2: tMidR, v3: tMidL, baseColor: primary, isGlass: false, isLight: isLight);
    _addShadedQuad(faces: faces, v0: tMidL, v1: tMidR, v2: tRearR, v3: tRearL, baseColor: primary, isGlass: false, isLight: isLight);

    // Sisi Kanan Bodi Motor
    _addShadedQuad(faces: faces, v0: e1, v1: tFwdR, v2: tMidR, v3: e2, baseColor: primary, isGlass: false, isLight: isLight);
    // Sisi Kiri Bodi Motor
    _addShadedQuad(faces: faces, v0: tFwdL, v1: e0, v2: e3, v3: tMidL, baseColor: primary, isGlass: false, isLight: isLight);

    // 4. Windshield & Lampu Depan Motor
    final wsTopL = _Vec3(-tankW * 0.5, 0.82 * h, hl * 0.50);
    final wsTopR = _Vec3(tankW * 0.5, 0.82 * h, hl * 0.50);
    _addShadedQuad(faces: faces, v0: tFwdL, v1: tFwdR, v2: wsTopR, v3: wsTopL, baseColor: primary, isGlass: true, isLight: isLight);

    // 5. Stang Kemudi (Handlebars)
    faces.add(_MeshFace(
      vertices: [
        _Vec3(-hw * 1.15, 0.72 * h, hl * 0.36),
        _Vec3(hw * 1.15, 0.72 * h, hl * 0.36),
        _Vec3(hw * 1.15, 0.76 * h, hl * 0.32),
        _Vec3(-hw * 1.15, 0.76 * h, hl * 0.32),
      ],
      fillColor: primary.withValues(alpha: isLight ? 0.85 : 0.95),
    ));

    // 6. Siluet Pengendara Motor (Rider Torso & Helmet)
    final riderW = hw * 0.60;
    final rBottomL = _Vec3(-riderW, 0.50 * h, -hl * 0.35);
    final rBottomR = _Vec3(riderW, 0.50 * h, -hl * 0.35);
    final rShoulderR = _Vec3(riderW * 0.9, 0.82 * h, hl * 0.05);
    final rShoulderL = _Vec3(-riderW * 0.9, 0.82 * h, hl * 0.05);

    // Dada / Punggung Pengendara
    _addShadedQuad(faces: faces, v0: rBottomL, v1: rBottomR, v2: rShoulderR, v3: rShoulderL, baseColor: primary, isGlass: false, isLight: isLight);

    // Helm Pengendara Motor (Head / Helmet)
    final helmRadius = riderW * 0.55;
    faces.add(_MeshFace(
      vertices: [
        _Vec3(-helmRadius, 0.82 * h, hl * 0.08),
        _Vec3(helmRadius, 0.82 * h, hl * 0.08),
        _Vec3(helmRadius, 0.98 * h, hl * 0.08),
        _Vec3(-helmRadius, 0.98 * h, hl * 0.08),
      ],
      fillColor: primary.withValues(alpha: isLight ? 0.88 : 0.98),
    ));

    return faces;
  }

  // ===========================================================================
  // 6. TRAFFIC CONE & OBSTACLE
  // ===========================================================================
  static List<_MeshFace> _buildTrafficConeFaces(Detected3DObject obj, bool isLight) {
    final faces = <_MeshFace>[];
    final hw = (obj.width / 2.0) * 0.85;
    final hl = (obj.length / 2.0) * 0.85;
    final h = obj.height * 0.95;

    final coneColor = const Color(0xFFFF6D00).withValues(alpha: 0.85);

    faces.add(_MeshFace(
      vertices: [
        _Vec3(-hw, 0.05 * h, -hl),
        _Vec3(hw, 0.05 * h, -hl),
        _Vec3(hw, 0.05 * h, hl),
        _Vec3(-hw, 0.05 * h, hl),
      ],
      fillColor: coneColor,
    ));

    final top = _Vec3(0.0, h, 0.0);
    final bFL = _Vec3(-hw * 0.7, 0.05 * h, hl * 0.7);
    final bFR = _Vec3(hw * 0.7, 0.05 * h, hl * 0.7);
    final bBR = _Vec3(hw * 0.7, 0.05 * h, -hl * 0.7);
    final bBL = _Vec3(-hw * 0.7, 0.05 * h, -hl * 0.7);

    faces.add(_MeshFace(vertices: [bFL, bFR, top], fillColor: coneColor));
    faces.add(_MeshFace(vertices: [bFR, bBR, top], fillColor: coneColor));
    faces.add(_MeshFace(vertices: [bBR, bBL, top], fillColor: coneColor));
    faces.add(_MeshFace(vertices: [bBL, bFL, top], fillColor: coneColor));

    return faces;
  }

  static List<_MeshFace> _buildObstacleFaces(Detected3DObject obj, bool isLight) {
    final faces = <_MeshFace>[];
    final hw = (obj.width / 2.0) * 0.90;
    final hl = (obj.length / 2.0) * 0.90;
    final h = obj.height * 0.88;

    final primary = obj.objectClass.primaryColor;

    final v0 = _Vec3(-hw, 0.05 * h, hl);
    final v1 = _Vec3(hw, 0.05 * h, hl);
    final v2 = _Vec3(hw, 0.05 * h, -hl);
    final v3 = _Vec3(-hw, 0.05 * h, -hl);
    final v4 = _Vec3(-hw, h, hl);
    final v5 = _Vec3(hw, h, hl);
    final v6 = _Vec3(hw, h, -hl);
    final v7 = _Vec3(-hw, h, -hl);

    _addShadedQuad(faces: faces, v0: v0, v1: v1, v2: v5, v3: v4, baseColor: primary, isGlass: false, isLight: isLight);
    _addShadedQuad(faces: faces, v0: v1, v1: v2, v2: v6, v3: v5, baseColor: primary, isGlass: false, isLight: isLight);
    _addShadedQuad(faces: faces, v0: v2, v1: v3, v2: v7, v3: v6, baseColor: primary, isGlass: false, isLight: isLight);
    _addShadedQuad(faces: faces, v0: v3, v1: v0, v2: v4, v3: v7, baseColor: primary, isGlass: false, isLight: isLight);
    _addShadedQuad(faces: faces, v0: v4, v1: v5, v2: v6, v3: v7, baseColor: primary, isGlass: false, isLight: isLight);

    return faces;
  }

  // ===========================================================================
  // SHADING & LIGHTING ENGINE (DIRECTIONAL NORMAL SHADING)
  // ===========================================================================
  static void _addShadedQuad({
    required List<_MeshFace> faces,
    required _Vec3 v0,
    required _Vec3 v1,
    required _Vec3 v2,
    _Vec3? v3,
    required Color baseColor,
    required bool isGlass,
    required bool isLight,
    bool isUnderbody = false,
  }) {
    final quadVertices = v3 != null
        ? [v0, v1, v2, v3]
        : [v0, v1, v2];

    final shadedColor = _shadeFace(
      v0: v0,
      v1: v1,
      v2: v2,
      baseColor: baseColor,
      isGlass: isGlass,
      isLight: isLight,
      isUnderbody: isUnderbody,
    );

    faces.add(_MeshFace(
      vertices: quadVertices,
      fillColor: shadedColor,
    ));
  }

  static Color _shadeFace({
    required _Vec3 v0,
    required _Vec3 v1,
    required _Vec3 v2,
    required Color baseColor,
    required bool isGlass,
    required bool isLight,
    bool isUnderbody = false,
  }) {
    if (isUnderbody) {
      return (isLight ? const Color(0xFF0D1E2D) : const Color(0xFF030A12))
          .withValues(alpha: 0.55);
    }

    // Hitung Vektor Normal 3D Permukaan (Cross Product)
    final ux = v1.x - v0.x;
    final uy = v1.y - v0.y;
    final uz = v1.z - v0.z;

    final vx = v2.x - v0.x;
    final vy = v2.y - v0.y;
    final vz = v2.z - v0.z;

    double nx = uy * vz - uz * vy;
    double ny = uz * vx - ux * vz;
    double nz = ux * vy - uy * vx;

    final len = math.sqrt(nx * nx + ny * ny + nz * nz);
    if (len > 0.0001) {
      nx /= len;
      ny /= len;
      nz /= len;
    } else {
      ny = 1.0;
    }

    if (ny < 0) {
      nx = -nx;
      ny = -ny;
      nz = -nz;
    }

    // Arah cahaya datang dari atas-kanan-depan (Key Light)
    const lx = 0.35;
    const ly = 0.85;
    const lz = 0.40;
    const lLen = 0.997;

    final dot = ((nx * lx + ny * ly + nz * lz) / lLen).clamp(-0.15, 1.0);
    final diffuse = math.max(0.0, dot);
    final specular = math.pow(diffuse, 3.5).toDouble() * 0.32;

    if (isGlass) {
      final glassCyan = isLight ? const Color(0xFF00E5FF) : const Color(0xFF4DD0E1);
      final alpha = (0.50 + diffuse * 0.28).clamp(0.40, 0.88);
      return Color.lerp(glassCyan, Colors.white, specular)!.withValues(alpha: alpha);
    }

    final ambient = 0.45;
    final factor = (ambient + diffuse * 0.55 + specular).clamp(0.40, 1.30);

    final r = (baseColor.r * 255 * factor).clamp(0, 255).toInt();
    final g = (baseColor.g * 255 * factor).clamp(0, 255).toInt();
    final b = (baseColor.b * 255 * factor).clamp(0, 255).toInt();
    final alpha = isLight ? 0.70 : 0.78;

    return Color.fromARGB((alpha * 255).toInt(), r, g, b);
  }

  // ===========================================================================
  // RODA CURVED & CHEVRON HALUAN
  // ===========================================================================
  static void _addCurvedWheel(
    List<_MeshFace> faces,
    double cx,
    double cz,
    double radius,
    Color color,
  ) {
    const segments = 8;
    final pts = <_Vec3>[];
    for (int i = 0; i < segments; i++) {
      final ang = (i * 2.0 * math.pi) / segments;
      pts.add(_Vec3(
        cx,
        radius + radius * math.sin(ang) * 0.95,
        cz + radius * math.cos(ang) * 0.95,
      ));
    }
    faces.add(_MeshFace(
      vertices: pts,
      fillColor: color,
    ));
  }

  static void _drawAutonomousHeadingChevron({
    required Canvas canvas,
    required Size size,
    required Bev3DCamera camera,
    required Detected3DObject obj,
    required bool isLight,
    required double cosY,
    required double sinY,
  }) {
    final hl = (obj.length / 2.0) * 0.92;
    final h = obj.height * 0.88;

    final hoodCenterZ = hl * 0.62;
    final hoodY = 0.45 * h;

    final pTip = _transformAndProject(0.0, hoodY, hoodCenterZ + 0.38, obj, cosY, sinY, camera, size);
    final pLeft = _transformAndProject(-0.22, hoodY, hoodCenterZ - 0.16, obj, cosY, sinY, camera, size);
    final pRight = _transformAndProject(0.22, hoodY, hoodCenterZ - 0.16, obj, cosY, sinY, camera, size);

    if (pTip.isVisible && pLeft.isVisible && pRight.isVisible) {
      final chevronPath = Path()
        ..moveTo(pLeft.screenOffset.dx, pLeft.screenOffset.dy)
        ..lineTo(pTip.screenOffset.dx, pTip.screenOffset.dy)
        ..lineTo(pRight.screenOffset.dx, pRight.screenOffset.dy);

      final chevronPaint = Paint()
        ..color = isLight
            ? Colors.white.withValues(alpha: 0.95)
            : const Color(0xFF00E5FF).withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (2.6 / (pTip.depth * 0.28)).clamp(1.2, 3.2)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(chevronPath, chevronPaint);
    }
  }

  static ProjectedPoint _transformAndProject(
    double lx,
    double ly,
    double lz,
    Detected3DObject obj,
    double cosY,
    double sinY,
    Bev3DCamera camera,
    Size size,
  ) {
    final rotX = lx * cosY - lz * sinY;
    final rotZ = lx * sinY + lz * cosY;
    return camera.project(obj.x + rotX, obj.y + ly, obj.z + rotZ, size);
  }
}

/// Definisi Penampang Melintang Mobil di sepanjang sumbu longitudinal (Z)
class _CarStation {
  final double u; // Posisi dari depan (+1.0) ke belakang (-1.0)
  final double yTopCenter;
  final double yTopShoulder;
  final double wTop;
  final double yBelt;
  final double wBelt;
  final double yRocker;
  final double wRocker;
  final bool isWindshield;
  final bool isRoof;
  final bool isRearGlass;

  const _CarStation({
    required this.u,
    required this.yTopCenter,
    required this.yTopShoulder,
    required this.wTop,
    required this.yBelt,
    required this.wBelt,
    required this.yRocker,
    required this.wRocker,
    this.isWindshield = false,
    this.isRoof = false,
    this.isRearGlass = false,
  });
}

class _ProjectedFace {
  final _MeshFace face;
  final List<Offset> points;
  final double depth;

  const _ProjectedFace({
    required this.face,
    required this.points,
    required this.depth,
  });
}
