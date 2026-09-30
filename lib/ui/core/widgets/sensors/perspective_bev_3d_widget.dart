import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../services/voice_navigation_service.dart';
import 'bev_3d_camera.dart';
import 'bev_3d_painter.dart';
import 'car_3d_viewer_widget.dart';
import 'models/detected_3d_object.dart';
import 'models/bev_scenario_type.dart';

/// Widget visualisasi 3D BEV berperspektif luas dengan Scenario Switcher
/// (1: Lurus, 2: Belok Kanan, 3: Belok Kiri, 4: Pertigaan, 5: Perempatan, dan AUTO Mode).
class PerspectiveBev3DWidget extends StatefulWidget {
  final double steeringAngle;
  final double speed;
  final BevScenarioType initialScenario;

  const PerspectiveBev3DWidget({
    super.key,
    this.steeringAngle = 0.0,
    this.speed = 20.0,
    this.initialScenario = BevScenarioType.straight,
  });

  @override
  State<PerspectiveBev3DWidget> createState() => _PerspectiveBev3DWidgetState();
}

class _PerspectiveBev3DWidgetState extends State<PerspectiveBev3DWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late Bev3DCamera _camera;

  BevScenarioType _currentScenario = BevScenarioType.straight;
  bool _isAutoCycle = false;
  Timer? _autoCycleTimer;
  bool _isVoiceMuted = false;
  StreamSubscription<bool>? _muteSub;

  @override
  void initState() {
    super.initState();
    _currentScenario = widget.initialScenario;
    _camera = const Bev3DCamera();
    _isVoiceMuted = VoiceNavigationService().isMuted;
    _muteSub = VoiceNavigationService().muteStream.listen((muted) {
      if (mounted) {
        setState(() => _isVoiceMuted = muted);
      }
    });

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    // Trigger pengumuman navigasi awal pada HUD pop-up
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _announceScenario(_currentScenario);
      }
    });
  }

  @override
  void dispose() {
    _muteSub?.cancel();
    _autoCycleTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _announceScenario(BevScenarioType scenario) {
    switch (scenario) {
      case BevScenarioType.straight:
        VoiceNavigationService().announce(
          const NavigationInstruction(
            text: 'Jalan lurus sejauh 50 meter',
            spokenText: 'Jalan lurus sejauh lima puluh meter',
            distanceText: '50m',
            icon: LucideIcons.arrowUp,
            bannerColor: Color(0xFF0288D1),
          ),
        );
        break;
      case BevScenarioType.rightTurn:
        VoiceNavigationService().announce(
          const NavigationInstruction(
            text: 'Setelah 15 meter, belok kanan',
            spokenText: 'Setelah lima belas meter, belok kanan',
            distanceText: '15m',
            icon: LucideIcons.cornerUpRight,
            bannerColor: Color(0xFF00C853),
          ),
        );
        break;
      case BevScenarioType.leftTurn:
        VoiceNavigationService().announce(
          const NavigationInstruction(
            text: 'Setelah 15 meter, belok kiri',
            spokenText: 'Setelah lima belas meter, belok kiri',
            distanceText: '15m',
            icon: LucideIcons.cornerUpLeft,
            bannerColor: Color(0xFF00B0FF),
          ),
        );
        break;
      case BevScenarioType.tJunction:
        VoiceNavigationService().announce(
          const NavigationInstruction(
            text: 'Mendekati pertigaan, kurangi kecepatan',
            spokenText: 'Mendekati pertigaan, kurangi kecepatan',
            distanceText: '10m',
            icon: LucideIcons.gitFork,
            bannerColor: Color(0xFFFF9100),
          ),
        );
        break;
      case BevScenarioType.crossroad:
        VoiceNavigationService().announce(
          const NavigationInstruction(
            text: 'Ada mobil berhenti di depan jarak 2 meter, menghentikan kendaraan',
            spokenText: 'Ada mobil berhenti di depan jarak dua meter, menghentikan kendaraan',
            distanceText: '2m',
            icon: LucideIcons.octagonAlert,
            bannerColor: Color(0xFFD50000),
            isWarning: true,
          ),
        );
        break;
    }
  }

  void _toggleAutoCycle() {
    setState(() {
      _isAutoCycle = !_isAutoCycle;
      if (_isAutoCycle) {
        _startAutoCycleTimer();
      } else {
        _autoCycleTimer?.cancel();
      }
    });
  }

  void _startAutoCycleTimer() {
    _autoCycleTimer?.cancel();
    _autoCycleTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      setState(() {
        final scenarios = BevScenarioType.values;
        final nextIndex = (_currentScenario.index + 1) % scenarios.length;
        _currentScenario = scenarios[nextIndex];
      });
      _announceScenario(_currentScenario);
    });
  }

  void _selectScenario(BevScenarioType scenario) {
    setState(() {
      _currentScenario = scenario;
      if (_isAutoCycle) {
        _isAutoCycle = false;
        _autoCycleTimer?.cancel();
      }
    });
    _announceScenario(scenario);
  }

  /// Menghasilkan daftar objek 3D terdeteksi secara realistis untuk setiap skenario jalan
  List<Detected3DObject> _getScenarioObjects(BevScenarioType scenario) {
    switch (scenario) {
      case BevScenarioType.straight:
        return const [
          Detected3DObject(
            id: 'car-passing-right',
            objectClass: Detected3DClass.car,
            x: 3.3,
            y: 0.0,
            z: 3.5,
            width: 1.95,
            height: 1.45,
            length: 4.3,
            yawDeg: 0.0,
            customLabel: 'Passing Car',
          ),
          Detected3DObject(
            id: 'car-parked-left',
            objectClass: Detected3DClass.car,
            x: -4.8,
            y: 0.0,
            z: 12.0,
            width: 1.95,
            height: 1.45,
            length: 4.3,
            yawDeg: 0.0,
            isParked: true,
            customLabel: 'Parked Car',
          ),
          Detected3DObject(
            id: 'pedestrian-right',
            objectClass: Detected3DClass.pedestrian,
            x: 5.2,
            y: 0.0,
            z: 8.5,
            width: 0.75,
            height: 1.80,
            length: 0.75,
            yawDeg: -15.0,
            customLabel: 'Pedestrian',
          ),
          Detected3DObject(
            id: 'traffic-ahead',
            objectClass: Detected3DClass.car,
            x: 0.0,
            y: 0.0,
            z: 20.0,
            width: 1.95,
            height: 1.50,
            length: 4.4,
            yawDeg: 0.0,
            customLabel: 'Ahead Car',
          ),
        ];

      case BevScenarioType.rightTurn:
        return const [
          Detected3DObject(
            id: 'car-curve-ahead',
            objectClass: Detected3DClass.car,
            x: 6.5,
            y: 0.0,
            z: 18.0,
            width: 1.95,
            height: 1.45,
            length: 4.3,
            yawDeg: 80.0,
            customLabel: 'Lead Car',
          ),
          Detected3DObject(
            id: 'bike-shoulder-left',
            objectClass: Detected3DClass.bicycle,
            x: -3.8,
            y: 0.0,
            z: 7.5,
            width: 0.70,
            height: 1.40,
            length: 1.8,
            yawDeg: 0.0,
            customLabel: 'Bicycle',
          ),
          Detected3DObject(
            id: 'pedestrian-corner',
            objectClass: Detected3DClass.pedestrian,
            x: 3.5,
            y: 0.0,
            z: 11.0,
            width: 0.75,
            height: 1.80,
            length: 0.75,
            yawDeg: -45.0,
            customLabel: 'Pedestrian',
          ),
        ];

      case BevScenarioType.leftTurn:
        return const [
          Detected3DObject(
            id: 'car-left-ahead',
            objectClass: Detected3DClass.car,
            x: -6.5,
            y: 0.0,
            z: 18.0,
            width: 1.95,
            height: 1.45,
            length: 4.3,
            yawDeg: -80.0,
            customLabel: 'Lead Car',
          ),
          Detected3DObject(
            id: 'pedestrian-left',
            objectClass: Detected3DClass.pedestrian,
            x: -3.5,
            y: 0.0,
            z: 11.0,
            width: 0.75,
            height: 1.80,
            length: 0.75,
            yawDeg: 45.0,
            customLabel: 'Pedestrian',
          ),
          Detected3DObject(
            id: 'truck-right',
            objectClass: Detected3DClass.truck,
            x: 4.2,
            y: 0.0,
            z: 8.0,
            width: 2.2,
            height: 2.6,
            length: 5.8,
            yawDeg: 0.0,
            isParked: true,
            customLabel: 'Truck',
          ),
        ];

      case BevScenarioType.tJunction:
        return const [
          Detected3DObject(
            id: 'car-waiting-junction',
            objectClass: Detected3DClass.car,
            x: 4.5,
            y: 0.0,
            z: 14.0,
            width: 1.95,
            height: 1.45,
            length: 4.2,
            yawDeg: -80.0,
            customLabel: 'Turning Car',
          ),
          Detected3DObject(
            id: 'pedestrian-junction',
            objectClass: Detected3DClass.pedestrian,
            x: 3.8,
            y: 0.0,
            z: 7.5,
            width: 0.75,
            height: 1.80,
            length: 0.75,
            yawDeg: -90.0,
            customLabel: 'Crossing',
          ),
          Detected3DObject(
            id: 'car-ahead-junction',
            objectClass: Detected3DClass.car,
            x: -0.5,
            y: 0.0,
            z: 22.0,
            width: 1.95,
            height: 1.45,
            length: 4.3,
            yawDeg: 0.0,
            customLabel: 'Car Ahead',
          ),
        ];

      case BevScenarioType.crossroad:
        return const [
          Detected3DObject(
            id: 'car-stopped-ahead',
            objectClass: Detected3DClass.car,
            x: 0.0,
            y: 0.0,
            z: 6.2,
            width: 1.95,
            height: 1.45,
            length: 4.3,
            yawDeg: 0.0,
            isParked: true,
            customLabel: 'Mobil Berhenti',
            customDistance: '2.0m',
          ),
          Detected3DObject(
            id: 'pedestrian-sidewalk',
            objectClass: Detected3DClass.pedestrian,
            x: 4.2,
            y: 0.0,
            z: 8.0,
            width: 0.75,
            height: 1.80,
            length: 0.75,
            yawDeg: -15.0,
            customLabel: 'Pedestrian',
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final objects = _getScenarioObjects(_currentScenario);
    final effectiveSteering = _currentScenario.defaultSteeringAngle != 0.0
        ? _currentScenario.defaultSteeringAngle
        : widget.steeringAngle;
    final effectiveSpeed = _currentScenario == BevScenarioType.crossroad
        ? 0.0
        : widget.speed;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. Background 3D Ground, Road Mesh, Trajectory Ribbon, & 3D Bounding Boxes
                Positioned.fill(
                  child: CustomPaint(
                    painter: Bev3DPainter(
                      camera: _camera,
                      scenario: _currentScenario,
                      steeringAngle: effectiveSteering,
                      speed: effectiveSpeed,
                      animationValue: _animController.value,
                      detectedObjects: objects,
                      isLight: isLight,
                    ),
                  ),
                ),

                // 2. Floating Badges Melayang di Atas Setiap 3D Bounding Box
                ..._buildFloatingBadges(size, isLight, objects),

                // 3. Ego Vehicle MEVI 3D Model Murni (Menghadap ke Depan / Chase View, Skala 1:1)
                _buildEgoVehicle3D(size, effectiveSteering, effectiveSpeed),

                // 4. Panel Tombol Switcher Skenario Jalan di Bawah Mobil MEVI
                _buildScenarioControlBar(size, isLight),
              ],
            );
          },
        );
      },
    );
  }

  List<Widget> _buildFloatingBadges(
    Size size,
    bool isLight,
    List<Detected3DObject> objects,
  ) {
    final widgets = <Widget>[];

    for (final obj in objects) {
      const floatStemHeight = 0.45;
      final pTopCenter = _camera.project(
        obj.x,
        obj.y + obj.height + floatStemHeight,
        obj.z,
        size,
      );

      if (!pTopCenter.isVisible) continue;

      final primaryColor = obj.objectClass.primaryColor;
      final distanceStr = obj.customDistance ?? '${obj.z.toStringAsFixed(1)}m';
      final labelText = obj.customLabel ?? obj.objectClass.label;

      final scale = (1.15 / (pTopCenter.depth * 0.15)).clamp(0.65, 1.05);

      widgets.add(
        Positioned(
          left: pTopCenter.screenOffset.dx - 60,
          top: pTopCenter.screenOffset.dy - 38,
          child: IgnorePointer(
            child: Transform.scale(
              scale: scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isLight
                          ? Colors.white.withValues(alpha: 0.96)
                          : const Color(0xFF1E2638).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primaryColor, width: 1.6),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(
                            alpha: isLight ? 0.35 : 0.50,
                          ),
                          blurRadius: 10,
                          spreadRadius: 1,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            obj.objectClass.iconData,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          labelText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isLight
                                ? const Color(0xFF1A2138)
                                : Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            distanceStr,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1.5,
                    height: 8,
                    color: primaryColor.withValues(alpha: 0.8),
                  ),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildEgoVehicle3D(
    Size size,
    double steeringAngle,
    double effectiveSpeed,
  ) {
    // Proyeksi lebar mobil 1.95m pada posisi z = 1.0 (posisi mobil ego MEVI)
    final pLeft = _camera.project(-0.95, 0.0, 1.0, size);
    final pRight = _camera.project(0.95, 0.0, 1.0, size);
    final pCenter = _camera.project(0.0, 0.0, 1.0, size);

    final rawWidth = (pRight.screenOffset.dx - pLeft.screenOffset.dx).abs();
    // Skala 1:1 proporsional terhadap mobil & bounding box di jalan (~1.68x untuk mengimbangi margin internal model-viewer)
    final carWidth = (rawWidth > 30.0 ? rawWidth : 92.0) * 1.68;
    final carHeight = carWidth * 1.28;

    final egoCenterX = pCenter.screenOffset.dx;
    final egoCenterY = pCenter.screenOffset.dy;

    final egoLeft = egoCenterX - (carWidth / 2.0);
    // Letakkan ego tepat di posisi pCenter agar roda menapak jalan secara presisi
    final egoTop = egoCenterY - (carHeight * 0.58);

    final tilt = (steeringAngle / 35.0).clamp(-1.0, 1.0);

    return Positioned(
      left: egoLeft,
      top: egoTop,
      width: carWidth,
      height: carHeight,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: tilt * (math.pi / 45.0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                bottom: 12,
                child: Container(
                  width: carWidth * 0.58,
                  height: carHeight * 0.22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00B0FF).withValues(alpha: 0.45),
                        blurRadius: 24,
                        spreadRadius: 3,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: Car3DViewerWidget(
                  speed: effectiveSpeed,
                  steeringAngle: steeringAngle,
                  cameraOrbit: '0deg 50deg 86%',
                  height: carHeight,
                  width: carWidth,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 4. Panel Tombol Skenario Jalan di Bawah MEVI 3D (Gaya Glassmorphism Dashboard)
  Widget _buildScenarioControlBar(Size size, bool isLight) {
    return Positioned(
      bottom: 12,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isLight
                ? Colors.white.withValues(alpha: 0.92)
                : const Color(0xFF141C2A).withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isLight
                  ? const Color(0xFFB0BEC5).withValues(alpha: 0.4)
                  : const Color(0xFF37474F).withValues(alpha: 0.6),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tombol 1 s/d 5
                for (final scenario in BevScenarioType.values) ...[
                  _buildScenarioButton(scenario, isLight),
                  const SizedBox(width: 5),
                ],

                // Divider Vertikal
                Container(
                  width: 1,
                  height: 22,
                  color: isLight ? Colors.black12 : Colors.white24,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),

                // Tombol AUTO Mode (Cycle per 5 detik)
                _buildAutoButton(isLight),

                // Divider Vertikal
                Container(
                  width: 1,
                  height: 22,
                  color: isLight ? Colors.black12 : Colors.white24,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),

                // Tombol Speaker (Mute / Unmute Suara Navigasi Otonom)
                _buildSpeakerButton(isLight),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScenarioButton(BevScenarioType scenario, bool isLight) {
    final isSelected = _currentScenario == scenario && !_isAutoCycle;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectScenario(scenario),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF0288D1)
                : (isLight ? const Color(0xFFF0F4F8) : const Color(0xFF1E2838)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? const Color(0xFF40C4FF) : Colors.transparent,
              width: 1.4,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF0288D1).withValues(alpha: 0.45),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                scenario.number,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? Colors.white
                      : (isLight ? const Color(0xFF1A2331) : Colors.white70),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                scenario.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isLight ? const Color(0xFF455A64) : Colors.white60),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutoButton(bool isLight) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleAutoCycle,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _isAutoCycle
                ? const Color(0xFF00C853)
                : (isLight ? const Color(0xFFF0F4F8) : const Color(0xFF1E2838)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isAutoCycle
                  ? const Color(0xFF69F0AE)
                  : Colors.transparent,
              width: 1.4,
            ),
            boxShadow: _isAutoCycle
                ? [
                    BoxShadow(
                      color: const Color(0xFF00C853).withValues(alpha: 0.45),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.repeat,
                size: 13,
                color: _isAutoCycle
                    ? Colors.white
                    : (isLight ? const Color(0xFF1A2331) : Colors.white70),
              ),
              const SizedBox(width: 5),
              Text(
                'AUTO (5s)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: _isAutoCycle ? FontWeight.w800 : FontWeight.w600,
                  color: _isAutoCycle
                      ? Colors.white
                      : (isLight ? const Color(0xFF1A2331) : Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeakerButton(bool isLight) {
    final isMuted = _isVoiceMuted;

    return Tooltip(
      message: isMuted ? 'Aktifkan Suara Navigasi' : 'Bisukan Suara Navigasi (Mute)',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            VoiceNavigationService().toggleMute();
            setState(() {
              _isVoiceMuted = VoiceNavigationService().isMuted;
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isMuted
                  ? (isLight
                      ? const Color(0xFFFFEBEE)
                      : const Color(0xFF2C161A))
                  : (isLight
                      ? const Color(0xFFE1F5FE)
                      : const Color(0xFF142436)),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isMuted
                    ? const Color(0xFFEF5350).withValues(alpha: 0.7)
                    : const Color(0xFF0288D1).withValues(alpha: 0.7),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isMuted
                          ? const Color(0xFFEF5350)
                          : const Color(0xFF0288D1))
                      .withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isMuted ? LucideIcons.volumeX : LucideIcons.volume2,
                  size: 14,
                  color: isMuted
                      ? const Color(0xFFE53935)
                      : (isLight ? const Color(0xFF0288D1) : const Color(0xFF40C4FF)),
                ),
                const SizedBox(width: 4),
                Text(
                  isMuted ? 'MUTE' : 'VOICE',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isMuted
                        ? const Color(0xFFE53935)
                        : (isLight ? const Color(0xFF0288D1) : const Color(0xFF40C4FF)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
