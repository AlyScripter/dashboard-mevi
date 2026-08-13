import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'car_3d_viewer_desktop.dart';
import 'car_3d_viewer_web_mobile.dart';
import 'car_3d_viewer_windows.dart';

/// Public entry point used by the rest of the app (left_panel.dart etc).
///
/// Three renderers live behind this one widget, one per platform group:
///
///   - Web, Android, iOS -> [Car3DViewerWebMobile] (model_viewer_plus /
///     GLB) — the only platforms that package actually supports.
///   - Windows -> [Car3DViewerWindows] (webview_windows driving the same
///     GLB + the same `<model-viewer>` JS as the web build, served over a
///     local loopback HTTP server so Chromium's `fetch()` will actually
///     load it instead of refusing `file://`). This is what makes
///     Windows look like Chrome — see car_3d_viewer_windows.dart for the
///     full explanation.
///   - Linux, macOS -> [Car3DViewerDesktop] (flutter_cube / OBJ). Nobody
///     has wired up a webview_windows equivalent for these two platforms
///     yet, so they keep using the lightweight, WebView-free OBJ
///     renderer for now — see car_3d_viewer_desktop.dart.
class Car3DViewerWidget extends StatelessWidget {
  final double speed;
  final double steeringAngle;

  /// Optional on-screen size for the viewer. Every platform-specific
  /// renderer defaults to `height: 220, width: double.infinity` (its old
  /// hardcoded behavior) when these are left null, so passing nothing
  /// here is still fully backwards compatible with existing call sites.
  final double? height;
  final double? width;

  const Car3DViewerWidget({
    super.key,
    required this.speed,
    required this.steeringAngle,
    this.height,
    this.width,
  });

  static bool get _isWindows => !kIsWeb && Platform.isWindows;

  static bool get _isOtherDesktop =>
      !kIsWeb && (Platform.isLinux || Platform.isMacOS);

  @override
  Widget build(BuildContext context) {
    if (_isWindows) {
      return Car3DViewerWindows(
        speed: speed,
        steeringAngle: steeringAngle,
        height: height,
        width: width,
      );
    }
    if (_isOtherDesktop) {
      return Car3DViewerDesktop(
        speed: speed,
        steeringAngle: steeringAngle,
        height: height,
        width: width,
      );
    }
    return Car3DViewerWebMobile(
      speed: speed,
      steeringAngle: steeringAngle,
      height: height,
      width: width,
    );
  }
}
