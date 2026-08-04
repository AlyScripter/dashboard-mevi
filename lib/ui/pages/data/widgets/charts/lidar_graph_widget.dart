import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../../../services/ros_service.dart';

class LidarGraphWidget extends StatelessWidget {
  final List<double>? lidarAngles;

  const LidarGraphWidget({super.key, this.lidarAngles});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<double>>(
      stream: RosService().lidarStream,
      builder: (context, snapshot) {
        final ranges = snapshot.data ?? lidarAngles ?? [];

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: CustomPaint(
            size: Size.infinite,
            painter: LidarGraphPainter(ranges),
          ),
        );
      },
    );
  }
}

class LidarGraphPainter extends CustomPainter {
  final List<double> angles;

  LidarGraphPainter(this.angles);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw grid
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;

    // Horizontal grid lines
    for (int i = 0; i <= 4; i++) {
      double y = (i / 4) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Vertical grid lines
    for (int i = 0; i <= 10; i++) {
      double x = (i / 10) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Color palette for different angles
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.red,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.cyan,
    ];

    // Draw lidar data for each angle
    for (int angleIndex = 0; angleIndex < angles.length; angleIndex++) {
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            colors[angleIndex % colors.length],
            colors[angleIndex % colors.length].withValues(alpha: .5),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      final path = Path();
      for (int i = 0; i <= 20; i++) {
        double x = (i / 20) * size.width;
        double variation = math.sin(i * 0.5 + angleIndex) * 10;
        double y =
            size.height -
            ((angles[angleIndex] + variation) / 15.0) * size.height;
        y = y.clamp(0, size.height);

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
