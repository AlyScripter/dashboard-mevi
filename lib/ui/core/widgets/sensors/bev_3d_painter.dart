import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'bev_3d_camera.dart';
import 'models/detected_3d_object.dart';
import 'models/bev_scenario_type.dart';

/// Data titik sampel jalur jalan 3D (centerline, normal, tangen, dan jarak kumulatif).
class _RoadSample {
  final double cx;
  final double cz;
  final double nx;
  final double nz;
  final double tx;
  final double tz;
  final double distanceAlongPath;

  const _RoadSample({
    required this.cx,
    required this.cz,
    required this.nx,
    required this.nz,
    required this.tx,
    required this.tz,
    required this.distanceAlongPath,
  });
}

/// Painter 3D berkinerja tinggi untuk merender pemandangan jalan 3D luas berperspektif BEV
/// (seperti visual 9.jpg), marka multi-lajur lapang, pita trajektori waypoint cyan bercahaya,
/// serta 3D Bounding Box kubus kawat dengan floating badges.
class Bev3DPainter extends CustomPainter {
  final Bev3DCamera camera;
  final BevScenarioType scenario;
  final double steeringAngle;
  final double speed;
  final double animationValue;
  final List<Detected3DObject> detectedObjects;
  final bool isLight;
  final List<Offset>? liveWaypoints;
  final bool isLiveMode;
  final double? liveWaypointsEndDistance;
  final Map<String, dynamic>? liveRoadScene;

