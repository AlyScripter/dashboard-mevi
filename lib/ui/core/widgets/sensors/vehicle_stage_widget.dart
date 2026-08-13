import 'package:flutter/material.dart';
import 'front_bev_widget.dart';
import 'car_3d_viewer_widget.dart';

/// "Stage" that composes the road/LIDAR visualization (FrontBevWidget)
/// together with the real MEVI 3D car model (assets/3d/car_model.glb on
/// Web/Android/iOS via model_viewer_plus, assets/mevi3d.obj on
/// Windows/Linux/macOS via flutter_cube — see Car3DViewerWidget) and a
/// soft blue glow + headlight beam, styled after the reference EV
/// dashboard (glowing beams under the car, blue ambient light).
///
/// Previously this drew a flat `assets/images/car.png` top-down sprite
/// instead, because the 3D pipeline (Car3DViewerWidget) wasn't wired up
/// anywhere and had an unverified steering-orientation offset. That
/// pipeline is now reused as-is here: Car3DViewerWidget already picks the
/// correct platform-specific renderer and already handles its own load
/// failures (falls back to an inline error message instead of a stuck
/// spinner), so no new dependency was added — just connected. If the 3D
/// model ever fails to render on a given machine/platform, check the
/// error text it shows first; `Car3DConstants.forwardYawOffsetDeg` is the
/// single knob to nudge if the model loads but faces the wrong way.
class VehicleStageWidget extends StatefulWidget {
  final double speed;
  final double steeringAngle;
  final double carSize;

  const VehicleStageWidget({
    super.key,
    required this.speed,
    required this.steeringAngle,
    required this.carSize,
  });

  @override
  State<VehicleStageWidget> createState() => _VehicleStageWidgetState();
}

class _VehicleStageWidgetState extends State<VehicleStageWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Moving speed nudges the glow brighter/faster — purely cosmetic,
    // driven by the same ROS speed stream already used across the panel.
    final speedFactor = (widget.speed / 30.0).clamp(0.0, 1.0);
    final tilt = (widget.steeringAngle / 35.0).clamp(-1.0, 1.0);

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // 1. Road + LIDAR obstacle layer (unchanged logic, restyled colors).
        const Positioned.fill(child: FrontBevWidget()),

        // 2. Ambient blue "stage light" glow under the car — enlarged
        // along with the car (item 4) so the glow still sits correctly
        // under the now-bigger model instead of looking small underneath
        // it.
        AnimatedBuilder(
          animation: _glowController,
          builder: (context, _) {
            final pulse = 0.75 + 0.25 * _glowController.value;
            return Container(
              width: widget.carSize * 1.75,
              height: widget.carSize * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF2196F3,
                    ).withValues(alpha: (0.28 + 0.14 * speedFactor) * pulse),
                    blurRadius: 70,
                    spreadRadius: 8,
                  ),
                ],
              ),
            );
          },
        ),

        // 3. Headlight beams fanning forward from the car, like the
        // reference image's light-cone illustration. Scaled up to match
        // the larger car below.
        CustomPaint(
          size: Size(widget.carSize * 2.0, widget.carSize * 2.0),
          painter: _HeadlightBeamPainter(intensity: 0.35 + 0.35 * speedFactor),
        ),

        // 4. The car itself — the real MEVI 3D model
        // (assets/3d/car_model.glb / assets/mevi3d.obj), steered live via
        // Car3DViewerWidget. `tilt` (from steeringAngle) is left as a
        // very slight extra Transform.rotate on top of the model's own
        // internal yaw so quick steering nudges still read as a subtle
        // "lean" on the stage, matching the old sprite's feel.
        //
        // Car3DViewerWidget now accepts `height`/`width` directly (see
        // car_3d_viewer_widget.dart) instead of only being sizeable via
        // an outer SizedBox — the outer SizedBox below still exists to
        // constrain layout, but the explicit height/width here are what
        // actually reach each platform-specific renderer (previously
        // those renderers had `height: 220` hardcoded internally and
        // ignored whatever size their parent gave them, which is why the
        // model used to render far too small regardless of carSize).
        Transform.rotate(
          angle: tilt * 0.03,
          child: SizedBox(
            width: widget.carSize * 1.45,
            height: widget.carSize * 1.45,
            child: Car3DViewerWidget(
              speed: widget.speed,
              steeringAngle: widget.steeringAngle,
              height: widget.carSize * 1.45,
              width: widget.carSize * 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeadlightBeamPainter extends CustomPainter {
  final double intensity;
  const _HeadlightBeamPainter({required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final apex = Offset(size.width / 2, size.height * 0.62);
    final spread = size.width * 0.36;
    final reach = size.height * 0.62;

    final path = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(apex.dx - spread, apex.dy - reach)
      ..lineTo(apex.dx + spread, apex.dy - reach)
      ..close();

    final paint = Paint()
      ..shader = _radialGlowShader(apex, reach, intensity)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  // Renamed from `ui_gradient` -> `_radialGlowShader`: Dart requires
  // lowerCamelCase identifiers (the analyzer's `non_constant_identifier_names`
  // warning on the old snake_case name), and this is private/internal to
  // the painter, so it's also prefixed with `_` like the rest of this
  // file's private members.
  Shader _radialGlowShader(Offset apex, double reach, double intensity) {
    return RadialGradient(
      center: Alignment.bottomCenter,
      radius: 1.0,
      colors: [
        const Color(0xFF64B5F6).withValues(alpha: 0.30 * intensity),
        const Color(0xFF64B5F6).withValues(alpha: 0.0),
      ],
    ).createShader(Rect.fromCircle(center: apex, radius: reach));
  }

  @override
  bool shouldRepaint(covariant _HeadlightBeamPainter oldDelegate) =>
      oldDelegate.intensity != intensity;
}
