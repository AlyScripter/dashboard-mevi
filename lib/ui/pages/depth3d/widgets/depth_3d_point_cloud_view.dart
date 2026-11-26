import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:dashboardmevi/core/theme/colors.dart';
import 'package:dashboardmevi/model/cam_cloud_frame.dart';
import 'package:dashboardmevi/services/ros_service.dart';

/// Color modes for `/bev/camcloud` rendering.
enum Depth3dColorMode {
  rgbObject('RGB'),
  semantic('Semantik'),
  height('Tinggi');

  final String label;
  const Depth3dColorMode(this.label);
}

@immutable
class _Depth3dLayers {
  final bool showCamCloud;
  final bool showBoxes;
  final bool showWaypoints;

  const _Depth3dLayers({
    this.showCamCloud = true,
    this.showBoxes = true,
    this.showWaypoints = false,
  });

  _Depth3dLayers copyWith({
    bool? showCamCloud,
    bool? showBoxes,
    bool? showWaypoints,
  }) {
    return _Depth3dLayers(
      showCamCloud: showCamCloud ?? this.showCamCloud,
      showBoxes: showBoxes ?? this.showBoxes,
      showWaypoints: showWaypoints ?? this.showWaypoints,
    );
  }
}

@immutable
class _OrbitCam {
  final double azimuth;
  final double elevation;
  final double distance;
  final double targetX;
  final double targetZ;

  const _OrbitCam({
    this.azimuth = math.pi,
    this.elevation = 0.26,
    this.distance = 11.0,
    this.targetX = 7.5,
    this.targetZ = 0.35,
  });

  _OrbitCam copyWith({
    double? azimuth,
    double? elevation,
    double? distance,
    double? targetX,
    double? targetZ,
  }) {
    return _OrbitCam(
      azimuth: azimuth ?? this.azimuth,
      elevation: elevation ?? this.elevation,
      distance: distance ?? this.distance,
      targetX: targetX ?? this.targetX,
      targetZ: targetZ ?? this.targetZ,
    );
  }
}

class _Box3d {
  final int? id;
  final String cls;
  final bool isDepthOnly;
  final double cx, cy, cz, l, w, h, yaw;
  const _Box3d({
    this.id,
    this.cls = 'Object',
    this.isDepthOnly = false,
    required this.cx,
    required this.cy,
    required this.cz,
    required this.l,
    required this.w,
    required this.h,
    required this.yaw,
  });
}

class _BevFrameOverlayData {
  final int? frameIdx;
  final List<_Box3d> boxes;
  final Float32List waypoints;

  const _BevFrameOverlayData({
    required this.frameIdx,
    required this.boxes,
    required this.waypoints,
  });
}

/// Interactive 3D viewer fusing `/bev/camcloud` (RGB-D segmented point cloud),
/// `/bev/frame` (green 3D bounding boxes + waypoints), and `/bev/class_color_map`
/// in a unified LiDAR coordinate frame.
class Depth3dPointCloudView extends StatefulWidget {
  const Depth3dPointCloudView({super.key});

  @override
  State<Depth3dPointCloudView> createState() => _Depth3dPointCloudViewState();
}

class _Depth3dPointCloudViewState extends State<Depth3dPointCloudView> {
  StreamSubscription<CamCloudFrame>? _camCloudSub;
  StreamSubscription<Map<String, dynamic>>? _bevFrameSub;
  StreamSubscription<Map<int, Color>>? _classColorSub;
  StreamSubscription<Map<String, BevObjectStyle>>? _objectStyleSub;

  final ValueNotifier<CamCloudFrame?> _camCloud = ValueNotifier(null);
  final ValueNotifier<_BevFrameOverlayData?> _bevOverlay = ValueNotifier(null);
  final ValueNotifier<_OrbitCam> _cam = ValueNotifier(const _OrbitCam());
  final ValueNotifier<Depth3dColorMode> _colorMode = ValueNotifier(
    Depth3dColorMode.rgbObject,
  );
  final ValueNotifier<_Depth3dLayers> _layers = ValueNotifier(
    const _Depth3dLayers(),
  );
  final ValueNotifier<Map<int, Color>> _classColors = ValueNotifier(const {});
  final ValueNotifier<Map<String, BevObjectStyle>> _objectStyles = ValueNotifier(
    const {},
  );

  final _Depth3dScratch _scratch = _Depth3dScratch();
  double _pinchStartDist = 11.0;

