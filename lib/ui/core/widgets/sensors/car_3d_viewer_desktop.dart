import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Desktop (Linux / macOS) 3D car renderer.
///
/// On Windows, `Car3DViewerWindows` uses WebView2 to drive `<model-viewer>`
/// with `assets/3d/mevi3d.glb`.
///
/// On Linux/macOS (where WebView2 is not available and software rasterization
/// of 500k-polygon OBJs causes visual glitches and high CPU load), this
/// renderer provides authentic, high-fidelity pre-rendered MEVI vehicle assets
/// matching the exact views from Windows:
///   - Top-down view (`0deg 20deg 105%`) for LiDAR 3D BEV (`assets/images/mevi_topdown.png`)
///   - Perspective 3D chase view (`0deg 50deg 86%`) for BEV (`assets/images/mevi_bev_perspective.png`)
///
/// When [captureSnapshot] is true and [onSnapshot] is provided (as in BEV
/// and LiDAR 3D BEV), this renderer delivers the PNG snapshot bytes to
/// the caller, which allows Flutter's native UI engine to display `RawImage`
/// with GPU-accelerated transforms and realistic blurred silhouette shadows.
class Car3DViewerDesktop extends StatefulWidget {
  final double speed;
  final double steeringAngle;

  /// Optional on-screen size; defaults to the old hardcoded
  /// `height: 220, width: double.infinity` when left null.
  final double? height;
  final double? width;

  /// model-viewer camera-orbit string, e.g. `"0deg 20deg 105%"` or `"0deg 50deg 86%"`.
  final String? cameraOrbit;

  /// Minta viewer memotret modelnya sekali dan mengirim PNG-nya ke [onSnapshot].
  final bool captureSnapshot;

  /// Dipanggil sekali dengan bytes PNG (latar transparan).
  final ValueChanged<Uint8List>? onSnapshot;

  const Car3DViewerDesktop({
    super.key,
    required this.speed,
    required this.steeringAngle,
    this.height,
    this.width,
    this.cameraOrbit,
    this.captureSnapshot = false,
    this.onSnapshot,
  });

  @override
  State<Car3DViewerDesktop> createState() => _Car3DViewerDesktopState();
}

class _Car3DViewerDesktopState extends State<Car3DViewerDesktop> {
  bool _snapshotDelivered = false;

  String get _resolvedAssetPath {
    final orbit = widget.cameraOrbit?.toLowerCase();
    if (orbit != null) {
      if (orbit.contains('20deg') || orbit.contains('top')) {
        return 'assets/images/mevi_topdown.png';
      }
      if (orbit.contains('50deg') || orbit.contains('bev')) {
        return 'assets/images/mevi_bev_perspective.png';
      }
    }
    return 'assets/images/mevi_bev_perspective.png';
  }

  @override
  void initState() {
    super.initState();
    _triggerSnapshotIfNeeded();
  }

  @override
  void didUpdateWidget(covariant Car3DViewerDesktop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cameraOrbit != widget.cameraOrbit ||
        oldWidget.captureSnapshot != widget.captureSnapshot) {
      _snapshotDelivered = false;
      _triggerSnapshotIfNeeded();
    }
  }

  void _triggerSnapshotIfNeeded() {
    if (!widget.captureSnapshot || widget.onSnapshot == null || _snapshotDelivered) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _snapshotDelivered) return;
      try {
        final data = await rootBundle.load(_resolvedAssetPath);
        final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        if (!mounted) return;
        _snapshotDelivered = true;
        widget.onSnapshot!(bytes);
      } catch (e) {
        debugPrint('Car3DViewerDesktop: failed to load snapshot asset: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width ?? double.infinity;
    final h = widget.height ?? 220.0;

    return SizedBox(
      width: w,
      height: h,
      child: Image.asset(
        _resolvedAssetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
