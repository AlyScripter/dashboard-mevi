import 'package:flutter/material.dart';
import 'package:flutter_cube/flutter_cube.dart' as cube3d;

import 'car_3d_constants.dart';

/// Desktop (Windows / Linux / macOS) 3D car renderer.
///
/// WHY THIS FILE EXISTS — root cause of the "doesn't render on Windows,
/// works fine in Chrome" bug:
///
/// The old single `Car3DViewerWidget` used `model_viewer_plus` on every
/// platform. That package embeds Google's <model-viewer> web component
/// inside a WebView, but it only actually implements Android, iOS and
/// Flutter Web (see its own pubspec.yaml: webview_flutter_android,
/// webview_flutter_wkwebview, web — no Windows/Linux/macOS entry
/// anywhere). On Windows there's no `WebViewPlatform` implementation for
/// it to use, and — this is the part that would keep biting even if that
/// were wired up by hand with `webview_flutter_windows` — WebView2 is
/// Chromium, and Chromium's `fetch()` API (which <model-viewer> uses
/// internally to download the .glb) hard-refuses to load `file://` URLs.
/// That's why the widget just hung on a spinner in the Windows build
/// (screenshot 1) instead of showing an error: the request never got far
/// enough to fail with a message, it was rejected at the browser level.
///
/// FIX: skip WebView entirely on desktop and render with `flutter_cube`
/// — a pure-Dart OBJ renderer with no WebView, no local HTTP server, and
/// no `fetch()` involved, so the `file://` CORS wall never comes up. It
/// reads straight from the asset bundle. `flutter_cube` was already a
/// dependency in pubspec.yaml, and `assets/mevi3d.obj` /
/// `assets/mevi3d.mtl` were already declared as assets — they just
/// weren't wired to anything yet.
class Car3DViewerDesktop extends StatefulWidget {
  final double speed;
  final double steeringAngle;

  /// Optional on-screen size; defaults to the old hardcoded
  /// `height: 220, width: double.infinity` when left null.
  final double? height;
  final double? width;

  const Car3DViewerDesktop({
    super.key,
    required this.speed,
    required this.steeringAngle,
    this.height,
    this.width,
  });

  @override
  State<Car3DViewerDesktop> createState() => _Car3DViewerDesktopState();
}

class _Car3DViewerDesktopState extends State<Car3DViewerDesktop> {
  static const _objAsset = 'assets/mevi3d.obj';

  cube3d.Object? _car;
  cube3d.Scene? _scene;
  String? _error;

  void _onSceneCreated(cube3d.Scene scene) {
    _scene = scene;

    // A modest, slightly elevated, straight-on camera. flutter_cube has
    // no auto-framing, so if the model looks too small/large or
    // clipped, adjust `position.z` (distance) and/or the car's `scale`
    // below together — moving the camera closer/farther and scaling the
    // model do the same visual job, so change one at a time.
    scene.camera.position.x = 0;
    scene.camera.position.y = 2.5;
    scene.camera.position.z = 9;
    scene.light.position.setFrom(cube3d.Vector3(0, 10, 10));

    try {
      _car = cube3d.Object(
        fileName: _objAsset,
        lighting: true,
        backfaceCulling: false,
        scale: cube3d.Vector3(3.2, 3.2, 3.2),
        rotation: cube3d.Vector3(
          0,
          Car3DConstants.forwardYawOffsetDeg + widget.steeringAngle,
          0,
        ),
      );
      scene.world.add(_car!);
    } catch (e) {
      debugPrint('Car3DViewerDesktop: failed to load obj: $e');
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  void didUpdateWidget(covariant Car3DViewerDesktop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_car != null && oldWidget.steeringAngle != widget.steeringAngle) {
      _car!.rotation.y =
          Car3DConstants.forwardYawOffsetDeg + widget.steeringAngle;
      _car!.updateTransform();
      _scene?.update();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Gagal memuat model 3D:\n$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 11),
          ),
        ),
      );
    }

    return SizedBox(
      height: widget.height ?? 220,
      width: widget.width ?? double.infinity,
      child: cube3d.Cube(interactive: false, onSceneCreated: _onSceneCreated),
    );
  }
}
