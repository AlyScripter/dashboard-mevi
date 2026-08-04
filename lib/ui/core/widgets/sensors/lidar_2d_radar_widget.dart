import 'dart:math' as math;
import 'package:flutter/material.dart';
// Pastikan import ini sesuai dengan struktur project Anda
import 'package:dashboardmevi/services/ros_service.dart';

/// Visualisasi LiDAR front-only (-40..40 derajat) dengan integrasi ROS.
/// Menggunakan style UI minimalis (pulse tipis, tanpa grid ramai) ala Code 2.
class Lidar2DRadarWidget extends StatefulWidget {
  const Lidar2DRadarWidget({super.key});

  @override
  State<Lidar2DRadarWidget> createState() => _Lidar2DRadarWidgetState();
}

class _Lidar2DRadarWidgetState extends State<Lidar2DRadarWidget>
    with SingleTickerProviderStateMixin {
  final RosService rosService = RosService();

  late AnimationController _pulseController;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    // Menggunakan durasi dan range tween yang sama dengan Code 1 & 2
    // untuk animasi yang pelan dan halus.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 260.0;
        final maxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 260.0;

        final radarSize = math.min(maxWidth, maxHeight).clamp(140.0, 320.0);

        return StreamBuilder<List<double>>(
          stream: rosService.lidarStream,
          builder: (context, lidarSnap) {
            final ranges = lidarSnap.data ?? const <double>[];

            return StreamBuilder<double>(
              stream: rosService.obstacleDistanceStream,
              builder: (context, distSnap) {
                final obstacleDistance = distSnap.data ?? double.infinity;

                return StreamBuilder<String>(
                  stream: rosService.obstaclePositionStream,
                  builder: (context, posSnap) {
                    final obstaclePosition = posSnap.data ?? 'none';

                    return AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) {
                        return SizedBox(
                          width: radarSize,
                          height: radarSize,
                          child: CustomPaint(
                            size: Size(radarSize, radarSize),
                            // Menggunakan Painter yang sudah dimodifikasi UI-nya
                            painter: LidarArcRadarMinimalPainter(
                              lidarRanges: ranges,
                              obstacleDistance: obstacleDistance,
                              obstaclePosition: obstaclePosition,
                              maxRangeMeters: 3.0,
                              pulseScale: _pulse.value,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Painter ini mempertahankan logika Code 1 tapi menggunakan estetika Code 2.
class LidarArcRadarMinimalPainter extends CustomPainter {
  final List<double> lidarRanges;
  final double obstacleDistance;
  final String obstaclePosition;
  final double maxRangeMeters;
  final double pulseScale;

  // Konfigurasi Geometri (Sama seperti Code 1)
  static const double lidarFovDegrees = 240.0;
  static const double lidarMinAngle = -120.0;
  static const double lidarMaxRange = 5.6;
  static const double displayFovMin = -40.0;
  static const double displayFovMax = 40.0;

  const LidarArcRadarMinimalPainter({
    required this.lidarRanges,
    required this.obstacleDistance,
    required this.obstaclePosition,
    required this.maxRangeMeters,
    required this.pulseScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.95);
    final maxRadius = math.min(size.width / 2, size.height * 0.9);

    // 1. Gambar Background yang sudah disederhanakan (ala Code 2)
    _drawMinimalBackgroundArc(canvas, center, maxRadius);

    // (Opsional: Saya hilangkan segment lines juga agar lebih bersih seperti Code 2.
    // Jika ingin dikembalikan, uncomment baris di bawah ini)
    // _drawSegmentLines(canvas, center, maxRadius);

    final hit = _resolveDetectionHit();
    // 2. Gambar titik raw (style sederhana)
    _drawRawPoints(canvas, center, maxRadius, excludeHit: hit);

    // 3. Gambar highlight obstacle jika ada (dibuat lebih subtle)
    if (hit != null && hit.distance.isFinite) {
      _drawDetectionArcSubtle(canvas, center, maxRadius, hit);
      _drawDetectionPointAndLabel(canvas, size, center, maxRadius, hit);
    }
  }

  /// MODIFIED: Background arc yang minimalis ala Code 2.
  /// - Grid 1m, 2m, 3m DIHAPUS.
  /// - Pulse dibuat lebih tipis dan transparan.
  void _drawMinimalBackgroundArc(Canvas canvas, Offset center, double maxRadius) {
    final arcDeg = displayFovMax - displayFovMin;
    final startDeg = -90.0 + displayFovMin;

    // Batas luar arc (dibuat lebih tipis dan samar)
    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 // Lebih tipis dari Code 1 (1.2)
      ..color = Colors.greenAccent.withValues(alpha: 0.10); // Lebih samar

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: maxRadius),
      _degToRad(startDeg),
      _degToRad(arcDeg),
      false,
      outerPaint,
    );

    // --- BAGIAN GRID LOOP DIHAPUS DI SINI ---

    // Pulse ring (dibuat tipis ala Code 2)
    final pulsePaint = Paint()
      ..style = PaintingStyle.stroke
      // Stroke width tipis (1.2) dan alpha rendah (0.15)
      // meniru "Subtle pulse ring" dari Code 2
      ..strokeWidth = 1.2 * pulseScale
      ..color = Colors.greenAccent.withValues(alpha: 0.15);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: maxRadius * pulseScale),
      _degToRad(startDeg),
      _degToRad(arcDeg),
      false,
      pulsePaint,
    );

    // Dot pusat mobil (dibuat sedikit lebih kecil dan bersih)
    final centerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.greenAccent.withValues(alpha: 0.6); // Alpha mirip Code 2
    canvas.drawCircle(center, 2.5, centerPaint);
  }

  // ... (Logika _drawSegmentLines, _drawRawPoints, _resolveDetectionHit,
  //      _findHitNearReportedObstacle, _closestFrontHitFromRaw
  //      SAMA PERSIS dengan Code 1, tidak ada perubahan logika) ...

  void _drawSegmentLines(Canvas canvas, Offset center, double maxRadius) {
    const segmentAngles = [40.0, 30.0, 20.0, 0.0, -20.0, -30.0, -40.0];
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5 // Sedikit lebih tipis
      ..color = Colors.greenAccent.withValues(alpha: 0.15); // Lebih samar

    for (final lidarAngle in segmentAngles) {
      final canvasAngleDeg = -90.0 + lidarAngle;
      final rad = _degToRad(canvasAngleDeg);
      final endX = center.dx + maxRadius * math.cos(rad);
      final endY = center.dy + maxRadius * math.sin(rad);
      canvas.drawLine(center, Offset(endX, endY), linePaint);
    }
  }

  void _drawRawPoints(
      Canvas canvas, Offset center, double maxRadius,
      {_DetectionHit? excludeHit}) {
    if (lidarRanges.isEmpty || maxRangeMeters <= 0) return;
    final len = lidarRanges.length;
    if (len == 0) return;

    final angleIncDeg = lidarFovDegrees / len;
    final startIndex = ((displayFovMin - lidarMinAngle) / angleIncDeg).round();
    final endIndex = ((displayFovMax - lidarMinAngle) / angleIncDeg).round();

    // Style point sederhana ala Code 2
    final pointPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.redAccent.withValues(alpha: 0.8);

    for (int i = startIndex; i <= endIndex && i < len; i++) {
      if (i < 0) continue;
      var d = lidarRanges[i];
      if (!d.isFinite || d <= 0.02 || d > lidarMaxRange || d.isNaN) continue;

      d = d.clamp(0.0, maxRangeMeters);
      final rPix = (d / maxRangeMeters) * maxRadius;

      final lidarAngleDeg = lidarMinAngle + i * angleIncDeg;
      final canvasAngleDeg = -90.0 + lidarAngleDeg;
      final rad = _degToRad(canvasAngleDeg);

      final pos = Offset(center.dx + rPix * math.cos(rad), center.dy + rPix * math.sin(rad));

      if (excludeHit != null) {
        final diffAng = (excludeHit.lidarAngle - lidarAngleDeg).abs();
        final diffDist = (excludeHit.distance - d).abs();
        if (diffAng < 1.0 && diffDist < 0.05) continue;
      }
      // Ukuran dot sedikit diperkecil agar terlihat "clean"
      canvas.drawCircle(pos, 1.5, pointPaint);
    }
  }

  _DetectionHit? _resolveDetectionHit() {
    if (obstaclePosition != 'none' && obstacleDistance.isFinite) {
      final bySegments = _findHitNearReportedObstacle();
      if (bySegments != null) {
        return _DetectionHit(
            distance: obstacleDistance.clamp(0.0, maxRangeMeters),
            lidarAngle: bySegments.lidarAngle);
      }
      final angle = switch (obstaclePosition) {
        'left' => -30.0,
        'right' => 30.0,
        'front' => 0.0,
        _ => 0.0,
      };
      return _DetectionHit(
          distance: obstacleDistance.clamp(0.0, maxRangeMeters),
          lidarAngle: angle);
    }
    return _closestFrontHitFromRaw();
  }

  _DetectionHit? _findHitNearReportedObstacle() {
    if (!obstacleDistance.isFinite || lidarRanges.isEmpty) return null;
    final len = lidarRanges.length;
    if (len == 0) return null;
    final angleIncDeg = lidarFovDegrees / len;
    const angleMinDeg = lidarMinAngle;

    List<double> candidateAngles;
    switch (obstaclePosition) {
      case 'right': candidateAngles = [20.0, 30.0, 40.0]; break;
      case 'left': candidateAngles = [-20.0, -30.0, -40.0]; break;
      case 'front': candidateAngles = [-20.0, 0.0, 20.0]; break;
      default: return null;
    }

    const windowSamples = 3;
    const distanceTolerance = 0.3;
    int? bestIndex;
    double bestDiff = double.infinity;

    int angleToIndex(double angleDeg) => ((angleDeg - angleMinDeg) / angleIncDeg).round();

    for (final baseAngle in candidateAngles) {
      final centerIdx = angleToIndex(baseAngle);
      for (int i = centerIdx - windowSamples; i <= centerIdx + windowSamples; i++) {
        if (i < 0 || i >= len) continue;
        final r = lidarRanges[i];
        if (!r.isFinite || r <= 0.02 || r > lidarMaxRange || r.isNaN) continue;
        final diff = (r - obstacleDistance).abs();
        if (diff < distanceTolerance && diff < bestDiff) {
          bestDiff = diff;
          bestIndex = i;
        }
      }
    }
    if (bestIndex == null) return null;
    return _DetectionHit(distance: lidarRanges[bestIndex], lidarAngle: angleMinDeg + bestIndex * angleIncDeg);
  }

  _DetectionHit? _closestFrontHitFromRaw() {
    if (lidarRanges.isEmpty) return null;
    final len = lidarRanges.length;
    if (len == 0) return null;
    final angleIncDeg = lidarFovDegrees / len;
    final startIndex = ((displayFovMin - lidarMinAngle) / angleIncDeg).round();
    final endIndex = ((displayFovMax - lidarMinAngle) / angleIncDeg).round();

    double? minDistance;
    int minIndex = -1;

    for (int i = startIndex; i <= endIndex && i < len; i++) {
      if (i < 0) continue;
      final r = lidarRanges[i];
      if (r <= 0.02 || r > lidarMaxRange || r.isNaN || r.isInfinite) continue;
      if (minDistance == null || r < minDistance) {
        minDistance = r;
        minIndex = i;
      }
    }
    if (minDistance == null || minIndex < 0) return null;
    return _DetectionHit(distance: minDistance, lidarAngle: lidarMinAngle + minIndex * angleIncDeg);
  }

  /// MODIFIED: Highlight obstacle dibuat lebih subtle (tidak terlalu nge-glow)
  /// agar cocok dengan tema minimalis.
  void _drawDetectionArcSubtle(
    Canvas canvas, Offset center, double maxRadius, _DetectionHit hit) {
    final d = hit.distance.clamp(0.0, maxRangeMeters);
    final rPix = (d / maxRangeMeters) * maxRadius;
    final canvasAngleDeg = -90.0 + hit.lidarAngle;
    const sweepDeg = 26.0;
    final arcRect = Rect.fromCircle(center: center, radius: rPix);
    final startRad = _degToRad(canvasAngleDeg - sweepDeg / 2);
    final sweepRad = _degToRad(sweepDeg);
    final color = _colorForDistance(d);

    // Glow dibuat lebih tipis dan samar
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * pulseScale // Dikurangi dari 7
      ..color = color.withValues(alpha: 0.15 * pulseScale) // Alpha dikurangi dari 0.22
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4); // Blur dikurangi

    canvas.drawArc(arcRect, startRad, sweepRad, false, glowPaint);

    // Garis utama highlight juga sedikit ditipiskan
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 // Dikurangi dari 3
      ..color = color.withValues(alpha: 0.9)
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, startRad, sweepRad, false, arcPaint);
  }

  void _drawDetectionPointAndLabel(
    Canvas canvas, Size size, Offset center, double maxRadius, _DetectionHit hit) {
    final d = hit.distance.clamp(0.0, maxRangeMeters);
    final rPix = (d / maxRangeMeters) * maxRadius;
    final canvasAngleDeg = -90.0 + hit.lidarAngle;
    final rad = _degToRad(canvasAngleDeg);
    final pos = Offset(center.dx + rPix * math.cos(rad), center.dy + rPix * math.sin(rad));
    final color = _colorForDistance(d);

    // Glow point juga dikurangi
    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.25 * pulseScale) // Alpha dikurangi
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4); // Blur dikurangi
    canvas.drawCircle(pos, 6 * pulseScale, glowPaint); // Radius dikurangi

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.98);
    canvas.drawCircle(pos, 4.0, dotPaint); // Radius dikurangi sedikit

    // Label tetap dipertahankan karena penting untuk informasi
    final tp = TextPainter(
      text: TextSpan(
        text: '${d.toStringAsFixed(2)} m',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.95),
          fontSize: 10, // Font size sedikit diperkecil
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const labelOffset = 18.0;
    double lx = pos.dx + labelOffset * math.cos(rad);
    double ly = pos.dy + labelOffset * math.sin(rad);
    ly = ly.clamp(4.0, size.height - tp.height - 4.0);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(lx - tp.width / 2 - 3, ly - tp.height / 2 - 2, tp.width + 6, tp.height + 4),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );
    tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
  }

  Color _colorForDistance(double d) {
    if (d < 1.0) return Colors.redAccent;
    if (d < 2.0) return Colors.orangeAccent;
    return Colors.greenAccent;
  }

  double _degToRad(double degrees) => degrees * math.pi / 180.0;

  @override
  bool shouldRepaint(covariant LidarArcRadarMinimalPainter oldDelegate) {
    return oldDelegate.obstacleDistance != obstacleDistance ||
        oldDelegate.obstaclePosition != obstaclePosition ||
        oldDelegate.pulseScale != pulseScale ||
        oldDelegate.maxRangeMeters != maxRangeMeters ||
        oldDelegate.lidarRanges.length != lidarRanges.length;
  }
}

class _DetectionHit {
  final double distance;
  final double lidarAngle;
  const _DetectionHit({required this.distance, required this.lidarAngle});
}