  @override
  void initState() {
    super.initState();
    final ros = RosService();

    _classColors.value = ros.bevClassColorMap ?? const {};
    _objectStyles.value = ros.bevObjectStyle ?? const {};
    _camCloud.value = ros.lastBevCamCloud;
    final lastBev = ros.lastBevFrame;
    if (lastBev != null) {
      _bevOverlay.value = _parseBevOverlay(lastBev);
    }

    _camCloudSub = ros.bevCamCloudStream.listen((frame) {
      if (mounted) _camCloud.value = frame;
    });
    _bevFrameSub = ros.bevFrameStream.listen((frame) {
      if (!mounted) return;
      final parsed = _parseBevOverlay(frame);
      if (parsed != null) {
        // Hold last _camCloud when /bev/frame arrives faster than /bev/camcloud.
        _bevOverlay.value = parsed;
      }
    });
    _classColorSub = ros.bevClassColorMapStream.listen((cmap) {
      if (mounted) _classColors.value = cmap;
    });
    _objectStyleSub = ros.bevObjectStyleStream.listen((styles) {
      if (mounted) _objectStyles.value = styles;
    });
  }

  @override
  void dispose() {
    _camCloudSub?.cancel();
    _bevFrameSub?.cancel();
    _classColorSub?.cancel();
    _objectStyleSub?.cancel();
    _camCloud.dispose();
    _bevOverlay.dispose();
    _cam.dispose();
    _colorMode.dispose();
    _layers.dispose();
    _classColors.dispose();
    _objectStyles.dispose();
    super.dispose();
  }

