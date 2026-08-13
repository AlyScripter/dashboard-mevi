import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:dashboardmevi/services/ros_service.dart';

/// Blue arc speedometer, styled after the reference dashboard's gauge
/// (dark track, glowing blue progress arc, big centered number).
class SpeedDisplayWidget extends StatelessWidget {
  final double maxSpeed;

  const SpeedDisplayWidget({super.key, this.maxSpeed = 120});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: RosService().speedometerRosStream,
      builder: (context, snapshot) {
        final speed = (snapshot.data ?? 20).clamp(0, maxSpeed).toDouble();
        final progress = (speed / maxSpeed).clamp(0.0, 1.0);

        return SizedBox(
          height: 108,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 150,
                height: 92,
                child: CustomPaint(
                  painter: _ArcGaugePainter(progress: progress),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      speed.toInt().toString(),
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Km/h',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.55),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ArcGaugePainter extends CustomPainter {
  final double progress;
  const _ArcGaugePainter({required this.progress});

  static const double _startAngle = 3.4; // ~195deg, in radians
  static const double _sweepAngle = 2.6; // ~150deg

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.width / 2 - 6);
    final radius = (size.width - 12) / 2;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.10);
    canvas.drawArc(arcRect, _startAngle, _sweepAngle, false, trackPaint);

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [Color(0xFF64B5F6), Color(0xFF2196F3)],
        startAngle: _startAngle,
        endAngle: _startAngle + _sweepAngle,
      ).createShader(arcRect);

    canvas.drawArc(
      arcRect,
      _startAngle,
      _sweepAngle * progress,
      false,
      progressPaint,
    );

    if (progress > 0.02) {
      final tipAngle = _startAngle + _sweepAngle * progress;
      final tip = Offset(
        center.dx + radius * math.cos(tipAngle),
        center.dy + radius * math.sin(tipAngle),
      );
      canvas.drawCircle(
        tip,
        6,
        Paint()
          ..color = const Color(0xFF64B5F6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArcGaugePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
