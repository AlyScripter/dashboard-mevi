import 'dart:math' as math;
import 'package:flutter/material.dart';

class RadarWidget extends StatefulWidget {
  final List<double> lidarDataMeters; // processed from websocket (meters)
  final double rangeMaxMeters;

  const RadarWidget({
    super.key,
    required this.lidarDataMeters,
    required this.rangeMaxMeters,
  });

  @override
  State<RadarWidget> createState() => _RadarWidgetState();
}

class _RadarWidgetState extends State<RadarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6), // Lebih slow dan smooth
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.96, // Range pulse yang lebih subtle
      end: 1.04,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final radarSize = math.min(size.width, size.height) * 0.60;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => CustomPaint(
        size: Size(radarSize, radarSize),
        painter: PulseOnlyRadarPainter(
          distancesMeters: widget.lidarDataMeters,
          rangeMaxMeters: widget.rangeMaxMeters,
          pulseScale: _pulse.value,
        ),
      ),
    );
  }
}

class PulseOnlyRadarPainter extends CustomPainter {
  final List<double> distancesMeters;
  final double rangeMaxMeters;
  final double pulseScale;

  PulseOnlyRadarPainter({
    required this.distancesMeters,
    required this.rangeMaxMeters,
    required this.pulseScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) * 0.95;

    // Background circle yang clean
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.greenAccent.withValues(alpha: 0.15);
    canvas.drawCircle(center, radius, bgPaint);

    // Grid circles yang minimal
    for (int i = 1; i <= 3; i++) {
      final gridRadius = radius * (i / 3);
      final gridPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = Colors.greenAccent.withValues(alpha: 0.1);
      canvas.drawCircle(center, gridRadius, gridPaint);
    }

    // Subtle pulse ring
    final pulsePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.greenAccent.withValues(alpha: 0.2);
    canvas.drawCircle(center, radius * pulseScale, pulsePaint);

    // Clean center dot
    final centerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.greenAccent.withValues(alpha: 0.6);
    canvas.drawCircle(center, 2.0, centerPaint);

    // Clean LiDAR points - no glow, simple dots
    final pointPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.redAccent.withValues(alpha: 0.8);

    final n = distancesMeters.length;
    if (n == 0 || rangeMaxMeters <= 0) return;

    for (int i = 0; i < n; i++) {
      var d = distancesMeters[i];
      if (!d.isFinite) continue;

      d = d.clamp(0.0, rangeMaxMeters);
      final rPix = (d / rangeMaxMeters) * radius;

      final angleDeg = (360.0 / n) * i;
      final rad = angleDeg * math.pi / 180.0;

      final x = center.dx + rPix * math.cos(rad);
      final y = center.dy + rPix * math.sin(rad);

      // Simple clean dots
      canvas.drawCircle(Offset(x, y), 1.5, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant PulseOnlyRadarPainter oldDelegate) {
    // Sangat restrictive repaint untuk mengurangi flickering
    if (oldDelegate.distancesMeters.length != distancesMeters.length) {
      return true;
    }

    if ((oldDelegate.rangeMaxMeters - rangeMaxMeters).abs() > 0.2) {
      return true;
    }

    // Hanya repaint jika pulse berubah signifikan
    if ((oldDelegate.pulseScale - pulseScale).abs() < 0.1) {
      return false;
    }

    // Hanya repaint jika ada perubahan data yang besar (> 20cm)
    for (int i = 0; i < distancesMeters.length; i++) {
      if ((oldDelegate.distancesMeters[i] - distancesMeters[i]).abs() > 0.2) {
        return true;
      }
    }

    return true; // Default repaint untuk pulse animation yang smooth
  }
}
