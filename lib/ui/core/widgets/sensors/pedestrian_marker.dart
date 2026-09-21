import 'package:flutter/material.dart';

/// Vector-drawn top-down pedestrian marker used by [TopDownBevWidget]'s
/// nearby-detections layer.
///
/// REVISI: the reference BEV mock-up (gambar 1 dari user) shows a small
/// upright person silhouette — blue torso, dark legs, rounded head —
/// standing inside a thin blue detection box, right next to the nearby
/// car sprite. The project's `assets/images` folder only ships
/// `car.png` / `mevicar.png`, and there's no bundled pedestrian asset
/// to point at (and this environment can't reach an image host to
/// download one into the asset bundle). So instead of a raster asset,
/// this paints the same silhouette as a lightweight vector — it scales
/// cleanly to any size, needs no new asset entry in `pubspec.yaml`, and
/// already follows the app's blue accent color used everywhere else in
/// the BEV scene (detection ring, lane lines, etc).
///
/// If a real pedestrian PNG/SVG is added to `assets/images` later, this
/// widget can be swapped 1-for-1 with `Image.asset('assets/images/
/// person.png')` at the single call site in `topdown_bev_widget.dart`
/// with no other changes needed.
class PedestrianMarker extends StatelessWidget {
  final double width;
  final double height;

  /// Torso/shirt color — defaults to the app's primary blue accent so
  /// the figure reads as part of the same detection-UI color family as
  /// the ring/box around it.
  final Color shirtColor;
  final Color pantsColor;
  final Color headColor;

  const PedestrianMarker({
    super.key,
    required this.width,
    required this.height,
    this.shirtColor = const Color(0xFF2F80ED),
    this.pantsColor = const Color(0xFF1A2331),
    this.headColor = const Color(0xFFE0AC69),
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _PedestrianPainter(
        shirtColor: shirtColor,
        pantsColor: pantsColor,
        headColor: headColor,
      ),
    );
  }
}

class _PedestrianPainter extends CustomPainter {
  final Color shirtColor;
  final Color pantsColor;
  final Color headColor;

  const _PedestrianPainter({
    required this.shirtColor,
    required this.pantsColor,
    required this.headColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Proportions: head ~22% of height, torso ~40%, legs ~38%.
    final headRadius = w * 0.34;
    final headCenterY = headRadius * 1.05;

    final torsoTop = headCenterY + headRadius * 0.75;
    final torsoBottom = h * 0.62;
    final torsoWidth = w * 0.86;

    final legsTop = torsoBottom - h * 0.03;
    final legsBottom = h;
    final legGap = w * 0.10;

    // Soft drop shadow under the whole figure so it doesn't look like
    // it's floating over the road, matching the subtle shadow every
    // other BEV sprite (MEVI / nearby car) already has via its PNG.
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, h - 2),
        width: w * 0.7,
        height: h * 0.10,
      ),
      shadowPaint,
    );

    // Legs — two rounded rectangles, slightly apart, as if mid-stride.
    final legsPaint = Paint()..color = pantsColor;
    final legWidth = (torsoWidth - legGap) / 2;
    final leftLeg = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        cx - legGap / 2 - legWidth,
        legsTop,
        cx - legGap / 2,
        legsBottom,
      ),
      Radius.circular(legWidth * 0.4),
    );
    final rightLeg = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        cx + legGap / 2,
        legsTop,
        cx + legGap / 2 + legWidth,
        legsBottom,
      ),
      Radius.circular(legWidth * 0.4),
    );
    canvas.drawRRect(leftLeg, legsPaint);
    canvas.drawRRect(rightLeg, legsPaint);

    // Torso — rounded trapezoid-ish body (shirt).
    final torsoPaint = Paint()..color = shirtColor;
    final torsoRRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        cx - torsoWidth / 2,
        torsoTop,
        cx + torsoWidth / 2,
        torsoBottom,
      ),
      Radius.circular(torsoWidth * 0.28),
    );
    canvas.drawRRect(torsoRRect, torsoPaint);

    // Arms — thin rounded strips hugging the torso sides.
    final armPaint = Paint()..color = shirtColor.withValues(alpha: 0.92);
    final armWidth = torsoWidth * 0.22;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          cx - torsoWidth / 2 - armWidth * 0.55,
          torsoTop + (torsoBottom - torsoTop) * 0.05,
          cx - torsoWidth / 2 + armWidth * 0.45,
          torsoBottom - (torsoBottom - torsoTop) * 0.05,
        ),
        Radius.circular(armWidth * 0.5),
      ),
      armPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          cx + torsoWidth / 2 - armWidth * 0.45,
          torsoTop + (torsoBottom - torsoTop) * 0.05,
          cx + torsoWidth / 2 + armWidth * 0.55,
          torsoBottom - (torsoBottom - torsoTop) * 0.05,
        ),
        Radius.circular(armWidth * 0.5),
      ),
      armPaint,
    );

    // Head.
    final headPaint = Paint()..color = headColor;
    canvas.drawCircle(Offset(cx, headCenterY), headRadius, headPaint);
  }

  @override
  bool shouldRepaint(covariant _PedestrianPainter oldDelegate) =>
      oldDelegate.shirtColor != shirtColor ||
      oldDelegate.pantsColor != pantsColor ||
      oldDelegate.headColor != headColor;
}