  _BevFrameOverlayData? _parseBevOverlay(Map<String, dynamic> frame) {
    try {
      final raw = frame['raw'];
      if (raw is! Map) return null;

      // 3D Bounding boxes from /bev/frame obj.
      final boxes = <_Box3d>[];
      final objList = raw['obj'];
      if (objList is List) {
        for (final o in objList) {
          if (o is! Map) continue;
          boxes.add(
            _Box3d(
              id: (o['id'] as num?)?.toInt(),
              cls: (o['cls'] as String?) ?? 'Object',
              isDepthOnly: o['st'] == 'D',
              cx: (o['cx'] as num?)?.toDouble() ?? 0.0,
              cy: (o['cy'] as num?)?.toDouble() ?? 0.0,
              cz: (o['cz'] as num?)?.toDouble() ?? 0.0,
              l: (o['l'] as num?)?.toDouble() ?? 0.0,
              w: (o['w'] as num?)?.toDouble() ?? 0.0,
              h: (o['h'] as num?)?.toDouble() ?? 0.0,
              yaw: (o['yaw'] as num?)?.toDouble() ?? 0.0,
            ),
          );
        }
      }

      // Optional waypoints.
      Float32List wp = Float32List(0);
      final wpList = raw['wp'];
      if (wpList is List && wpList.isNotEmpty) {
        final tmp = Float32List(wpList.length * 2);
        int k = 0;
        for (final p in wpList) {
          if (p is List && p.length >= 2) {
            final x = p[0];
            final y = p[1];
            if (x is num && y is num) {
              tmp[k++] = x.toDouble();
              tmp[k++] = y.toDouble();
            }
          }
        }
        wp = k == tmp.length ? tmp : Float32List.sublistView(tmp, 0, k);
      }

      return _BevFrameOverlayData(
        frameIdx: (frame['frame_idx'] as num?)?.toInt(),
        boxes: boxes,
        waypoints: wp,
      );
    } catch (e) {
      debugPrint('Depth3dPointCloudView: failed to parse /bev/frame: $e');
      return null;
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final dy = event.scrollDelta.dy;
      if (dy == 0) return;
      final factor = dy > 0 ? 1.12 : 0.89;
      final c = _cam.value;
      _cam.value = c.copyWith(
        distance: (c.distance * factor).clamp(4.0, 60.0),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Listener(
      onPointerSignal: _onPointerSignal,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: (_) {
          _pinchStartDist = _cam.value.distance;
        },
        onScaleUpdate: (details) {
          final c = _cam.value;
          double nextDist = c.distance;
          if ((details.scale - 1.0).abs() > 0.01) {
            nextDist = (_pinchStartDist / details.scale).clamp(4.0, 60.0);
          }
          final dAz = -details.focalPointDelta.dx * 0.0065;
          final dEl = details.focalPointDelta.dy * 0.0065;
          _cam.value = c.copyWith(
            azimuth: c.azimuth + dAz,
            elevation: (c.elevation + dEl).clamp(0.08, 1.52),
            distance: nextDist,
          );
        },
        child: Container(
          color: isLight ? Colors.white : const Color(0xFF05070C),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Main 3D GPU-accelerated canvas
              CustomPaint(
                painter: _Depth3dPainter(
                  camCloud: _camCloud,
                  bevOverlay: _bevOverlay,
                  cam: _cam,
                  colorMode: _colorMode,
                  layers: _layers,
                  classColors: _classColors,
                  objectStyles: _objectStyles,
                  scratch: _scratch,
                  isLight: isLight,
                ),
              ),

              // Empty-state prompt until any frame arrives
              ValueListenableBuilder<CamCloudFrame?>(
                valueListenable: _camCloud,
                builder: (context, cc, _) {
                  return ValueListenableBuilder<_BevFrameOverlayData?>(
                    valueListenable: _bevOverlay,
                    builder: (context, bev, _) {
                      if (cc != null || bev != null) {
                        return const SizedBox.shrink();
                      }
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.box,
                              size: 40,
                              color: isLight
                                  ? const Color(0xFF94A3B8)
                                  : Colors.white.withValues(alpha: 0.28),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Menunggu stream /bev/camcloud & /bev/frame',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isLight
                                    ? const Color(0xFF475569)
                                    : Colors.white.withValues(alpha: 0.55),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Drag untuk orbit 3D · Scroll/Pinch untuk zoom',
                              style: TextStyle(
                                fontSize: 11,
                                color: isLight
                                    ? const Color(0xFF94A3B8)
                                    : Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),

              // Top-left: Live status + frame counters
              Positioned(
                top: 12,
                left: 12,
                child: _buildStatusPill(isLight),
              ),

              // Top-right: Color mode selector + layer toggles
              Positioned(
                top: 12,
                right: 12,
                child: _buildControlPanel(isLight),
              ),

              // Bottom-right: Reset POV button
              Positioned(
                right: 12,
                bottom: 12,
                child: _buildResetPovButton(isLight),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(bool isLight) {
    final panelBg = isLight ? Colors.white : AppColors.glassSurfaceAlt;
    final panelBorder = isLight
        ? const Color(0xFFE2E8F0)
        : AppColors.glassBlueBorder.withValues(alpha: 0.35);

    return ValueListenableBuilder<CamCloudFrame?>(
      valueListenable: _camCloud,
      builder: (context, cc, _) {
        return ValueListenableBuilder<_BevFrameOverlayData?>(
          valueListenable: _bevOverlay,
          builder: (context, bev, _) {
            final isLive = cc != null || bev != null;
            final dotColor =
                isLive ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
            final liveTextColor = isLive
                ? (isLight ? const Color(0xFF15803D) : const Color(0xFF4ADE80))
                : (isLight ? const Color(0xFFB45309) : const Color(0xFFFBBF24));
            final liveBgColor = isLive
                ? (isLight ? const Color(0xFFDCFCE7) : const Color(0x2A10B981))
                : (isLight ? const Color(0xFFFEF3C7) : const Color(0x2AF59E0B));
            final idx = cc?.idx ?? bev?.frameIdx;
            final camPts = cc?.count ?? 0;
            final boxCount = bev?.boxes.length ?? 0;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: panelBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: panelBorder, width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: isLight
                        ? const Color(0x0C0F172A)
                        : AppColors.glassBlueGlow.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: liveBgColor,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: dotColor.withValues(alpha: 0.6),
                                blurRadius: 5,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isLive ? 'LIVE' : 'WAITING',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: liveTextColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (idx != null) ...[
                    _pillDivider(isLight),
                    Text(
                      '#$idx',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isLight
                            ? const Color(0xFF0F172A)
                            : AppColors.glassTextPrimary,
                      ),
                    ),
                  ],
                  _pillDivider(isLight),
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      'Cam $camPts · Box $boxCount',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isLight
                            ? const Color(0xFF475569)
                            : AppColors.glassTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _pillDivider(bool isLight) => Container(
        width: 1,
        height: 14,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: isLight
            ? const Color(0xFFE2E8F0)
            : Colors.white.withValues(alpha: 0.14),
      );

  Widget _buildControlPanel(bool isLight) {
    final panelBg = isLight ? Colors.white : AppColors.glassSurfaceAlt;
    final panelBorder = isLight
        ? const Color(0xFFE2E8F0)
        : AppColors.glassBlueBorder.withValues(alpha: 0.35);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: panelBorder, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: isLight
                ? const Color(0x0C0F172A)
                : AppColors.glassBlueGlow.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 3 color modes: RGB, Semantik, Tinggi
          ValueListenableBuilder<Depth3dColorMode>(
            valueListenable: _colorMode,
            builder: (context, mode, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: Depth3dColorMode.values.map((m) {
                  final selected = mode == m;
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: GestureDetector(
                      onTap: () => _colorMode.value = m,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF2563EB)
                              : (isLight
                                  ? const Color(0xFFF1F5F9)
                                  : Colors.white.withValues(alpha: 0.06)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF3B82F6)
                                : (isLight
                                    ? const Color(0xFFE2E8F0)
                                    : Colors.white.withValues(alpha: 0.10)),
                          ),
                        ),
                        child: Text(
                          m.label,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : (isLight
                                    ? const Color(0xFF475569)
                                    : AppColors.glassTextSecondary),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 6),
          // Layer visibility chips (CamCloud, Box 3D, WP)
          ValueListenableBuilder<_Depth3dLayers>(
            valueListenable: _layers,
            builder: (context, l, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _layerChip(
                    'CamCloud',
                    l.showCamCloud,
                    const Color(0xFFFF4D6D),
                    isLight,
                    () => _layers.value =
                        l.copyWith(showCamCloud: !l.showCamCloud),
                  ),
                  _layerChip(
                    'Box 3D',
                    l.showBoxes,
                    isLight
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF00FF41),
                    isLight,
                    () => _layers.value = l.copyWith(showBoxes: !l.showBoxes),
                  ),
                  _layerChip(
                    'WP',
                    l.showWaypoints,
                    const Color(0xFFFFA726),
                    isLight,
                    () => _layers.value =
                        l.copyWith(showWaypoints: !l.showWaypoints),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _layerChip(
    String label,
    bool active,
    Color dotColor,
    bool isLight,
    VoidCallback onTap,
  ) {
    final activeBg = isLight
        ? const Color(0xFFF8FAFC)
        : Colors.white.withValues(alpha: 0.12);
    final activeBorder = isLight
        ? const Color(0xFFCBD5E1)
        : Colors.white.withValues(alpha: 0.24);
    final inactiveBorder = isLight
        ? const Color(0xFFE2E8F0)
        : Colors.white.withValues(alpha: 0.08);
    final activeText = isLight ? const Color(0xFF0F172A) : Colors.white;
    final inactiveText = isLight ? const Color(0xFF94A3B8) : Colors.white38;
    final inactiveDot = isLight ? const Color(0xFFCBD5E1) : Colors.white24;

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: active ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: active ? activeBorder : inactiveBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? dotColor : inactiveDot,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: active ? activeText : inactiveText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResetPovButton(bool isLight) {
    return Tooltip(
      message: 'Reset Sudut Pandang Kamera',
      child: GestureDetector(
        onTap: () => _cam.value = const _OrbitCam(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isLight ? Colors.white : AppColors.glassSurfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isLight
                  ? const Color(0xFFE2E8F0)
                  : AppColors.glassBlueBorder.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.focus,
                size: 14,
                color: isLight
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF7DB4FF),
              ),
              const SizedBox(width: 6),
              Text(
                'Reset POV',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isLight
                      ? const Color(0xFF0F172A)
                      : AppColors.glassTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable scratch buffers to avoid allocations during 3D rendering.
class _Depth3dScratch {
  Float32List secondary2d = Float32List(8192);
  Float32List triPositions = Float32List(32768);
  Int32List triColors = Int32List(16384);
  Float32List semOther = Float32List(8192);
  Float32List semRoad = Float32List(8192);
  Float32List semObj = Float32List(8192);
  final Float64List boxCorners = Float64List(16);

  Float32List ensureSecondary2d(int floatsNeeded) {
    if (secondary2d.length < floatsNeeded) {
      secondary2d = Float32List(floatsNeeded + (floatsNeeded >> 2));
    }
    return secondary2d;
  }

  void ensureTriangles(int pointCount) {
    final posLen = pointCount * 6;
    final colLen = pointCount * 3;
    if (triPositions.length < posLen) {
      triPositions = Float32List(posLen + (posLen >> 2));
    }
    if (triColors.length < colLen) {
      triColors = Int32List(colLen + (colLen >> 2));
    }
  }

  void ensureSemantic(int maxPoints) {
    final need = maxPoints * 2;
    if (semOther.length < need) semOther = Float32List(need);
    if (semRoad.length < need) semRoad = Float32List(need);
    if (semObj.length < need) semObj = Float32List(need);
  }
}

class _Camera3d {
  final double px, py, pz;
  final double rx, ry, rz;
  final double ux, uy, uz;
  final double fx, fy, fz;
  final double f;
  final double cx, cy;
  final double minX, maxX, minY, maxY;

  static const double _fovYRad = 0.92;
  static const double _near = 0.35;

  factory _Camera3d(_OrbitCam cs, Size size) {
    final cosE = math.cos(cs.elevation);
    final sinE = math.sin(cs.elevation);
    final cosA = math.cos(cs.azimuth);
    final sinA = math.sin(cs.azimuth);

    final px = cs.targetX + cs.distance * cosE * cosA;
    final py = cs.distance * cosE * sinA;
    final pz = cs.targetZ + cs.distance * sinE;

    var fx = cs.targetX - px;
    var fy = -py;
    var fz = cs.targetZ - pz;
    final fLen = math.sqrt(fx * fx + fy * fy + fz * fz);
    if (fLen > 1e-9) {
      fx /= fLen;
      fy /= fLen;
      fz /= fLen;
    }

    // World up = (0, 0, 1); right = forward x worldUp = (fy, -fx, 0)
    var rx = fy;
    var ry = -fx;
    const rz = 0.0;
    final rLen = math.sqrt(rx * rx + ry * ry);
    if (rLen < 1e-6) {
      rx = 1.0;
      ry = 0.0;
    } else {
      rx /= rLen;
      ry /= rLen;
    }

    // up = right x forward
    final ux = ry * fz - rz * fy;
    final uy = rz * fx - rx * fz;
    final uz = rx * fy - ry * fx;

    final f = (size.height / 2.0) / math.tan(_fovYRad / 2.0);
    return _Camera3d._(
      px: px,
      py: py,
      pz: pz,
      rx: rx,
      ry: ry,
      rz: rz,
      ux: ux,
      uy: uy,
      uz: uz,
      fx: fx,
      fy: fy,
      fz: fz,
      f: f,
      cx: size.width / 2.0,
      cy: size.height / 2.0,
      minX: -20.0,
      maxX: size.width + 20.0,
      minY: -20.0,
      maxY: size.height + 20.0,
    );
  }

  const _Camera3d._({
    required this.px,
    required this.py,
    required this.pz,
    required this.rx,
    required this.ry,
    required this.rz,
    required this.ux,
    required this.uy,
    required this.uz,
    required this.fx,
    required this.fy,
    required this.fz,
    required this.f,
    required this.cx,
    required this.cy,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  Offset? project(double x, double y, double z) {
    final dx = x - px;
    final dy = y - py;
    final dz = z - pz;
    final vz = dx * fx + dy * fy + dz * fz;
    if (vz <= _near) return null;
    final k = f / vz;
    return Offset(
      cx + (dx * rx + dy * ry + dz * rz) * k,
      cy - (dx * ux + dy * uy + dz * uz) * k,
    );
  }
}

class _Depth3dPainter extends CustomPainter {
  final ValueListenable<CamCloudFrame?> camCloud;
  final ValueListenable<_BevFrameOverlayData?> bevOverlay;
  final ValueListenable<_OrbitCam> cam;
  final ValueListenable<Depth3dColorMode> colorMode;
  final ValueListenable<_Depth3dLayers> layers;
  final ValueListenable<Map<int, Color>> classColors;
  final ValueListenable<Map<String, BevObjectStyle>> objectStyles;
  final _Depth3dScratch scratch;
  final bool isLight;

  _Depth3dPainter({
    required this.camCloud,
    required this.bevOverlay,
    required this.cam,
    required this.colorMode,
    required this.layers,
    required this.classColors,
    required this.objectStyles,
    required this.scratch,
    required this.isLight,
  }) : super(
          repaint: Listenable.merge([
            camCloud,
            bevOverlay,
            cam,
            colorMode,
            layers,
            classColors,
            objectStyles,
          ]),
        );

  static const Color _objectRedColor = Color(0xFFFF1744);
  static const Color _roadBlueColor = Color(0xFF2979FF);
  static const Color _otherGrayColor = Color(0xFF94A3B8);
  static const Color _boxGreenDark = Color(0xFF00FF41);
  static const Color _boxGreenLight = Color(0xFF16A34A);

  final Paint _vertexPaint = Paint();

  final Paint _semPointPaint = Paint()
    ..strokeWidth = 2.6
    ..strokeCap = StrokeCap.round;

  final Paint _objRedPaint = Paint()
    ..color = _objectRedColor
    ..strokeWidth = 3.2
    ..strokeCap = StrokeCap.round;

  final Paint _boxPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4
    ..strokeJoin = StrokeJoin.round;

  final Paint _wpPaint = Paint()
    ..color = const Color(0xFFFFA726)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2;

  final Paint _axisPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2
    ..strokeCap = StrokeCap.round;

  static const List<List<int>> _boxEdges = [
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 0],
    [4, 5],
    [5, 6],
    [6, 7],
    [7, 4],
    [0, 4],
    [1, 5],
    [2, 6],
    [3, 7],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final camera = _Camera3d(cam.value, size);
    final lyr = layers.value;
    final mode = colorMode.value;
    final bev = bevOverlay.value;
    final cc = camCloud.value;

    // 1. Camera RGB-D point cloud from /bev/camcloud
    if (lyr.showCamCloud && cc != null && cc.count > 0) {
      _drawCamCloud(canvas, camera, cc, mode);
    }

    // 2. Optional waypoints from /bev/frame wp
    if (lyr.showWaypoints && bev != null && bev.waypoints.length >= 4) {
      _drawWaypoints(canvas, camera, bev.waypoints);
    }

    // 3. Colored 3D wireframe bounding boxes + class labels from /bev/frame obj
    if (lyr.showBoxes && bev != null && bev.boxes.isNotEmpty) {
      _drawWireframeBoxes(canvas, camera, bev.boxes);
    }

    // 4. Ego RGB XYZ coordinate axes at (0, 0, 0)
    _drawEgoAxes(canvas, camera);
  }

  void _drawCamCloud(
    Canvas canvas,
    _Camera3d camera,
    CamCloudFrame cc,
    Depth3dColorMode mode,
  ) {
    final n = cc.count;
    final xyz = cc.xyz;
    final clsArr = cc.classes;

    if (mode == Depth3dColorMode.semantic) {
      scratch.ensureSemantic(n);
      final otherBuf = scratch.semOther;
      final roadBuf = scratch.semRoad;
      final objBuf = scratch.semObj;
      int wOther = 0;
      int wRoad = 0;
      int wObj = 0;

      for (int i = 0, j = 0; i < n; i++, j += 3) {
        final dx = xyz[j] - camera.px;
        final dy = xyz[j + 1] - camera.py;
        final dz = xyz[j + 2] - camera.pz;
        final vz = dx * camera.fx + dy * camera.fy + dz * camera.fz;
        if (vz <= _Camera3d._near) continue;
        final k = camera.f / vz;
        final sx =
            camera.cx + (dx * camera.rx + dy * camera.ry + dz * camera.rz) * k;
        final sy =
            camera.cy - (dx * camera.ux + dy * camera.uy + dz * camera.uz) * k;
        if (sx < camera.minX ||
            sx > camera.maxX ||
            sy < camera.minY ||
            sy > camera.maxY) {
          continue;
        }
        final c = clsArr[i];
        if (c == 4 || c == 5) {
          objBuf[wObj++] = sx;
          objBuf[wObj++] = sy;
        } else if (c == 1) {
          roadBuf[wRoad++] = sx;
          roadBuf[wRoad++] = sy;
        } else {
          otherBuf[wOther++] = sx;
          otherBuf[wOther++] = sy;
        }
      }

      if (wOther > 0) {
        _semPointPaint.color = classColors.value[0] ?? _otherGrayColor;
        canvas.drawRawPoints(
          ui.PointMode.points,
          Float32List.sublistView(otherBuf, 0, wOther),
          _semPointPaint,
        );
      }
      if (wRoad > 0) {
        _semPointPaint.color = _roadBlueColor;
        canvas.drawRawPoints(
          ui.PointMode.points,
          Float32List.sublistView(roadBuf, 0, wRoad),
          _semPointPaint,
        );
      }
      if (wObj > 0) {
        canvas.drawRawPoints(
          ui.PointMode.points,
          Float32List.sublistView(objBuf, 0, wObj),
          _objRedPaint,
        );
      }
      return;
    }

    // RGB + Object Red or Height heatmap using 1 GPU drawVertices call
    scratch.ensureTriangles(n);
    final pos = scratch.triPositions;
    final col = scratch.triColors;
    final redBuf = mode == Depth3dColorMode.rgbObject
        ? scratch.ensureSecondary2d(n * 2)
        : null;

    int triVerts = 0;
    int posW = 0;
    int colW = 0;
    int redW = 0;
    const double h = 1.55;
    final rgbArr = cc.rgbArgb;

    for (int i = 0, j = 0; i < n; i++, j += 3) {
      final x = xyz[j];
      final y = xyz[j + 1];
      final z = xyz[j + 2];

      final dx = x - camera.px;
      final dy = y - camera.py;
      final dz = z - camera.pz;
      final vz = dx * camera.fx + dy * camera.fy + dz * camera.fz;
      if (vz <= _Camera3d._near) continue;
      final k = camera.f / vz;
      final sx =
          camera.cx + (dx * camera.rx + dy * camera.ry + dz * camera.rz) * k;
      final sy =
          camera.cy - (dx * camera.ux + dy * camera.uy + dz * camera.uz) * k;
      if (sx < camera.minX ||
          sx > camera.maxX ||
          sy < camera.minY ||
          sy > camera.maxY) {
        continue;
      }

      if (mode == Depth3dColorMode.rgbObject) {
        final cls = clsArr[i];
        if (cls == 4 || cls == 5) {
          redBuf![redW++] = sx;
          redBuf[redW++] = sy;
          continue;
        }
        final argb = rgbArr[i];
        pos[posW++] = sx;
        pos[posW++] = sy - h;
        pos[posW++] = sx - h;
        pos[posW++] = sy + h;
        pos[posW++] = sx + h;
        pos[posW++] = sy + h;
        col[colW++] = argb;
        col[colW++] = argb;
        col[colW++] = argb;
        triVerts += 3;
      } else {
        final argb = _heightArgb(z);
        pos[posW++] = sx;
        pos[posW++] = sy - h;
        pos[posW++] = sx - h;
        pos[posW++] = sy + h;
        pos[posW++] = sx + h;
        pos[posW++] = sy + h;
        col[colW++] = argb;
        col[colW++] = argb;
        col[colW++] = argb;
        triVerts += 3;
      }
    }

    if (triVerts > 0) {
      final vertices = ui.Vertices.raw(
        ui.VertexMode.triangles,
        Float32List.sublistView(pos, 0, posW),
        colors: Int32List.sublistView(col, 0, colW),
      );
      canvas.drawVertices(vertices, BlendMode.srcOver, _vertexPaint);
    }

    if (redBuf != null && redW > 0) {
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.sublistView(redBuf, 0, redW),
        _objRedPaint,
      );
    }
  }

  /// Smooth perceptual elevation ramp for `z` in [-1.5m, +2.5m].
  int _heightArgb(double z) {
    final t = ((z + 1.5) / 4.0).clamp(0.0, 1.0);
    int r, g, b;
    if (t < 0.25) {
      final u = t / 0.25;
      r = 30;
      g = (80 + 175 * u).round();
      b = 255;
    } else if (t < 0.5) {
      final u = (t - 0.25) / 0.25;
      r = (30 + 30 * u).round();
      g = 255;
      b = (255 * (1.0 - u)).round();
    } else if (t < 0.75) {
      final u = (t - 0.5) / 0.25;
      r = (60 + 195 * u).round();
      g = 255;
      b = 0;
    } else {
      final u = (t - 0.75) / 0.25;
      r = 255;
      g = (255 * (1.0 - u)).round();
      b = 20;
    }
    return 0xFF000000 | (r << 16) | (g << 8) | b;
  }

  void _drawWireframeBoxes(
    Canvas canvas,
    _Camera3d camera,
    List<_Box3d> boxes,
  ) {
    final corners = scratch.boxCorners;
    final styles = objectStyles.value;
    final fallbackColor = isLight ? _boxGreenLight : _boxGreenDark;

    for (final b in boxes) {
      final hl = b.l * 0.5;
      final hw = b.w * 0.5;
      final hh = b.h * 0.5;
      final cosY = math.cos(b.yaw);
      final sinY = math.sin(b.yaw);

      const localSigns = [
        [-1.0, -1.0, -1.0],
        [1.0, -1.0, -1.0],
        [1.0, 1.0, -1.0],
        [-1.0, 1.0, -1.0],
        [-1.0, -1.0, 1.0],
        [1.0, -1.0, 1.0],
        [1.0, 1.0, 1.0],
        [-1.0, 1.0, 1.0],
      ];

      bool allValid = true;
      for (int i = 0; i < 8; i++) {
        final s = localSigns[i];
        final lx = s[0] * hl;
        final ly = s[1] * hw;
        final lz = s[2] * hh;
        final wx = b.cx + lx * cosY - ly * sinY;
        final wy = b.cy + lx * sinY + ly * cosY;
        final wz = b.cz + lz;
        final p = camera.project(wx, wy, wz);
        if (p == null) {
          allValid = false;
          break;
        }
        corners[i * 2] = p.dx;
        corners[i * 2 + 1] = p.dy;
      }
      if (!allValid) continue;

      final style = styles[b.cls];
      final boxColor = style?.color ?? fallbackColor;
      _boxPaint.color = boxColor;

      if (b.isDepthOnly) {
        for (final e in _boxEdges) {
          final a = e[0] * 2;
          final c = e[1] * 2;
          _drawDashedLine(
            canvas,
            Offset(corners[a], corners[a + 1]),
            Offset(corners[c], corners[c + 1]),
            _boxPaint,
          );
        }
      } else {
        final path = Path();
        for (final e in _boxEdges) {
          final a = e[0] * 2;
          final c = e[1] * 2;
          path.moveTo(corners[a], corners[a + 1]);
          path.lineTo(corners[c], corners[c + 1]);
        }
        canvas.drawPath(path, _boxPaint);
      }

      // Draw class + ID + distance label above top-center of the box
      double topCenterX = 0.0;
      double minTopY = double.infinity;
      for (int i = 4; i < 8; i++) {
        topCenterX += corners[i * 2];
        if (corners[i * 2 + 1] < minTopY) {
          minTopY = corners[i * 2 + 1];
        }
      }
      topCenterX *= 0.25;

      final dist = math.sqrt(b.cx * b.cx + b.cy * b.cy);
      final labelName = style?.label ?? b.cls;
      final idPart = b.id != null ? ' #${b.id}' : '';
      final labelText = '$labelName$idPart · ${dist.toStringAsFixed(1)} m';

      final tp = TextPainter(
        text: TextSpan(
          text: labelText,
          style: const TextStyle(
            fontSize: 10.0,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      const padH = 6.0;
      const padV = 3.0;
      final pillW = tp.width + padH * 2;
      final pillH = tp.height + padV * 2;
      final pillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          topCenterX - pillW * 0.5,
          minTopY - pillH - 4.0,
          pillW,
          pillH,
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(
        pillRect,
        Paint()..color = boxColor.withValues(alpha: 0.88),
      );
      tp.paint(
        canvas,
        Offset(pillRect.left + padH, pillRect.top + padV),
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashLen = 5.0;
    const gapLen = 4.0;
    final total = (p2 - p1).distance;
    if (total <= 0.001) return;
    final dx = (p2.dx - p1.dx) / total;
    final dy = (p2.dy - p1.dy) / total;
    double cur = 0.0;
    while (cur < total) {
      final end = math.min(cur + dashLen, total);
      canvas.drawLine(
        Offset(p1.dx + dx * cur, p1.dy + dy * cur),
        Offset(p1.dx + dx * end, p1.dy + dy * end),
        paint,
      );
      cur += dashLen + gapLen;
    }
  }

  void _drawWaypoints(Canvas canvas, _Camera3d camera, Float32List wp) {
    final count = wp.length ~/ 2;
    if (count < 2) return;
    final path = Path();
    bool started = false;
    for (int i = 0; i < count; i++) {
      final p = camera.project(wp[i * 2], wp[i * 2 + 1], -0.2);
      if (p == null) {
        started = false;
        continue;
      }
      if (!started) {
        path.moveTo(p.dx, p.dy);
        started = true;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, _wpPaint);
  }

  void _drawEgoAxes(Canvas canvas, _Camera3d camera) {
    final origin = camera.project(0, 0, 0);
    if (origin == null) return;

    void drawAxis(double x, double y, double z, Color color) {
      final tip = camera.project(x, y, z);
      if (tip == null) return;
      _axisPaint.color = color;
      canvas.drawLine(origin, tip, _axisPaint);
    }

    drawAxis(1.6, 0, 0, const Color(0xFFFF3B30)); // +X forward (Red)
    drawAxis(0, 1.6, 0, const Color(0xFF22C55E)); // +Y left (Green)
    drawAxis(0, 0, 1.5, const Color(0xFF3B82F6)); // +Z up (Blue)

    canvas.drawCircle(origin, 3.0, Paint()..color = const Color(0xFF94A3B8));
  }

  @override
  bool shouldRepaint(covariant _Depth3dPainter oldDelegate) =>
      oldDelegate.isLight != isLight;
}
