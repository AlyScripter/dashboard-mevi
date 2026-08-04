import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../models/data_point.dart';

class UltrasonicGraphWidget extends StatelessWidget {
  final List<DataPoint> ultrasonicHistory;

  const UltrasonicGraphWidget({super.key, required this.ultrasonicHistory});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: CustomPaint(
        size: Size.infinite,
        painter: UltrasonicTimeSeriesPainter(ultrasonicHistory),
      ),
    );
  }
}

class UltrasonicTimeSeriesPainter extends CustomPainter {
  final List<DataPoint> data;

  UltrasonicTimeSeriesPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

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

    // Draw the time series line
    final path = Path();
    for (int i = 0; i < data.length; i++) {
      double x = (i / (data.length - 1)) * size.width;
      double y = size.height - (data[i].value / 10.0) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.blue, Colors.lightBlueAccent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, paint);

    // Draw data points as circles
    for (int i = 0; i < data.length; i++) {
      double x = (i / math.max(1, data.length - 1)) * size.width;
      double y = size.height - (data[i].value / 10.0) * size.height;
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = Colors.blueAccent);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
