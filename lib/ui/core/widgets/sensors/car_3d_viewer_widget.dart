import 'dart:io';
import 'dart:typed_data';
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
///
/// REVISI (BEV/SDC top-down car overlay): added optional [cameraOrbit],
/// forwarded to [Car3DViewerWindows] / [Car3DViewerWebMobile] only —
/// those two both wrap Google's `<model-viewer>`, which natively
/// understands a `camera-orbit="azimuth polar radius"` string (e.g.
/// `"0deg 15deg 105%"` for a near-top-down look). Left `null` (the
/// default), both renderers fall back to exactly their previous
/// behavior, so this is fully backwards compatible with every existing
/// call site (e.g. VehicleStageWidget, which doesn't pass it and keeps
/// looking exactly as before).
/// [Car3DViewerDesktop] (flutter_cube) is NOT wired to this — flutter_cube
/// has no equivalent orbit-string API, it just points a manually
/// positioned `Vector3` camera at the model (see that file). Nobody runs
/// this app on Linux/macOS right now, so it's left as a future TODO
/// rather than guessed at blind.
///
/// REVISI ke-2 (BEV/SDC — hemat memori): added optional [captureSnapshot]
/// / [onSnapshot], diteruskan ke [Car3DViewerWindows] SAJA (satu-satunya
/// renderer berbasis WebView2 yang memang boros memori). Renderer lain
/// mengabaikannya (callback tidak pernah dipanggil -> pemanggil tetap
/// memakai widget live seperti biasa). Default false = tidak berubah.
class Car3DViewerWidget extends StatelessWidget {
  final double speed;
  final double steeringAngle;

  /// Optional on-screen size for the viewer. Every platform-specific
  /// renderer defaults to `height: 220, width: double.infinity` (its old
  /// hardcoded behavior) when these are left null, so passing nothing
  /// here is still fully backwards compatible with existing call sites.
  final double? height;
  final double? width;

  /// model-viewer camera-orbit string, e.g. `"0deg 15deg 105%"`. Null =
  /// unchanged previous behavior (model-viewer's own auto-framed default
  /// view). See class doc above.
  final String? cameraOrbit;

  /// Windows saja: minta model dipotret sekali (PNG transparan) & dikirim
  /// ke [onSnapshot]. Lihat catatan class di atas.
  final bool captureSnapshot;
  final ValueChanged<Uint8List>? onSnapshot;

  const Car3DViewerWidget({
    super.key,
    required this.speed,
    required this.steeringAngle,
    this.height,
    this.width,
    this.cameraOrbit,
    this.captureSnapshot = false,
    this.onSnapshot,
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
        cameraOrbit: cameraOrbit,
        captureSnapshot: captureSnapshot,
        onSnapshot: onSnapshot,
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
      cameraOrbit: cameraOrbit,
    );
  }
}
