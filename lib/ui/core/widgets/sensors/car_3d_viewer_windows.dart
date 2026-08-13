import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../../../services/local_asset_server_service.dart';
import 'car_3d_constants.dart';

/// Windows-only 3D car renderer. See `local_asset_server_service.dart` for
/// the full explanation of the file:// and same-origin/CORS problems this
/// works around — both are solved on the server side; this file just
/// drives the WebView2 controller.
class Car3DViewerWindows extends StatefulWidget {
  final double speed;
  final double steeringAngle;

  /// Optional on-screen size; defaults to `height: 220, width:
  /// double.infinity` when left null.
  final double? height;
  final double? width;

  const Car3DViewerWindows({
    super.key,
    required this.speed,
    required this.steeringAngle,
    this.height,
    this.width,
  });

  @override
  State<Car3DViewerWindows> createState() => _Car3DViewerWindowsState();
}

class _Car3DViewerWindowsState extends State<Car3DViewerWindows> {
  // ---------------------------------------------------------------------
  // TESTING SWITCH: change ONLY this constant to try a different .glb —
  // e.g. 'assets/3d/vino.glb' or 'assets/3d/mevi3d.glb' — without
  // touching anything else in this file or in
  // local_asset_server_service.dart. If a smaller/different file renders
  // fine here, the problem is specific to the asset named below, not the
  // WebView2/server plumbing. If nothing renders no matter which path you
  // put here, the problem is still in the plumbing — check the
  // `webMessage` log as described in car_3d_viewer_windows.dart's parent
  // doc / WINDOWS_3D_VIEWER_FIX.md.
  // ---------------------------------------------------------------------
  static const _glbAssetPath = 'assets/3d/mevi3d.glb';

  final WebviewController _controller = WebviewController();
  StreamSubscription<dynamic>? _webMessageSub;

  bool _ready = false;
  String? _error;
  String _stage = 'starting';

  @override
  void initState() {
    super.initState();
    _init();
  }

  String get _orientation =>
      '0deg 0deg '
      '${Car3DConstants.forwardYawOffsetDeg + widget.steeringAngle}deg';

  void _setStage(String stage) {
    debugPrint('Car3DViewerWindows: stage -> $stage');
    _stage = stage;
  }

  Future<void> _init() async {
    try {
      _setStage('starting local asset server');
      await LocalAssetServerService.instance.start();
      final baseUrl = LocalAssetServerService.instance.baseUrl;
      debugPrint('Car3DViewerWindows: local server up at $baseUrl');
      debugPrint('Car3DViewerWindows: testing GLB path = $_glbAssetPath');

      _setStage('checking WebView2 Runtime');
      final webviewVersion = await WebviewController.getWebViewVersion();
      debugPrint(
        'Car3DViewerWindows: WebView2 runtime version = $webviewVersion',
      );
      if (webviewVersion == null || webviewVersion.isEmpty) {
        throw StateError(
          'Microsoft Edge WebView2 Runtime tidak ditemukan di perangkat ini. '
          'Unduh & install "Evergreen WebView2 Runtime" dari Microsoft, lalu '
          'restart aplikasi.',
        );
      }

      _setStage('initializing WebView2 controller');
      await _controller.initialize();

      _setStage('setting background color');
      await _controller.setBackgroundColor(Colors.transparent);

      _setStage('listening for in-page diagnostics');
      _webMessageSub = _controller.webMessage.listen((event) {
        debugPrint('Car3DViewerWindows: webMessage: $event');
      });

      _setStage('loading viewer page');
      final url = Uri.parse('$baseUrl${LocalAssetServerService.viewerPath}')
          .replace(
            queryParameters: {'glb': '/$_glbAssetPath', 'ori': _orientation},
          )
          .toString();
      debugPrint('Car3DViewerWindows: loading $url');
      await _controller.loadUrl(url);

      _setStage('ready');
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e, st) {
      debugPrint('Car3DViewerWindows: init failed at stage "$_stage": $e');
      debugPrint('$st');
      if (!mounted) return;
      setState(() => _error = '[$_stage] $e');
    }
  }

  @override
  void didUpdateWidget(covariant Car3DViewerWindows oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready && oldWidget.steeringAngle != widget.steeringAngle) {
      _controller.executeScript("setOrientation('$_orientation')");
    }
  }

  @override
  void dispose() {
    _webMessageSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.12),
          border: Border.all(color: Colors.redAccent, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Gagal memuat model 3D (Windows):\n$_error',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.redAccent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (!_ready) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 8),
            Text(
              _stage,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: widget.height ?? 220,
      width: widget.width ?? double.infinity,
      child: Webview(_controller),
    );
  }
}
