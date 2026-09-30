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

  Bev3DPainter({
    required this.camera,
    required this.scenario,
    required this.steeringAngle,
    required this.speed,
    required this.animationValue,
    required this.detectedObjects,
    required this.isLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Latar Belakang Langit & Horizon Lapang (berada di bawah Speedometer & HUD Banner)
    final farPoint = camera.project(0.0, 0.0, 42.0, size);
    final horizonY = farPoint.isVisible
        ? farPoint.screenOffset.dy.clamp(195.0, size.height * 0.35)
        : size.height * 0.28;

    _drawSkyAndGround(canvas, size, horizonY);

    final samples = _generateRoadSamples();

    // 2. Jaringan Jalan 3D Perspektif Proporsional (Mentok penuh sampai dasar layar)
    _draw3DRoadNetwork(canvas, size, horizonY, samples);

    // 3. Pita Trajektori Navigasi Otonom (Waypoint Path Ribbon mentok sampai bawah layar)
    _drawAutonomousTrajectoryRibbon(canvas, size, samples);

    // 4. 3D Bounding Boxes untuk Objek Terdeteksi
    _draw3DDetectedBoundingBoxes(canvas, size);
  }

  void _drawSkyAndGround(Canvas canvas, Size size, double horizonY) {
    final skyRect = Rect.fromLTRB(0, 0, size.width, horizonY);
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isLight
            ? const [Color(0xFFE0EBF6), Color(0xFFEFF5FB)]
            : const [Color(0xFF081018), Color(0xFF0E1824)],
      ).createShader(skyRect);
    canvas.drawRect(skyRect, skyPaint);

    final groundRect = Rect.fromLTRB(0, horizonY, size.width, size.height);
    final groundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isLight
            ? const [Color(0xFFF3F7FA), Color(0xFFDFE8F1)]
            : const [Color(0xFF0B141F), Color(0xFF050A0E)],
      ).createShader(groundRect);
    canvas.drawRect(groundRect, groundPaint);
  }

  /// Menghasilkan titik-titik sampel centerline, normal, dan tangen jalan.
  /// Untuk skenario Belok Kanan dan Belok Kiri, membentuk tikungan tajam 90° yang kompak
  /// dan realistis sesuai dengan kontur jalan lingkungan kampus/institusi (BRIN).
  List<_RoadSample> _generateRoadSamples() {
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
    const rRadius = 7.0; // Radius belokan tikungan jalan kampus
    const zStart = 11.5; // Titik awal mulai membelok (setelah pendekatan lurus)
    const branchLen = 14.5; // Panjang jalan cabang horizontal setelah belok 90°

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

    // 2. Busur belokan 90 derajat tajam
    const stepsArc = 24;
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

  void _draw3DRoadNetwork(
    Canvas canvas,
    Size size,
    double horizonY,
    List<_RoadSample> samples,
  ) {
    // Lebar jalan terukur 11.2 meter total (-5.6m s/d +5.6m) agar proporsional dan tidak menabrak rail menu kiri & tombol kanan
    const roadHalfWidth = 5.6;

    // Poligon Jalan Utama (dimulai dari z = -1.6m agar mentok penuh sampai ke dasar layar paling bawah)
    final leftRoadPoints = <Offset>[];
    final rightRoadPoints = <Offset>[];
    final leftLane1Points = <Offset>[];
    final rightLane1Points = <Offset>[];
    final leftLane2Points = <Offset>[];
    final rightLane2Points = <Offset>[];

    for (final s in samples) {
      final pLeft = camera.project(
        s.cx - roadHalfWidth * s.nx,
        0.0,
        s.cz - roadHalfWidth * s.nz,
        size,
      );
      final pRight = camera.project(
        s.cx + roadHalfWidth * s.nx,
        0.0,
        s.cz + roadHalfWidth * s.nz,
        size,
      );
      final pLeft1 = camera.project(
        s.cx - 1.8 * s.nx,
        0.0,
        s.cz - 1.8 * s.nz,
        size,
      );
      final pRight1 = camera.project(
        s.cx + 1.8 * s.nx,
        0.0,
        s.cz + 1.8 * s.nz,
        size,
      );
      final pLeft2 = camera.project(
        s.cx - 4.8 * s.nx,
        0.0,
        s.cz - 4.8 * s.nz,
        size,
      );
      final pRight2 = camera.project(
        s.cx + 4.8 * s.nx,
        0.0,
        s.cz + 4.8 * s.nz,
        size,
      );

      if (pLeft.isVisible && pRight.isVisible) {
        leftRoadPoints.add(pLeft.screenOffset);
        rightRoadPoints.add(pRight.screenOffset);
      }
      if (pLeft1.isVisible && pRight1.isVisible) {
        leftLane1Points.add(pLeft1.screenOffset);
        rightLane1Points.add(pRight1.screenOffset);
      }
      if (pLeft2.isVisible && pRight2.isVisible) {
        leftLane2Points.add(pLeft2.screenOffset);
        rightLane2Points.add(pRight2.screenOffset);
      }
    }

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
    if (scenario == BevScenarioType.tJunction) {
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

      // Pembatas Bahu Parkir Samping
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

    final leftRibbon = <Offset>[];
    final rightRibbon = <Offset>[];

    for (final s in samples) {
      if (scenario == BevScenarioType.crossroad && s.cz > 4.1) {
        break;
      }

      double cx = s.cx;
      double cz = s.cz;
      if (scenario == BevScenarioType.tJunction && cz > 13.0) {
        final turnProgress = ((cz - 13.0) / 14.0).clamp(0.0, 1.0);
        cx += turnProgress * turnProgress * 3.5;
      }

      final pLeft = camera.project(
        cx - ribbonHalfWidth * s.nx,
        0.02,
        cz - ribbonHalfWidth * s.nz,
        size,
      );
      final pRight = camera.project(
        cx + ribbonHalfWidth * s.nx,
        0.02,
        cz + ribbonHalfWidth * s.nz,
        size,
      );

      if (pLeft.isVisible && pRight.isVisible) {
        leftRibbon.add(pLeft.screenOffset);
        rightRibbon.add(pRight.screenOffset);
      }
    }

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
      if (scenario == BevScenarioType.tJunction && cz > 13.0) {
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
    final sortedObjects = List<Detected3DObject>.from(detectedObjects)
      ..sort((a, b) => b.z.compareTo(a.z));

    for (final obj in sortedObjects) {
      _drawSingle3DBoundingBox(canvas, size, obj);
    }
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

    // A. Tapak Tanah / Bayangan
    final groundPath = Path()
      ..moveTo(vertices[0].screenOffset.dx, vertices[0].screenOffset.dy)
      ..lineTo(vertices[1].screenOffset.dx, vertices[1].screenOffset.dy)
      ..lineTo(vertices[2].screenOffset.dx, vertices[2].screenOffset.dy)
      ..lineTo(vertices[3].screenOffset.dx, vertices[3].screenOffset.dy)
      ..close();

    final groundShadowPaint = Paint()
      ..color = primaryColor.withValues(alpha: isLight ? 0.24 : 0.32)
      ..style = PaintingStyle.fill;
    canvas.drawPath(groundPath, groundShadowPaint);

    // B. Sisi-Sisi Poligon Kubus
    const faces = [
      [0, 1, 5, 4], // Depan
      [1, 2, 6, 5], // Kanan
      [2, 3, 7, 6], // Belakang
      [3, 0, 4, 7], // Kiri
      [4, 5, 6, 7], // Atas
    ];

    for (int faceIdx = 0; faceIdx < faces.length; faceIdx++) {
      final idxs = faces[faceIdx];
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
      final alpha = isTopFace
          ? (isLight ? 0.28 : 0.38)
          : (isLight ? 0.16 : 0.24);

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

    final avgDepth = vertices.map((v) => v.depth).reduce((a, b) => a + b) / 8.0;
    final edgeWidth = (3.6 / (avgDepth * 0.28)).clamp(1.5, 3.8);

    final edgePaint = Paint()
      ..color = primaryColor.withValues(alpha: isLight ? 0.95 : 1.0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = edgeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final edge in edges) {
      final p1 = vertices[edge[0]];
      final p2 = vertices[edge[1]];
      if (p1.isVisible || p2.isVisible) {
        canvas.drawLine(p1.screenOffset, p2.screenOffset, edgePaint);
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

  @override
  bool shouldRepaint(covariant Bev3DPainter oldDelegate) {
    return oldDelegate.scenario != scenario ||
        oldDelegate.steeringAngle != steeringAngle ||
        oldDelegate.speed != speed ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.detectedObjects != detectedObjects ||
        oldDelegate.isLight != isLight;
  }
}