  Bev3DPainter({
    required this.camera,
    required this.scenario,
    required this.steeringAngle,
    required this.speed,
    required this.animationValue,
    required this.detectedObjects,
    required this.isLight,
    this.liveWaypoints,
    this.isLiveMode = false,
    this.liveWaypointsEndDistance,
    this.liveRoadScene,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Latar Belakang Langit & Horizon Lapang (berada di bawah Speedometer & HUD Banner)
    final farPoint = camera.project(0.0, 0.0, 42.0, size);
    final horizonY = farPoint.isVisible
        ? farPoint.screenOffset.dy.clamp(195.0, size.height * 0.35)
        : size.height * 0.28;

    _drawSkyAndGround(canvas, size, horizonY);

    // Cek apakah data jalan atau waypoint riil sudah tersedia
    final hasRealRoadScene = liveRoadScene != null &&
        liveRoadScene!['road'] is Map &&
        ((liveRoadScene!['road']['p'] as List?)?.isNotEmpty ?? false);
    final hasLiveWaypoints = liveWaypoints != null && liveWaypoints!.length >= 2;

    // Sesuai permintaan user: Jika data belum masuk (saat halaman BEV baru dibuka),
    // jangan render visualisasi jalan lurus buatan maupun waypoint, cukup mobil MEVI saja.
    // Jalan & waypoint hanya dirender jika ada data riil yang masuk, atau jika bukan live mode.
    final shouldRenderRoad = hasRealRoadScene || (!isLiveMode && scenario != BevScenarioType.straight);
    final shouldRenderTrajectory = hasLiveWaypoints || (!isLiveMode && scenario != BevScenarioType.straight);

    final samples = (shouldRenderRoad || shouldRenderTrajectory)
        ? _generateRoadSamples()
        : const <_RoadSample>[];

    // 2. Jaringan Jalan 3D (Hanya dirender bila data segmentasi nyata tersedia)
    if (shouldRenderRoad && (hasRealRoadScene || samples.isNotEmpty)) {
      _draw3DRoadNetwork(canvas, size, horizonY, samples);
    }

    // 3. Pita Trajektori Navigasi Otonom (Hanya bila waypoints riil masuk)
    if (shouldRenderTrajectory && samples.isNotEmpty) {
      _drawAutonomousTrajectoryRibbon(canvas, size, samples);
    }

    // 4. 3D Bounding Boxes untuk Objek Terdeteksi
    if (detectedObjects.isNotEmpty) {
      _draw3DDetectedBoundingBoxes(canvas, size);
    }
  }

  void _drawSkyAndGround(Canvas canvas, Size size, double horizonY) {
    // Mode Terang: Latar abu-abu muda elegan khas autonomous vehicle (Tesla / Waymo / Streetscape style)
    // Mode Gelap: Sleek dark cockpit cockpit tone
    final skyRect = Rect.fromLTRB(0, 0, size.width, horizonY);
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isLight
            ? const [Color(0xFFE2E8F0), Color(0xFFEDF2F7)]
            : const [Color(0xFF0A0F18), Color(0xFF0F1722)],
      ).createShader(skyRect);
    canvas.drawRect(skyRect, skyPaint);

    final groundRect = Rect.fromLTRB(0, horizonY, size.width, size.height);
    final groundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isLight
            ? const [Color(0xFFEDF2F7), Color(0xFFE2E8F0)]
            : const [Color(0xFF0F1722), Color(0xFF0A0F18)],
      ).createShader(groundRect);
    canvas.drawRect(groundRect, groundPaint);
  }

  /// Menghasilkan titik-titik sampel centerline, normal, dan tangen jalan.
  /// Untuk skenario Belok Kanan dan Belok Kiri, membentuk tikungan tajam 90° yang kompak
  /// dan realistis sesuai dengan kontur jalan lingkungan kampus/institusi (BRIN).
  List<_RoadSample> _generateRoadSamples() {
    if (isLiveMode && liveWaypoints != null && liveWaypoints!.length >= 2) {
      final liveSamples = _generateRoadSamplesFromLiveWaypoints(liveWaypoints!);
      if (liveSamples.isNotEmpty) return liveSamples;
    }

    final isSharpTurn =
        scenario == BevScenarioType.rightTurn ||
        scenario == BevScenarioType.leftTurn;

    if (!isSharpTurn) {
      final curveFactor = (steeringAngle / 35.0).clamp(-1.0, 1.0) * 0.0028;
      const maxZ = 42.0;
      const stepZ = 0.8;
      final samples = <_RoadSample>[];
      double dist = 0.0;
      double? prevX, prevZ;

      for (double z = -1.6; z <= maxZ; z += stepZ) {
        final cx = curveFactor * (z * z);
        final cz = z;
        const eps = 0.4;
        final dx =
            curveFactor * ((z + eps) * (z + eps)) -
            curveFactor * ((z - eps) * (z - eps));
        final angle = math.atan2(dx, 2 * eps);
        final tx = math.sin(angle);
        final tz = math.cos(angle);
        final nx = math.cos(angle);
        final nz = -math.sin(angle);

        if (prevX != null && prevZ != null) {
          dist += math.sqrt(
            (cx - prevX) * (cx - prevX) + (cz - prevZ) * (cz - prevZ),
          );
        }
        prevX = cx;
        prevZ = cz;

        samples.add(
          _RoadSample(
            cx: cx,
            cz: cz,
            nx: nx,
            nz: nz,
            tx: tx,
            tz: tz,
            distanceAlongPath: dist,
          ),
        );
      }
      return samples;
    }

    // Tikungan Tajam 90 Derajat Kontur Jalan Lingkungan BRIN (KST Samaun Samadikun)
    final dir = (scenario == BevScenarioType.rightTurn) ? 1.0 : -1.0;
    const rRadius = 8.0; // Radius belokan tikungan jalan kampus yang proporsional
    const zStart = 11.5; // Titik awal mulai membelok (setelah pendekatan lurus)
    const branchLen = 16.0; // Panjang jalan cabang horizontal setelah belok 90°

    final samples = <_RoadSample>[];
    double dist = 0.0;
    double? prevX, prevZ;

    void addSample(
      double cx,
      double cz,
      double nx,
      double nz,
      double tx,
      double tz,
    ) {
      if (prevX != null && prevZ != null) {
        dist += math.sqrt(
          (cx - prevX!) * (cx - prevX!) + (cz - prevZ!) * (cz - prevZ!),
        );
      }
      prevX = cx;
      prevZ = cz;
      samples.add(
        _RoadSample(
          cx: cx,
          cz: cz,
          nx: nx,
          nz: nz,
          tx: tx,
          tz: tz,
          distanceAlongPath: dist,
        ),
      );
    }

    // 1. Pendekatan lurus dari mobil ego
    for (double z = -1.6; z < zStart; z += 0.4) {
      addSample(0.0, z, 1.0, 0.0, 0.0, 1.0);
    }

    // 2. Busur belokan 90 derajat tajam yang mulus
    const stepsArc = 32;
    for (int i = 0; i <= stepsArc; i++) {
      final phi = (math.pi / 2.0) * (i / stepsArc);
      final cx = dir * rRadius * (1.0 - math.cos(phi));
      final cz = zStart + rRadius * math.sin(phi);
      final nx = math.cos(phi);
      final nz = -dir * math.sin(phi);
      final tx = dir * math.sin(phi);
      final tz = math.cos(phi);
      addSample(cx, cz, nx, nz, tx, tz);
    }

    // 3. Koridor jalan horizontal setelah belokan 90 derajat
    final cxEnd = dir * rRadius;
    final czEnd = zStart + rRadius;
    for (double d = 0.4; d <= branchLen; d += 0.4) {
      final cx = cxEnd + dir * d;
      final cz = czEnd;
      addSample(cx, cz, 0.0, -dir, dir, 0.0);
    }

    return samples;
  }

  /// Menghasilkan titik sampel jalan 3D adaptif dari waypoints live ROS (Metode 1: Waypoint-Corridor Extrusion).
  /// Menggunakan urutan asli trajectory, smoothing multi-pass, interpolasi busur kontinu Catmull-Rom,
  /// ekstrapolasi tangen alami tanpa clamping artifisial, dan vektor normal ortogonal presisi.
  List<_RoadSample> _generateRoadSamplesFromLiveWaypoints(List<Offset> waypoints) {
    // 1. Ekstraksi titik valid dengan mempertahankan urutan sekuensial asli planner
    final validPts = <Offset>[];
    for (final p in waypoints) {
      if (p.dx.isFinite && p.dy.isFinite) {
        if (validPts.isEmpty) {
          validPts.add(p);
        } else {
          final prev = validPts.last;
          final d = (p - prev).distance;
          // Abaikan titik duplikat atau terlalu rapat (< 15cm) agar interpolasi stabil
          if (d >= 0.15) {
            validPts.add(p);
          }
        }
      }
    }
    if (validPts.length < 2) return const [];

    // 2. Hubungkan secara mulus dari posisi mobil ego (z = -1.6m di bawah bodi MEVI)
    final controlPoints = <Offset>[];
    final firstWp = validPts.first;
    if (firstWp.dy > -1.2) {
      controlPoints.add(const Offset(0.0, -1.6));
      if (firstWp.dy > 0.6) {
        controlPoints.add(Offset(firstWp.dx * 0.35, 0.0));
      }
    }
    controlPoints.addAll(validPts);

    // 3. Penghalusan kurva (Weighted 3-point Gaussian Filter) untuk meratakan jitter planner
    final smoothed = List<Offset>.from(controlPoints);
    for (int pass = 0; pass < 2; pass++) {
      for (int i = 1; i < smoothed.length - 1; i++) {
        final prev = smoothed[i - 1];
        final cur = smoothed[i];
        final next = smoothed[i + 1];
        smoothed[i] = Offset(
          0.20 * prev.dx + 0.60 * cur.dx + 0.20 * next.dx,
          0.20 * prev.dy + 0.60 * cur.dy + 0.20 * next.dy,
        );
      }
    }

    // 4. Parameterisasi Panjang Busur (Cumulative Arc Length)
    final arcLengths = <double>[0.0];
    for (int i = 1; i < smoothed.length; i++) {
      final segDist = (smoothed[i] - smoothed[i - 1]).distance;
      arcLengths.add(arcLengths.last + math.max(1e-4, segDist));
    }
    // Sesuai permintaan user: Render waypoint visual cukup ~setengah saja agar proporsional
    // dan tidak menjulur terlalu panjang melebihi visualisasi jalan riil.
    final totalPathLength = (arcLengths.last * 0.52).clamp(2.5, arcLengths.last);

    // 5. Resampling Padat & Mulus (Equidistant Arc-Length Catmull-Rom Spline)
    final densePoints = <Offset>[];
    const double stepDist = 0.40; // 40 cm per sampel untuk transisi tikungan yang sangat halus
    int segIdx = 0;

    for (double s = 0.0; s <= totalPathLength; s += stepDist) {
      while (segIdx < arcLengths.length - 2 && arcLengths[segIdx + 1] < s) {
        segIdx++;
      }
      final s0 = arcLengths[segIdx];
      final s1 = arcLengths[segIdx + 1];
      final segLen = s1 - s0;
      final t = segLen > 1e-4 ? ((s - s0) / segLen).clamp(0.0, 1.0) : 0.0;

      final cp0 = segIdx > 0 ? smoothed[segIdx - 1] : smoothed[segIdx];
      final cp1 = smoothed[segIdx];
      final cp2 = smoothed[segIdx + 1];
      final cp3 = segIdx + 2 < smoothed.length
          ? smoothed[segIdx + 2]
          : smoothed[segIdx + 1];

      final t2 = t * t;
      final t3 = t2 * t;

      final x = 0.5 * (
        (2.0 * cp1.dx) +
        (-cp0.dx + cp2.dx) * t +
        (2.0 * cp0.dx - 5.0 * cp1.dx + 4.0 * cp2.dx - cp3.dx) * t2 +
        (-cp0.dx + 3.0 * cp1.dx - 3.0 * cp2.dx + cp3.dx) * t3
      );
      final z = 0.5 * (
        (2.0 * cp1.dy) +
        (-cp0.dy + cp2.dy) * t +
        (2.0 * cp0.dy - 5.0 * cp1.dy + 4.0 * cp2.dy - cp3.dy) * t2 +
        (-cp0.dy + 3.0 * cp1.dy - 3.0 * cp2.dy + cp3.dy) * t3
      );

      densePoints.add(Offset(x, z));
    }

    // 6. Tidak melakukan ekstrapolasi liar ke depan agar pita waypoint tetap berada
    // di dalam jangkauan jalan segmentasi riil yang terlihat.

    // 7. Konstruksi Sampel Jalan dengan Vektor Tangen & Normal Ortogonal yang Dihaluskan
    final rawTangents = <Offset>[];
    for (int i = 0; i < densePoints.length; i++) {
      double tx, tz;
      if (i > 0 && i < densePoints.length - 1) {
        final prevP = densePoints[i - 1];
        final nextP = densePoints[i + 1];
        final dx = nextP.dx - prevP.dx;
        final dz = nextP.dy - prevP.dy;
        final len = math.sqrt(dx * dx + dz * dz);
        tx = len > 1e-5 ? dx / len : 0.0;
        tz = len > 1e-5 ? dz / len : 1.0;
      } else if (i < densePoints.length - 1) {
        final nextP = densePoints[i + 1];
        final dx = nextP.dx - densePoints[i].dx;
        final dz = nextP.dy - densePoints[i].dy;
        final len = math.sqrt(dx * dx + dz * dz);
        tx = len > 1e-5 ? dx / len : 0.0;
        tz = len > 1e-5 ? dz / len : 1.0;
      } else {
        final prevP = densePoints[i - 1];
        final dx = densePoints[i].dx - prevP.dx;
        final dz = densePoints[i].dy - prevP.dy;
        final len = math.sqrt(dx * dx + dz * dz);
        tx = len > 1e-5 ? dx / len : 0.0;
        tz = len > 1e-5 ? dz / len : 1.0;
      }
      rawTangents.add(Offset(tx, tz));
    }

    // Filter perataan vektor tangen agar transisi normal di tikungan benar-benar kontinu
    final smoothedTangents = <Offset>[];
    for (int i = 0; i < rawTangents.length; i++) {
      if (i == 0 || i == rawTangents.length - 1) {
        smoothedTangents.add(rawTangents[i]);
      } else {
        final t0 = rawTangents[i - 1];
        final t1 = rawTangents[i];
        final t2 = rawTangents[i + 1];
        final avgX = 0.25 * t0.dx + 0.50 * t1.dx + 0.25 * t2.dx;
        final avgZ = 0.25 * t0.dy + 0.50 * t1.dy + 0.25 * t2.dy;
        final len = math.sqrt(avgX * avgX + avgZ * avgZ);
        smoothedTangents.add(len > 1e-5 ? Offset(avgX / len, avgZ / len) : t1);
      }
    }

    final samples = <_RoadSample>[];
    double totalDist = 0.0;
    Offset? prevPt;

    for (int i = 0; i < densePoints.length; i++) {
      final cur = densePoints[i];
      final tx = smoothedTangents[i].dx;
      final tz = smoothedTangents[i].dy;

      // Vektor normal tegak lurus mengarah ke kanan jalan (+x)
      final nx = tz;
      final nz = -tx;

      if (prevPt != null) {
        totalDist += (cur - prevPt).distance;
      }
      prevPt = cur;

      samples.add(
        _RoadSample(
          cx: cur.dx,
          cz: cur.dy,
          nx: nx,
          nz: nz,
          tx: tx,
          tz: tz,
          distanceAlongPath: totalDist,
        ),
      );
    }

    return samples;
  }

  _RoadSample _sampleAtDistance(List<_RoadSample> samples, double dist) {
    if (dist <= samples.first.distanceAlongPath) return samples.first;
    if (dist >= samples.last.distanceAlongPath) return samples.last;

    int low = 0, high = samples.length - 1;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (samples[mid].distanceAlongPath < dist) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    final idx = low.clamp(1, samples.length - 1);
    final prev = samples[idx - 1];
    final next = samples[idx];
    final segLen = next.distanceAlongPath - prev.distanceAlongPath;
    final t = segLen > 1e-4
        ? ((dist - prev.distanceAlongPath) / segLen).clamp(0.0, 1.0)
        : 0.0;

    return _RoadSample(
      cx: prev.cx + (next.cx - prev.cx) * t,
      cz: prev.cz + (next.cz - prev.cz) * t,
      nx: prev.nx + (next.nx - prev.nx) * t,
      nz: prev.nz + (next.nz - prev.nz) * t,
      tx: prev.tx + (next.tx - prev.tx) * t,
      tz: prev.tz + (next.tz - prev.tz) * t,
      distanceAlongPath: dist,
    );
  }

  /// Mencari titik perpotongan antara dua segmen garis 2D (p1-p2) dan (p3-p4).
  Offset? _findSegmentIntersection(Offset p1, Offset p2, Offset p3, Offset p4) {
    final d1x = p2.dx - p1.dx;
    final d1z = p2.dy - p1.dy;
    final d2x = p4.dx - p3.dx;
    final d2z = p4.dy - p3.dy;

    final cross = d1x * d2z - d1z * d2x;
    if (cross.abs() < 1e-7) return null; // Segmen sejajar atau kolinear

    final dx = p3.dx - p1.dx;
    final dz = p3.dy - p1.dy;

    final t = (dx * d2z - dz * d2x) / cross;
    final u = (dx * d1z - dz * d1x) / cross;

    // Titik potong strictly di dalam kedua segmen
    if (t >= 0.001 && t <= 0.999 && u >= 0.001 && u <= 0.999) {
      return Offset(p1.dx + t * d1x, p1.dy + t * d1z);
    }
    return null;
  }

  /// Menghilangkan lipatan / self-intersection loops (swallowtail) pada polyline batas jalan.
  /// Memotong seluruh titik di dalam loop tertutup dan menggantinya dengan titik potong persimpangan yang rapi.
  List<Offset> _untanglePolyline(List<Offset> pts) {
    if (pts.length < 4) return pts;
    var result = List<Offset>.from(pts);

    bool changed = true;
    int maxPasses = 10;
    while (changed && maxPasses > 0) {
      changed = false;
      maxPasses--;

      for (int i = 0; i < result.length - 3; i++) {
        final p1 = result[i];
        final p2 = result[i + 1];

        // Cari perpotongan dengan segmen ke depan mulai dari segmen terujung
        // untuk langsung memotong loop terbesar dalam satu irisan bersih
        for (int j = result.length - 2; j >= i + 2; j--) {
          final p3 = result[j];
          final p4 = result[j + 1];

          final inter = _findSegmentIntersection(p1, p2, p3, p4);
          if (inter != null) {
            final newPts = <Offset>[];
            for (int k = 0; k <= i; k++) {
              newPts.add(result[k]);
            }
            newPts.add(inter);
            for (int k = j + 1; k < result.length; k++) {
              newPts.add(result[k]);
            }
            result = newPts;
            changed = true;
            break;
          }
        }
        if (changed) break;
      }
    }

    return result;
  }

  /// Memfilter titik-titik yang membalik arah (retrograde) atau berdempetan rapat
  /// agar tidak ada spike patah di tikungan.
  List<Offset> _filterRetrogradePoints(List<Offset> pts) {
    if (pts.length < 3) return pts;
    final filtered = <Offset>[pts.first];

    for (int i = 1; i < pts.length; i++) {
      final p = pts[i];
      final prev = filtered.last;
      final dist = (p - prev).distance;

      // Abaikan titik yang terlalu berdekatan (< 4 cm)
      if (dist < 0.04) continue;

      // Cek apakah ada spike patah membalik arah tajam (> 135 derajat)
      if (filtered.length >= 2 && i < pts.length - 1) {
        final prevPrev = filtered[filtered.length - 2];
        final v1 = prev - prevPrev;
        final v2 = p - prev;
        final dot = v1.dx * v2.dx + v1.dy * v2.dy;
        final l1 = v1.distance;
        final l2 = v2.distance;
        if (l1 > 1e-4 && l2 > 1e-4) {
          final cosA = dot / (l1 * l2);
          if (cosA < -0.70) {
            continue; // Lewati spike balik arah
          }
        }
      }

      filtered.add(p);
    }

    if (filtered.length < 2) return pts;
    return filtered;
  }

  /// Menghaluskan polyline batas jalan menggunakan Chaikin corner cutting & Gaussian smoothing
  /// untuk menciptakan sudut fillet lengkung yang bulat dan mulus (tanpa lipatan / patahan).
  List<Offset> _smoothBoundaryPolyline(List<Offset> pts) {
    if (pts.length < 4) return pts;

    // 1 pass Chaikin corner cutting untuk membulatkan lekukan sudut
    final chaikin = <Offset>[pts.first];
    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i];
      final p1 = pts[i + 1];
      chaikin.add(Offset(0.75 * p0.dx + 0.25 * p1.dx, 0.75 * p0.dy + 0.25 * p1.dy));
      chaikin.add(Offset(0.25 * p0.dx + 0.75 * p1.dx, 0.25 * p0.dy + 0.75 * p1.dy));
    }
    chaikin.add(pts.last);

    // 2 pass Gaussian weighted moving average (0.20, 0.60, 0.20)
    var cur = chaikin;
    for (int pass = 0; pass < 2; pass++) {
      final next = List<Offset>.from(cur);
      for (int i = 1; i < cur.length - 1; i++) {
        final p0 = cur[i - 1];
        final p1 = cur[i];
        final p2 = cur[i + 1];
        next[i] = Offset(
          0.20 * p0.dx + 0.60 * p1.dx + 0.20 * p2.dx,
          0.20 * p0.dy + 0.60 * p1.dy + 0.20 * p2.dy,
        );
      }
      cur = next;
    }

    return cur;
  }

  /// Menghasilkan koordinat 3D batas jalan (x, z) mulus yang bebas dari lipatan
  List<Offset> _generateSmoothBoundary3D(
    List<_RoadSample> samples,
    double offsetDist,
  ) {
    if (samples.length < 2) return const [];

    // 1. Ekstraksi koordinat mentah offset di ground plane dunia (x, z)
    final rawPts = <Offset>[];
    for (final s in samples) {
      rawPts.add(Offset(
        s.cx + offsetDist * s.nx,
        s.cz + offsetDist * s.nz,
      ));
    }

    // 2. Hilangkan lipatan / self-intersection loops (swallowtail loop clipping)
    final untangled = _untanglePolyline(rawPts);

    // 3. Filter titik balik arah liar (retrograde / spike filter)
    final filtered = _filterRetrogradePoints(untangled);

    // 4. Penghalusan kurva sudut (Chaikin subdivision & Gaussian fillet smoothing)
    final smoothed = _smoothBoundaryPolyline(filtered);

    return smoothed;
  }

  /// Memproyeksikan titik ground (x, z) ke koordinat layar 2D
  List<Offset> _projectPolyline(
    List<Offset> groundPoints,
    Size size, {
    double y = 0.0,
  }) {
    final screenPts = <Offset>[];
    for (final pt in groundPoints) {
      final p = camera.project(pt.dx, y, pt.dy, size);
      if (p.isVisible) {
        screenPts.add(p.screenOffset);
      }
    }
    return screenPts;
  }

  void _draw3DRoadNetwork(
    Canvas canvas,
    Size size,
    double horizonY,
    List<_RoadSample> samples,
  ) {
    // 1. Jika data segmentasi jalan riil dari /bev/scene tersedia, gambar poligon nyata!
    if (isLiveMode && liveRoadScene != null) {
      final roadData = liveRoadScene!['road'];
      if (roadData is Map && roadData['p'] is List && (roadData['p'] as List).isNotEmpty) {
        _drawSegmentedRoadScene(canvas, size, horizonY, roadData);
        return;
      }
    }

    // Lebar jalan proporsional 5.6m (total lebar 11.2m) agar seluruh kendaraan & objek muat di lajur
    const roadHalfWidth = 5.6;

    // Batasi area render jalan agar selalu berada di koridor pandang aman
    // dan tidak menabrak atau merusak panel roda gigi kiri (P-R-N-D) dan tombol aksi kanan
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(92.0, 0, size.width - 92.0, size.height));

    // Ekstraksi garis batas jalan dan marka lajur yang mulus dan bebas lipatan
    final leftRoadPoints = _projectPolyline(
      _generateSmoothBoundary3D(samples, -roadHalfWidth),
      size,
    );
    final rightRoadPoints = _projectPolyline(
      _generateSmoothBoundary3D(samples, roadHalfWidth),
      size,
    );
    final leftLane1Points = _projectPolyline(
      _generateSmoothBoundary3D(samples, -1.8),
      size,
    );
    final rightLane1Points = _projectPolyline(
      _generateSmoothBoundary3D(samples, 1.8),
      size,
    );
    final leftLane2Points = _projectPolyline(
      _generateSmoothBoundary3D(samples, -4.8),
      size,
    );
    final rightLane2Points = _projectPolyline(
      _generateSmoothBoundary3D(samples, 4.8),
      size,
    );

    final roadPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: isLight
            ? const [
                Color(0xFFD0DFEC),
                Color(0xFFDCE7F2),
                Color(0xFFEFF5FB),
              ]
            : const [
                Color(0xFF13202D),
                Color(0xFF0F1924),
                Color(0xFF081018),
              ],
        stops: const [0.0, 0.72, 1.0],
      ).createShader(Rect.fromLTRB(0, horizonY, size.width, size.height));

    final outerShoulderPaint = Paint()
      ..color = isLight
          ? const Color(0xFF42A5F5).withValues(alpha: 0.90)
          : const Color(0xFF29B6F6).withValues(alpha: 0.90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final sideLanePaint = Paint()
      ..color = isLight
          ? const Color(0xFF90CAF9).withValues(alpha: 0.55)
          : const Color(0xFF1E88E5).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    // Topologi Simpang Pertigaan (panjang cabang aman dari menu samping)
    if (!isLiveMode && scenario == BevScenarioType.tJunction) {
      _drawIntersectionBranchRoads(canvas, size, roadPaint, outerShoulderPaint);
    }

    // Gambar Permukaan Jalan Utama
    if (leftRoadPoints.length > 2 && rightRoadPoints.length > 2) {
      final roadPath = Path();
      roadPath.moveTo(leftRoadPoints.first.dx, leftRoadPoints.first.dy);
      for (final p in leftRoadPoints) {
        roadPath.lineTo(p.dx, p.dy);
      }
      for (int i = rightRoadPoints.length - 1; i >= 0; i--) {
        roadPath.lineTo(rightRoadPoints[i].dx, rightRoadPoints[i].dy);
      }
      roadPath.close();
      canvas.drawPath(roadPath, roadPaint);

      // Garis Bahu Luar Kiri
      final leftOuter = Path();
      leftOuter.moveTo(leftRoadPoints.first.dx, leftRoadPoints.first.dy);
      for (final p in leftRoadPoints) {
        leftOuter.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(leftOuter, outerShoulderPaint);

      // Garis Bahu Luar Kanan
      final rightOuter = Path();
      rightOuter.moveTo(rightRoadPoints.first.dx, rightRoadPoints.first.dy);
      for (final p in rightRoadPoints) {
        rightOuter.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(rightOuter, outerShoulderPaint);

      // Pembatas Lajur Kiri & Kanan (Ego lane divider)
      if (leftLane1Points.length > 2) {
        final lane = Path()
          ..moveTo(leftLane1Points.first.dx, leftLane1Points.first.dy);
        for (final p in leftLane1Points) {
          lane.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(lane, sideLanePaint);
      }
      if (rightLane1Points.length > 2) {
        final lane = Path()
          ..moveTo(rightLane1Points.first.dx, rightLane1Points.first.dy);
        for (final p in rightLane1Points) {
          lane.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(lane, sideLanePaint);
      }

      // Pembatas Bahu Samping
      if (leftLane2Points.length > 2) {
        final lane = Path()
          ..moveTo(leftLane2Points.first.dx, leftLane2Points.first.dy);
        for (final p in leftLane2Points) {
          lane.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(lane, sideLanePaint);
      }
      if (rightLane2Points.length > 2) {
        final lane = Path()
          ..moveTo(rightLane2Points.first.dx, rightLane2Points.first.dy);
        for (final p in rightLane2Points) {
          lane.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(lane, sideLanePaint);
      }
    }

    // Marka Garis Tengah Putus-Putus
    _draw3DDashedCenterLine(canvas, size, samples);

    canvas.restore();
  }

  void _drawIntersectionBranchRoads(
    Canvas canvas,
    Size size,
    Paint roadPaint,
    Paint shoulderPaint,
  ) {
    const branchZStart = 13.0;
    const branchZEnd = 23.0;
    const branchLength = 10.5; // Panjang cabang aman di area tengah (tidak menabrak widget samping)

    // 1. Cabang Kanan
    final pRightNear = camera.project(5.6, 0.0, branchZStart, size);
    final pRightFar = camera.project(5.6, 0.0, branchZEnd, size);
    final pRightBranchNear = camera.project(
      branchLength,
      0.0,
      branchZStart,
      size,
    );
    final pRightBranchFar = camera.project(branchLength, 0.0, branchZEnd, size);

    if (pRightNear.isVisible && pRightBranchNear.isVisible) {
      final rightBranchPath = Path()
        ..moveTo(pRightNear.screenOffset.dx, pRightNear.screenOffset.dy)
        ..lineTo(
          pRightBranchNear.screenOffset.dx,
          pRightBranchNear.screenOffset.dy,
        )
        ..lineTo(
          pRightBranchFar.screenOffset.dx,
          pRightBranchFar.screenOffset.dy,
        )
        ..lineTo(pRightFar.screenOffset.dx, pRightFar.screenOffset.dy)
        ..close();
      canvas.drawPath(rightBranchPath, roadPaint);

      canvas.drawLine(
        pRightNear.screenOffset,
        pRightBranchNear.screenOffset,
        shoulderPaint,
      );
      canvas.drawLine(
        pRightFar.screenOffset,
        pRightBranchFar.screenOffset,
        shoulderPaint,
      );
    }
  }

  /// Menggambar jalan nyata dari data segmentasi /bev/scene (road.p, road.h)
  /// lengkap dengan permukaan aspal gelap realistis dan pita tepi jalan (curb ribbon) putih/terang.
  void _drawSegmentedRoadScene(
    Canvas canvas,
    Size size,
    double horizonY,
    Map<dynamic, dynamic> road,
  ) {
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(92.0, 0, size.width - 92.0, size.height));

    final pList = road['p'] as List?;
    final hList = road['h'] as List?;
    if (pList == null || pList.isEmpty) {
      canvas.restore();
      return;
    }

    final roadPath = Path()..fillType = PathFillType.evenOdd;
    final curbPath = Path();

    // 1. Gambar poligon luar (perimeter road.p) & filter garis tepi dengan road.q
    final qList = road['q'] as List?;

    for (int k = 0; k < pList.length; k++) {
      final ring = pList[k];
      if (ring is! List || ring.length < 3) continue;

      final projectedPts = <Offset>[];
      for (final pt in ring) {
        if (pt is! List || pt.length < 2) continue;
        final xRos = (pt[0] as num).toDouble();
        final yRos = (pt[1] as num).toDouble();
        // Koordinat 3D Camera: cx = -yRos, cz = xRos, cy = 0.0
        final p = camera.project(-yRos, 0.0, xRos, size);
        if (p.isVisible) {
          projectedPts.add(p.screenOffset);
        }
      }

      if (projectedPts.length >= 3) {
        roadPath.moveTo(projectedPts.first.dx, projectedPts.first.dy);
        for (int i = 1; i < projectedPts.length; i++) {
          roadPath.lineTo(projectedPts[i].dx, projectedPts[i].dy);
        }
        roadPath.close();

        // Garis tepi putih: Hanya sisi berbukti di mana q[i] == '0' && q[j] == '0' (Aturan R3)
        // Tanpa q -> semua sisi dianggap berbukti
        final qStr = (qList != null && k < qList.length && qList[k] is String)
            ? qList[k] as String
            : null;

        for (int i = 0; i < projectedPts.length; i++) {
          final j = (i + 1) % projectedPts.length;
          final isProvenEdge = qStr == null ||
              (i < qStr.length && j < qStr.length && qStr[i] == '0' && qStr[j] == '0');
          if (isProvenEdge) {
            curbPath.moveTo(projectedPts[i].dx, projectedPts[i].dy);
            curbPath.lineTo(projectedPts[j].dx, projectedPts[j].dy);
          }
        }
      }
    }

    // 2. Gambar lubang / pulau jalan nyata (holes road.h)
    // Sisi lubang (h) selalu berbukti (Aturan R3)
    if (hList != null && hList.isNotEmpty) {
      for (final hole in hList) {
        if (hole is! List || hole.length < 3) continue;

        final holePts = <Offset>[];
        for (final pt in hole) {
          if (pt is! List || pt.length < 2) continue;
          final xRos = (pt[0] as num).toDouble();
          final yRos = (pt[1] as num).toDouble();
          final p = camera.project(-yRos, 0.0, xRos, size);
          if (p.isVisible) {
            holePts.add(p.screenOffset);
          }
        }

        if (holePts.length >= 3) {
          roadPath.moveTo(holePts.first.dx, holePts.first.dy);
          for (int i = 1; i < holePts.length; i++) {
            roadPath.lineTo(holePts[i].dx, holePts[i].dy);
          }
          roadPath.close();

          for (int i = 0; i < holePts.length; i++) {
            final j = (i + 1) % holePts.length;
            curbPath.moveTo(holePts[i].dx, holePts[i].dy);
            curbPath.lineTo(holePts[j].dx, holePts[j].dy);
          }
        }
      }
    }

    // 3. Permukaan Aspal Nyata (Realistic Asphalt Shader dengan gradasi perspektif dalam)
    // Warna aspal pekat realistis (#323946 di mode siang / #1A202C di mode gelap)
    final roadPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: isLight
            ? const [
                Color(0xFF38414E), // aspal pekat dekat mobil
                Color(0xFF454F5E), // aspal tengah
                Color(0xFF566273), // horizon blend
              ]
            : const [
                Color(0xFF1E2530),
                Color(0xFF262F3C),
                Color(0xFF323B4A),
              ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTRB(0, horizonY, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(roadPath, roadPaint);

    // 4. Lapisan Inferred Region (ir) jika ada
    final irList = road['ir'] as List?;
    if (irList != null && irList.isNotEmpty) {
      final irPath = Path()..fillType = PathFillType.evenOdd;
      for (final r in irList) {
        if (r is! List || r.length < 3) continue;
        final irPts = <Offset>[];
        for (final pt in r) {
          if (pt is! List || pt.length < 2) continue;
          final xRos = (pt[0] as num).toDouble();
          final yRos = (pt[1] as num).toDouble();
          final p = camera.project(-yRos, 0.0, xRos, size);
          if (p.isVisible) irPts.add(p.screenOffset);
        }
        if (irPts.length >= 3) {
          irPath.moveTo(irPts.first.dx, irPts.first.dy);
          for (int i = 1; i < irPts.length; i++) {
            irPath.lineTo(irPts[i].dx, irPts[i].dy);
          }
          irPath.close();
        }
      }
      final irPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill;
      canvas.drawPath(irPath, irPaint);
    }

    // 5. Garis tepi jalan / curb ribbon (Putih tebal berbukti ±2.8px, StrokeCap.round)
    final curbPaint = Paint()
      ..color = isLight ? const Color(0xFFFFFFFF) : const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(curbPath, curbPaint);

    canvas.restore();
  }

  void _draw3DDashedCenterLine(
    Canvas canvas,
    Size size,
    List<_RoadSample> samples,
  ) {
    if (samples.length < 2) return;
    const dashLength = 3.5;
    const gapLength = 4.0;
    final cycle = dashLength + gapLength;
    final animOffset = (animationValue * cycle) % cycle;

    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: isLight ? 0.95 : 0.90)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    final totalDist = samples.last.distanceAlongPath;

    for (double dStart = 0.0; dStart < totalDist; dStart += cycle) {
      final d1 = dStart + animOffset;
      final d2 = math.min(d1 + dashLength, totalDist);

      if (d1 >= totalDist) continue;

      final s1 = _sampleAtDistance(samples, d1);
      final s2 = _sampleAtDistance(samples, d2);

      final p1 = camera.project(s1.cx, 0.01, s1.cz, size);
      final p2 = camera.project(s2.cx, 0.01, s2.cz, size);

      if (p1.isVisible && p2.isVisible) {
        final strokeW = (4.8 / (p1.depth * 0.32)).clamp(1.2, 4.8);
        dashPaint.strokeWidth = strokeW;
        canvas.drawLine(p1.screenOffset, p2.screenOffset, dashPaint);
      }
    }
  }

  /// 3. Pita Trajektori Waypoint (Waypoint Path Ribbon mentok sampai dasar layar)
  void _drawAutonomousTrajectoryRibbon(
    Canvas canvas,
    Size size,
    List<_RoadSample> samples,
  ) {
    const ribbonHalfWidth = 1.15;

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(92.0, 0, size.width - 92.0, size.height));

    final ribbonSamples = <_RoadSample>[];
    for (final s in samples) {
      if (!isLiveMode && scenario == BevScenarioType.crossroad && s.cz > 4.1) {
        break;
      }

      double cx = s.cx;
      double cz = s.cz;
      if (!isLiveMode && scenario == BevScenarioType.tJunction && cz > 13.0) {
        final turnProgress = ((cz - 13.0) / 14.0).clamp(0.0, 1.0);
        cx += turnProgress * turnProgress * 3.5;
      }

      ribbonSamples.add(_RoadSample(
        cx: cx,
        cz: cz,
        nx: s.nx,
        nz: s.nz,
        tx: s.tx,
        tz: s.tz,
        distanceAlongPath: s.distanceAlongPath,
      ));
    }

    final leftRibbon = _projectPolyline(
      _generateSmoothBoundary3D(ribbonSamples, -ribbonHalfWidth),
      size,
      y: 0.02,
    );
    final rightRibbon = _projectPolyline(
      _generateSmoothBoundary3D(ribbonSamples, ribbonHalfWidth),
      size,
      y: 0.02,
    );

    if (leftRibbon.length > 2) {
      final ribbonPath = Path();
      ribbonPath.moveTo(leftRibbon.first.dx, leftRibbon.first.dy);
      for (final p in leftRibbon) {
        ribbonPath.lineTo(p.dx, p.dy);
      }
      for (int i = rightRibbon.length - 1; i >= 0; i--) {
        ribbonPath.lineTo(rightRibbon[i].dx, rightRibbon[i].dy);
      }
      ribbonPath.close();

      final ribbonPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: scenario == BevScenarioType.crossroad
              ? [
                  const Color(0xFF00E5FF).withValues(alpha: isLight ? 0.45 : 0.55),
                  const Color(0xFFFF5252).withValues(alpha: isLight ? 0.40 : 0.50),
                  const Color(0xFFFF1744).withValues(alpha: isLight ? 0.55 : 0.65),
                ]
              : [
                  const Color(0xFF00E5FF).withValues(alpha: isLight ? 0.48 : 0.58),
                  const Color(0xFF0091EA).withValues(alpha: isLight ? 0.28 : 0.35),
                  const Color(0xFF0091EA).withValues(alpha: 0.0),
                ],
          stops: const [0.0, 0.70, 1.0],
        ).createShader(Rect.fromLTRB(0, 0, size.width, size.height));
      canvas.drawPath(ribbonPath, ribbonPaint);

      final borderPaint = Paint()
        ..color = scenario == BevScenarioType.crossroad
            ? const Color(0xFFFF5252).withValues(alpha: isLight ? 0.85 : 0.95)
            : const Color(0xFF00B0FF).withValues(alpha: isLight ? 0.85 : 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      final leftBorder = Path();
      leftBorder.moveTo(leftRibbon.first.dx, leftRibbon.first.dy);
      for (final p in leftRibbon) {
        leftBorder.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(leftBorder, borderPaint);

      final rightBorder = Path();
      rightBorder.moveTo(rightRibbon.first.dx, rightRibbon.first.dy);
      for (final p in rightRibbon) {
        rightBorder.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(rightBorder, borderPaint);

      // Garis batas berhenti (Stop Bar) warna merah tegas di depan rintangan
      if (scenario == BevScenarioType.crossroad &&
          leftRibbon.isNotEmpty &&
          rightRibbon.isNotEmpty) {
        final stopLinePaint = Paint()
          ..color = const Color(0xFFFF1744)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(leftRibbon.last, rightRibbon.last, stopLinePaint);
      }

      _drawTrajectoryChevrons(canvas, size, samples);
    }

    canvas.restore();
  }

  void _drawTrajectoryChevrons(
    Canvas canvas,
    Size size,
    List<_RoadSample> samples,
  ) {
    if (samples.isEmpty) return;
    const spacing = 5.0;
    final isStopped = speed <= 0.1 || scenario == BevScenarioType.crossroad;
    final animOffset = isStopped ? 0.0 : (animationValue * spacing) % spacing;
    final totalDist = scenario == BevScenarioType.crossroad
        ? math.min(samples.last.distanceAlongPath, 3.8)
        : samples.last.distanceAlongPath;

    for (double d = 2.0 + animOffset; d < totalDist - 1.0; d += spacing) {
      final s = _sampleAtDistance(samples, d);

      double cx = s.cx;
      double cz = s.cz;
      if (!isLiveMode && scenario == BevScenarioType.tJunction && cz > 13.0) {
        final turnProgress = ((cz - 13.0) / 14.0).clamp(0.0, 1.0);
        cx += turnProgress * turnProgress * 3.5;
      }

      final pCenter = camera.project(cx, 0.03, cz, size);
      final pLeft = camera.project(
        cx - s.tx * 0.65 - s.nx * 0.55,
        0.03,
        cz - s.tz * 0.65 - s.nz * 0.55,
        size,
      );
      final pRight = camera.project(
        cx - s.tx * 0.65 + s.nx * 0.55,
        0.03,
        cz - s.tz * 0.65 + s.nz * 0.55,
        size,
      );

      if (pCenter.isVisible && pLeft.isVisible && pRight.isVisible) {
        final chevronPath = Path()
          ..moveTo(pLeft.screenOffset.dx, pLeft.screenOffset.dy)
          ..lineTo(pCenter.screenOffset.dx, pCenter.screenOffset.dy)
          ..lineTo(pRight.screenOffset.dx, pRight.screenOffset.dy);

        final fade = (1.0 - (d / totalDist)).clamp(0.0, 1.0);
        final chevronPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.90 * fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (3.6 / (pCenter.depth * 0.28)).clamp(1.5, 4.0)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        canvas.drawPath(chevronPath, chevronPaint);
      }
    }
  }



  void _draw3DDetectedBoundingBoxes(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(92.0, 0, size.width - 92.0, size.height));

    final sortedObjects = List<Detected3DObject>.from(detectedObjects)
      ..sort((a, b) => b.z.compareTo(a.z));

    for (final obj in sortedObjects) {
      _drawSingle3DBoundingBox(canvas, size, obj);
    }

    canvas.restore();
  }

  void _drawSingle3DBoundingBox(
    Canvas canvas,
    Size size,
    Detected3DObject obj,
  ) {
    final vertices = camera.projectBoundingBoxVertices(
      centerX: obj.x,
      baseY: obj.y,
      centerZ: obj.z,
      width: obj.width,
      height: obj.height,
      length: obj.length,
      yawDeg: obj.yawDeg,
      viewportSize: size,
    );

    final anyVisible = vertices.any((v) => v.isVisible);
    if (!anyVisible) return;

    final primaryColor = obj.objectClass.primaryColor;

    // A. Tapak Tanah / Bayangan (hanya jika 4 sudut dasar di depan kamera)
    if (vertices[0].isVisible &&
        vertices[1].isVisible &&
        vertices[2].isVisible &&
        vertices[3].isVisible) {
      final groundPath = Path()
        ..moveTo(vertices[0].screenOffset.dx, vertices[0].screenOffset.dy)
        ..lineTo(vertices[1].screenOffset.dx, vertices[1].screenOffset.dy)
        ..lineTo(vertices[2].screenOffset.dx, vertices[2].screenOffset.dy)
        ..lineTo(vertices[3].screenOffset.dx, vertices[3].screenOffset.dy)
        ..close();

      final groundShadowPaint = Paint()
        ..color = primaryColor.withValues(alpha: isLight ? 0.20 : 0.28)
        ..style = PaintingStyle.fill;
      canvas.drawPath(groundPath, groundShadowPaint);
    }

    // B. Kubus Bounding Box 3D Semi-transparan (Gaya Streetscape.gl / AV 3D Bounding Box)
    // Sesuai permintaan user: Objek di dalam box ditiadakan, murni 3D Wireframe Box & Badges.

    // C. Sisi-Sisi Poligon Kubus Pembungkus (Translucent Bounding Cage)
    const faces = [
      [0, 1, 5, 4], // Depan
      [1, 2, 6, 5], // Kanan
      [2, 3, 7, 6], // Belakang
      [3, 0, 4, 7], // Kiri
      [4, 5, 6, 7], // Atas
    ];

    for (int faceIdx = 0; faceIdx < faces.length; faceIdx++) {
      final idxs = faces[faceIdx];
      // Pastikan semua 4 sudut sisi terlihat agar tidak melempar garis artefak ke luar layar
      if (!idxs.every((i) => vertices[i].isVisible)) continue;

      final facePath = Path()
        ..moveTo(
          vertices[idxs[0]].screenOffset.dx,
          vertices[idxs[0]].screenOffset.dy,
        )
        ..lineTo(
          vertices[idxs[1]].screenOffset.dx,
          vertices[idxs[1]].screenOffset.dy,
        )
        ..lineTo(
          vertices[idxs[2]].screenOffset.dx,
          vertices[idxs[2]].screenOffset.dy,
        )
        ..lineTo(
          vertices[idxs[3]].screenOffset.dx,
          vertices[idxs[3]].screenOffset.dy,
        )
        ..close();

      final isTopFace = faceIdx == 4;
      // Tingkat transparansi dinding kubus dibuat halus agar model 3D di dalamnya terlihat jelas
      final alpha = isTopFace
          ? (isLight ? 0.16 : 0.22)
          : (isLight ? 0.08 : 0.14);

      final facePaint = Paint()
        ..color = primaryColor.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      canvas.drawPath(facePath, facePaint);
    }

    // C. Garis Kawat Wireframe
    const edges = [
      [0, 1],
      [1, 2],
      [2, 3],
      [3, 0],
      [4, 5],
      [5, 6],
      [6, 7],
      [7, 4],
      [0, 4],
      [1, 5],
      [2, 6],
      [3, 7],
    ];

    final avgDepth =
        vertices.map((v) => v.depth).reduce((a, b) => a + b) / 8.0;
    final edgeWidth = (3.6 / (avgDepth * 0.28)).clamp(1.5, 3.8);

    final edgePaint = Paint()
      ..color = obj.isDepthOnly
          ? primaryColor.withValues(alpha: isLight ? 0.70 : 0.80)
          : primaryColor.withValues(alpha: isLight ? 0.95 : 1.0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = obj.isDepthOnly ? edgeWidth * 0.9 : edgeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final edge in edges) {
      final p1 = vertices[edge[0]];
      final p2 = vertices[edge[1]];
      // Hanya gambar garis jika KEDUA ujung titik berada di depan kamera
      if (p1.isVisible && p2.isVisible) {
        if (obj.isDepthOnly) {
          _drawDashedScreenLine(canvas, p1.screenOffset, p2.screenOffset, edgePaint);
        } else {
          canvas.drawLine(p1.screenOffset, p2.screenOffset, edgePaint);
        }
      }
    }

    // D. Garis Penunjuk Arah Hadap di Sisi Depan
    final pFrontCenterTop = Offset(
      (vertices[4].screenOffset.dx + vertices[5].screenOffset.dx) / 2.0,
      (vertices[4].screenOffset.dy + vertices[5].screenOffset.dy) / 2.0,
    );
    final pFrontCenterBottom = Offset(
      (vertices[0].screenOffset.dx + vertices[1].screenOffset.dx) / 2.0,
      (vertices[0].screenOffset.dy + vertices[1].screenOffset.dy) / 2.0,
    );

    final headingPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = edgeWidth * 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(pFrontCenterBottom, pFrontCenterTop, headingPaint);
  }

  void _drawDashedScreenLine(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Paint paint,
  ) {
    const dashLength = 6.0;
    const gapLength = 4.0;
    final totalDist = (p2 - p1).distance;
    if (totalDist <= 0.001) return;
    final dx = (p2.dx - p1.dx) / totalDist;
    final dy = (p2.dy - p1.dy) / totalDist;
    double currentDist = 0.0;
    while (currentDist < totalDist) {
      final start = Offset(p1.dx + dx * currentDist, p1.dy + dy * currentDist);
      final endDist = math.min(currentDist + dashLength, totalDist);
      final end = Offset(p1.dx + dx * endDist, p1.dy + dy * endDist);
      canvas.drawLine(start, end, paint);
      currentDist += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant Bev3DPainter oldDelegate) {
    return oldDelegate.scenario != scenario ||
        oldDelegate.steeringAngle != steeringAngle ||
        oldDelegate.speed != speed ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.detectedObjects != detectedObjects ||
        oldDelegate.isLight != isLight ||
        oldDelegate.isLiveMode != isLiveMode ||
        oldDelegate.liveWaypoints != liveWaypoints ||
        oldDelegate.liveWaypointsEndDistance != liveWaypointsEndDistance;
  }
}
