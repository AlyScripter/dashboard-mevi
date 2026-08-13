import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'car_3d_constants.dart';

/// Renders the MEVI 3D car model (assets/3d/car_model.glb) using
/// model_viewer_plus, rotating with live steering angle.
///
/// PLATFORM SCOPE — READ BEFORE "FIXING" THIS ON DESKTOP:
/// model_viewer_plus only ships a real implementation for Android
/// (webview_flutter_android), iOS (webview_flutter_wkwebview) and Flutter
/// Web (the `web` package / an <iframe>-like element). It has no Windows,
/// Linux or macOS implementation — check its own pubspec, there's no
/// webview_flutter_windows/linux/macos in its dependency list. So this
/// file is only ever built for kIsWeb / Android / iOS; Car3DViewerWidget
/// (the router in car_3d_viewer_widget.dart) sends Windows/Linux/macOS to
/// car_3d_viewer_desktop.dart instead, which uses flutter_cube (pure
/// Dart, no WebView) on the OBJ export of the same model.
///
/// Even if you register `webview_flutter_windows` yourself, this still
/// won't work: WebView2 is Chromium-based, and Chromium's `fetch()` (which
/// <model-viewer> uses internally to download the .glb) refuses to load
/// `file://` URLs — "Fetch API cannot load file:///...: URL scheme 'file'
/// is not supported." That's a browser-level restriction, not something
/// this app can configure around. It's *why* the desktop build was
/// spinning forever instead of erroring: the WebView had nothing to
/// legitimately fail on since the request never went anywhere.
///
/// SETUP STEP (do this once, outside this file), inside <head> of
/// web/index.html:
///
///   <script type="module"
///     src="./assets/packages/model_viewer_plus/assets/model-viewer.min.js"
///     defer></script>
///
/// Why two different `src` strategies below:
/// - Web: Flutter serves the asset bundle over its own HTTP server, so a
///   relative "assets/assets/3d/car_model.glb" URL just works.
/// - Mobile (Android/iOS): there is no such HTTP server either, so we copy
///   the bundled .glb out to a real temp file once and point ModelViewer
///   at it via a file:// URI — this works fine on Android/iOS because
///   webview_flutter_android / webview_flutter_wkwebview both special-case
///   local file access for their WebView, unlike WebView2 on Windows.
class Car3DViewerWebMobile extends StatefulWidget {
  final double speed;
  final double steeringAngle;

  /// Optional on-screen size; defaults to the old hardcoded
  /// `height: 220, width: double.infinity` when left null.
  final double? height;
  final double? width;

  const Car3DViewerWebMobile({
    super.key,
    required this.speed,
    required this.steeringAngle,
    this.height,
    this.width,
  });

  @override
  State<Car3DViewerWebMobile> createState() => _Car3DViewerWebMobileState();
}

class _Car3DViewerWebMobileState extends State<Car3DViewerWebMobile> {
  static const _assetPath = 'assets/3d/car_model.glb';

  String? _src;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolveSrc();
  }

  Future<void> _resolveSrc() async {
    if (kIsWeb) {
      // Relative to index.html — Flutter's own web server handles it.
      setState(() => _src = 'assets/$_assetPath');
      return;
    }

    try {
      final data = await rootBundle.load(_assetPath);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/mevi_car_model.glb');

      // Only write once — no need to re-copy on every rebuild/hot reload.
      if (!await file.exists() || await file.length() != data.lengthInBytes) {
        await file.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
      }

      if (!mounted) return;
      setState(() => _src = Uri.file(file.path).toString());
    } catch (e) {
      debugPrint('Car3DViewerWebMobile: failed to extract glb: $e');
      if (!mounted) return;
      // IMPORTANT: always resolve to a visible state, never leave the UI
      // stuck on a spinner forever — that was the previous bug.
      setState(() => _error = e.toString());
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

    if (_src == null) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    // model-viewer's `orientation` attribute takes "roll pitch yaw":
    //   roll  -> rotation around Z (banks the car sideways, wrong axis
    //            for steering — this is what the old code used by
    //            mistake, putting steeringAngle in the FIRST slot).
    //   pitch -> rotation around X (nose tips up/down).
    //   yaw   -> rotation around Y, the vertical axis — this is the
    //            correct axis for "the car turns left/right", so
    //            steeringAngle now goes in the LAST slot, added on top
    //            of the forward-facing base offset.
    final orientation =
        '0deg 0deg '
        '${Car3DConstants.forwardYawOffsetDeg + widget.steeringAngle}deg';

    return SizedBox(
      height: widget.height ?? 220,
      width: widget.width ?? double.infinity,
      child: ModelViewer(
        key: const ValueKey('mevi-car-3d'),
        src: _src!,
        alt: 'Model 3D Mobil MEVI',
        autoRotate: false,
        cameraControls: false,
        disableZoom: true,
        orientation: orientation,
        backgroundColor: Colors.transparent,
      ),
    );
  }
}
