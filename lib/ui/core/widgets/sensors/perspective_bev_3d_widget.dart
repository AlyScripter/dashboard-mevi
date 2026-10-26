import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../services/ros_service.dart';
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

  /// Cache snapshot 3D model mobil MEVI di GPU Flutter.
  /// Bersifat static agar persisten antar navigasi halaman (0ms reload).
  static ui.Image? _cachedEgoSnapshot;

  BevScenarioType _currentScenario = BevScenarioType.straight;
  bool _isAutoCycle = false;
  Timer? _autoCycleTimer;
  bool _isVoiceMuted = false;
  StreamSubscription<bool>? _muteSub;

  // Live WebSocket ROS Stream Integration (Metode 1: Waypoint-Corridor + Fase 6: Scene)
  StreamSubscription<Map<String, dynamic>>? _bevFrameSub;
  StreamSubscription<Map<String, dynamic>>? _bevSceneSub;
  bool _isLiveMode = true;
  List<Offset>? _liveWaypoints;
  double? _liveWaypointsEndDistance;
  List<Detected3DObject>? _liveObjects;
  Map<String, dynamic>? _liveRoadScene;
  int _roadHoldCount = 0;
  int? _liveFrameIdx;
  int _livePointCount = 0;
  DateTime? _lastLiveFrameTime;

  // Camera Mode State (Chase, Top, Free)
  BevCameraMode _cameraMode = BevCameraMode.chase;
  double _freeYaw = 0.0;
  double _freePitch = 32.0;
  double _freeDist = 20.0;
  Offset? _lastPanPos;

  // Dynamic Live Voice Navigation Assistant & Destination Tracking
  String? _lastAnnouncedManeuverKey;
  DateTime? _lastSpokenTime;
  bool _hasReceivedActiveWaypoints = false;
  bool _hasAnnouncedArrival = false;

  @override
  void initState() {
    super.initState();
    _currentScenario = widget.initialScenario;
    _camera = Bev3DCamera.chase();
    _isVoiceMuted = VoiceNavigationService().isMuted;
    _muteSub = VoiceNavigationService().muteStream.listen((muted) {
      if (mounted) {
        setState(() => _isVoiceMuted = muted);
      }
    });

    _bevFrameSub = RosService().bevFrameStream.listen(_onLiveBevFrame);
    _bevSceneSub = RosService().bevSceneStream.listen(_onLiveBevScene);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    // Trigger initial navigation announcement on HUD pop-up
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (_isLiveMode) {
          VoiceNavigationService().announce(
            const NavigationInstruction(
              text: 'Live Autonomous Navigation Active',
              spokenText: 'Live autonomous navigation active',
              distanceText: 'Live',
              icon: LucideIcons.radio,
              bannerColor: Color(0xFF00C853),
            ),
            playVoice: true,
          );
        } else {
          _announceScenario(_currentScenario);
        }
      }
    });
  }

  Future<void> _onEgoSnapshot(Uint8List png) async {
    if (_cachedEgoSnapshot != null) return;
    try {
      final codec = await ui.instantiateImageCodec(png);
      final fr = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        fr.image.dispose();
        return;
      }
      setState(() => _cachedEgoSnapshot = fr.image);
    } catch (e) {
      debugPrint('PerspectiveBev3DWidget: snapshot ego gagal: $e');
    }
  }

  @override
  void didUpdateWidget(covariant PerspectiveBev3DWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isLiveMode &&
        _hasReceivedActiveWaypoints &&
        !_hasAnnouncedArrival &&
        widget.speed < 1.2) {
      final dist = _liveWaypointsEndDistance;
      if (_liveWaypoints == null ||
          _liveWaypoints!.length < 2 ||
          (dist != null && dist <= 2.2)) {
        _checkAndTriggerArrival();
      }
    }
  }

  void _checkAndTriggerArrival() {
    if (!_isLiveMode || !_hasReceivedActiveWaypoints || _hasAnnouncedArrival) return;
    if (widget.speed < 1.2) {
      _hasAnnouncedArrival = true;
      const instruction = NavigationInstruction(
        text: 'You have arrived at your destination',
        spokenText: 'You have arrived at your destination',
        distanceText: 'Arrived',
        icon: LucideIcons.mapPinCheck,
        bannerColor: Color(0xFF00C853),
      );
      _triggerLiveAnnounce(instruction, 'destination_arrived');
    }
  }

  @override
  void dispose() {
    // Hentikan suara navigasi seketika dan bersihkan HUD banner
    VoiceNavigationService().stop();
    VoiceNavigationService().clearInstruction();

    _bevFrameSub?.cancel();
    _bevSceneSub?.cancel();
    _muteSub?.cancel();
    _autoCycleTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _onLiveBevScene(Map<String, dynamic> scene) {
    try {
      final sv = scene['sv'];
      if (sv != 4) return; // Guard: Hanya kontrak sv:4 (road-only)

      final frameIdx = (scene['i'] as num?)?.toInt();
      final road = scene['road'] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          if (road != null && road['p'] is List && (road['p'] as List).isNotEmpty) {
            _liveRoadScene = scene;
            _roadHoldCount = 0; // reset hitungan tahan frame
          } else {
            // Frame tanpa jalan (road: null) -> Tahan jalan terakhir <= 4 frame
            if (_roadHoldCount < 4) {
              _roadHoldCount++;
            } else {
              _liveRoadScene = null;
            }
          }
          if (frameIdx != null) _liveFrameIdx = frameIdx;
          _lastLiveFrameTime = DateTime.now();
        });
      }
    } catch (e) {
      debugPrint('PerspectiveBev3DWidget: gagal parse live scene: $e');
    }
  }

  void _onLiveBevFrame(Map<String, dynamic> msg) {
    try {
      final raw = msg['raw'];
      if (raw is! Map) return;

      final frameIdx = (msg['frame_idx'] as num?)?.toInt();
      final pointCount = (msg['point_count'] as num?)?.toInt() ?? 0;

      // 1. Waypoints: raw['wp'] -> List of [x, y] in ROS ego coordinate
      // ROS: x = forward (meter), y = left (meter)
      // Camera 3D: cz = forward (meter), cx = lateral (+ kanan, - kiri)
      List<Offset>? parsedWp;
      double? maxDist;
      final wpList = raw['wp'];
      if (wpList is List && wpList.isNotEmpty) {
        final tmp = <Offset>[];
        for (final p in wpList) {
          if (p is List && p.length >= 2) {
            final xRos = (p[0] as num).toDouble();
            final yRos = (p[1] as num).toDouble();
            // cx = -yRos, cz = xRos
            tmp.add(Offset(-yRos, xRos));
          }
        }
        if (tmp.length >= 2) {
          parsedWp = tmp;
          double maxZ = 0.0;
          for (final p in tmp) {
            if (p.dy > maxZ) maxZ = p.dy;
          }
          maxDist = maxZ + 0.6;
        }
      }

      // 2. 3D Detected Objects: raw['obj'] -> List of {id, cls, cx, cy, cz, l, w, h, yaw}
      List<Detected3DObject>? parsedObjs;
      final objList = raw['obj'];
      if (objList is List) {
        final tmpObj = <Detected3DObject>[];
        for (int i = 0; i < objList.length; i++) {
          final o = objList[i];
          if (o is! Map) continue;
          final id = o['id']?.toString() ?? 'obj_$i';
          final clsStr = (o['cls'] as String? ?? 'car').toLowerCase();
          final statusStr = o['st']?.toString();
          final isDepthOnly = statusStr == 'depth_only';

          final Detected3DClass cls;
          if (clsStr.contains('pedestrian') || clsStr.contains('person')) {
            cls = Detected3DClass.pedestrian;
          } else if (clsStr.contains('motorcycle') ||
              clsStr.contains('motor') ||
              clsStr.contains('scooter')) {
            cls = Detected3DClass.motorcycle;
          } else if (clsStr.contains('bike') ||
              clsStr.contains('bicycle') ||
              clsStr.contains('cyc')) {
            cls = Detected3DClass.bicycle;
          } else if (clsStr.contains('truck') || clsStr.contains('bus')) {
            cls = Detected3DClass.truck;
          } else if (clsStr.contains('cone')) {
            cls = Detected3DClass.trafficCone;
          } else {
            cls = Detected3DClass.car;
          }

          final double cx = (o['cx'] as num?)?.toDouble() ?? 0.0;
          final double cy = (o['cy'] as num?)?.toDouble() ?? 0.0;
          final double cz = (o['cz'] as num?)?.toDouble() ?? 0.0;
          final double l = (o['l'] as num?)?.toDouble() ?? 4.2;
          final double w = (o['w'] as num?)?.toDouble() ?? 1.8;
          final double h = (o['h'] as num?)?.toDouble() ?? 1.5;
          final double yaw = (o['yaw'] as num?)?.toDouble() ?? 0.0;

          tmpObj.add(
            Detected3DObject(
              id: id,
              objectClass: cls,
              x: -cy,
              y: math.max(0.0, cz - h / 2.0),
              z: cx,
              width: w,
              height: h,
              length: l,
              yawDeg: -yaw * 180.0 / math.pi,
              isDepthOnly: isDepthOnly,
              status: statusStr,
              customLabel: isDepthOnly ? '${cls.label} [Depth]' : cls.label,
              customDistance: '${cx.toStringAsFixed(1)}m',
            ),
          );
        }
        parsedObjs = tmpObj;
      }

      if (mounted) {
        setState(() {
          _liveFrameIdx = frameIdx;
          _livePointCount = pointCount;
          _lastLiveFrameTime = DateTime.now();
          if (parsedWp != null) {
            _liveWaypoints = parsedWp;
            _liveWaypointsEndDistance = maxDist;
          }
          if (parsedObjs != null) {
            _liveObjects = parsedObjs;
          }
        });

        // Dynamic Live Voice Guidance & Realtime HUD Navigation
        if (_isLiveMode) {
          if (parsedWp != null && parsedWp.length >= 2) {
            _hasReceivedActiveWaypoints = true;
            // Reset arrival status if vehicle receives a new active route and moves
            if (widget.speed > 2.0 && (maxDist ?? 0.0) > 5.0) {
              _hasAnnouncedArrival = false;
            }
            _updateLiveNavigationInstructions(parsedWp, parsedObjs, maxDist);
          } else {
            // Waypoints depleted or finished
            _checkAndTriggerArrival();
          }
        }
      }
    } catch (e) {
      debugPrint('PerspectiveBev3DWidget: gagal parse live frame: $e');
    }
  }

  /// Menganalisis kurvatur lintasan waypoints dan rintangan untuk menghasilkan
  /// instruksi suara & HUD banner navigasi dinamis secara realtime
  void _updateLiveNavigationInstructions(
    List<Offset> waypoints,
    List<Detected3DObject>? objects,
    double? maxDist,
  ) {
    if (waypoints.length < 2) return;

    // 0. Cek kondisi akhir rute saat mobil berhenti di titik tujuan
    if (_hasReceivedActiveWaypoints &&
        !_hasAnnouncedArrival &&
        widget.speed < 1.2 &&
        (maxDist != null && maxDist <= 2.2)) {
      _checkAndTriggerArrival();
      return;
    }

    // 1. Cek rintangan/mobil berhenti tepat di depan jalur mobil ego (Prioritas Tertinggi)
    if (objects != null && objects.isNotEmpty) {
      Detected3DObject? hazardAhead;
      for (final obj in objects) {
        if (obj.z > 0.8 && obj.z < 7.5 && obj.x.abs() < 1.4) {
          hazardAhead = obj;
          break;
        }
      }
      if (hazardAhead != null) {
        final distStr = hazardAhead.z.toStringAsFixed(1);
        final distInt = math.max(1, hazardAhead.z.round());
        String label = 'Vehicle';
        if (hazardAhead.objectClass == Detected3DClass.pedestrian) {
          label = 'Pedestrian';
        } else if (hazardAhead.objectClass == Detected3DClass.bicycle) {
          label = 'Bicycle';
        } else if (hazardAhead.customLabel != null && hazardAhead.customLabel!.isNotEmpty) {
          label = hazardAhead.customLabel!;
        }

        final instruction = NavigationInstruction(
          text: 'Warning: $label ahead (${distStr}m)',
          spokenText: 'Warning, $label ahead in $distInt meters',
          distanceText: '${distStr}m',
          icon: LucideIcons.octagonAlert,
          bannerColor: const Color(0xFFD50000),
          isWarning: true,
        );
        _triggerLiveAnnounce(instruction, 'hazard_${hazardAhead.id}');
        return;
      }
    }

    // 2. Analisis kurvatur lintasan & manuver dari arah waypoints masa depan
    final p0 = waypoints[0];
    int nearIdx = 1;
    for (int i = 1; i < waypoints.length; i++) {
      if ((waypoints[i] - p0).distance >= 2.5) {
        nearIdx = i;
        break;
      }
    }
    final pNear = waypoints[nearIdx];
    final nearAngle = math.atan2(pNear.dx - p0.dx, pNear.dy - p0.dy);

    double maxDeflectionRad = 0.0;
    double maneuverDistMeters = 15.0;

    for (int i = nearIdx + 1; i < waypoints.length; i++) {
      final p = waypoints[i];
      final distFromCar = (p - p0).distance;
      if (distFromCar > 28.0) break;

      final segAngle = math.atan2(p.dx - p0.dx, p.dy - p0.dy);
      var diff = segAngle - nearAngle;
      while (diff > math.pi) {
        diff -= 2 * math.pi;
      }
      while (diff < -math.pi) {
        diff += 2 * math.pi;
      }

      if (diff.abs() > maxDeflectionRad.abs()) {
        maxDeflectionRad = diff;
        maneuverDistMeters = distFromCar;
      }
    }

    final maxDeflectionDeg = maxDeflectionRad * 180.0 / math.pi;
    final distInt = math.max(2, maneuverDistMeters.round());

    NavigationInstruction instruction;
    String maneuverKey;

    if (maxDeflectionDeg > 22.0) {
      // Turn Right
      if (maneuverDistMeters > 7.0) {
        instruction = NavigationInstruction(
          text: 'In $distInt meters, turn right',
          spokenText: 'In $distInt meters, turn right',
          distanceText: '${distInt}m',
          icon: LucideIcons.cornerUpRight,
          bannerColor: const Color(0xFF00C853),
        );
        maneuverKey = 'turn_right_${(distInt / 5).round() * 5}';
      } else {
        instruction = const NavigationInstruction(
          text: 'Turn right now',
          spokenText: 'Turn right now',
          distanceText: 'Turn',
          icon: LucideIcons.arrowUpRight,
          bannerColor: Color(0xFF00E676),
        );
        maneuverKey = 'turn_right_now';
      }
    } else if (maxDeflectionDeg < -22.0) {
      // Turn Left
      if (maneuverDistMeters > 7.0) {
        instruction = NavigationInstruction(
          text: 'In $distInt meters, turn left',
          spokenText: 'In $distInt meters, turn left',
          distanceText: '${distInt}m',
          icon: LucideIcons.cornerUpLeft,
          bannerColor: const Color(0xFF00B0FF),
        );
        maneuverKey = 'turn_left_${(distInt / 5).round() * 5}';
      } else {
        instruction = const NavigationInstruction(
          text: 'Turn left now',
          spokenText: 'Turn left now',
          distanceText: 'Turn',
          icon: LucideIcons.arrowUpLeft,
          bannerColor: Color(0xFF40C4FF),
        );
        maneuverKey = 'turn_left_now';
      }
    } else {
      // Straight
      instruction = const NavigationInstruction(
        text: 'Continue straight on route',
        spokenText: 'Continue straight on route',
        distanceText: 'Straight',
        icon: LucideIcons.arrowUp,
        bannerColor: Color(0xFF0288D1),
      );
      maneuverKey = 'straight';
    }

    _triggerLiveAnnounce(instruction, maneuverKey);
  }

  void _triggerLiveAnnounce(NavigationInstruction instruction, String key) {
    if (!mounted) return;

    // 1. Update visual HUD banner in realtime (playVoice = false agar tidak memicu audio ganda)
    VoiceNavigationService().announce(instruction, playVoice: false);

    // 2. Audio TTS: Debounce repeat audio announcements to prevent spam
    final now = DateTime.now();
    final isNewManeuver = _lastAnnouncedManeuverKey != key;
    final timeSinceLastSpoken = _lastSpokenTime == null
        ? 999
        : now.difference(_lastSpokenTime!).inSeconds;

    if (instruction.isWarning ||
        (isNewManeuver && timeSinceLastSpoken >= 5) ||
        timeSinceLastSpoken >= 12) {
      _lastAnnouncedManeuverKey = key;
      _lastSpokenTime = now;
      if (mounted && !VoiceNavigationService().isMuted) {
        VoiceNavigationService().speak(instruction.spokenText);
      }
    }
  }

  void _announceScenario(BevScenarioType scenario) {
    if (!mounted) return;
    switch (scenario) {
      case BevScenarioType.straight:
        VoiceNavigationService().announce(
          const NavigationInstruction(
            text: 'Proceed straight for 50 meters',
            spokenText: 'Proceed straight for fifty meters',
            distanceText: '50m',
            icon: LucideIcons.arrowUp,
            bannerColor: Color(0xFF0288D1),
          ),
          playVoice: true,
        );
        break;
      case BevScenarioType.rightTurn:
        VoiceNavigationService().announce(
          const NavigationInstruction(
            text: 'In 15 meters, turn right',
            spokenText: 'In fifteen meters, turn right',
            distanceText: '15m',
            icon: LucideIcons.cornerUpRight,
            bannerColor: Color(0xFF00C853),
          ),
          playVoice: true,
        );
        break;
      case BevScenarioType.leftTurn:
        VoiceNavigationService().announce(
          const NavigationInstruction(
            text: 'In 15 meters, turn left',
            spokenText: 'In fifteen meters, turn left',
            distanceText: '15m',
            icon: LucideIcons.cornerUpLeft,
            bannerColor: Color(0xFF00B0FF),
          ),
          playVoice: true,
        );
        break;
      case BevScenarioType.tJunction:
        VoiceNavigationService().announce(
          const NavigationInstruction(
            text: 'Approaching T-junction, reduce speed',
            spokenText: 'Approaching T-junction, reduce speed',
            distanceText: '10m',
            icon: LucideIcons.gitFork,
            bannerColor: Color(0xFFFF9100),
          ),
          playVoice: true,
        );
        break;
      case BevScenarioType.crossroad:
        VoiceNavigationService().announce(
          const NavigationInstruction(
            text: 'Vehicle stopped ahead in 2 meters, stopping vehicle',
            spokenText: 'Vehicle stopped ahead in two meters, stopping vehicle',
            distanceText: '2m',
            icon: LucideIcons.octagonAlert,
            bannerColor: Color(0xFFD50000),
            isWarning: true,
          ),
          playVoice: true,
        );
        break;
    }
  }

  void _toggleAutoCycle() {
    setState(() {
      _isAutoCycle = !_isAutoCycle;
      if (_isAutoCycle) {
        _isLiveMode = false;
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
        _isLiveMode = false;
      });
      _announceScenario(_currentScenario);
    });
  }

  void _selectScenario(BevScenarioType scenario) {
    setState(() {
      _currentScenario = scenario;
      _isLiveMode = false;
      _lastAnnouncedManeuverKey = null;
      _lastSpokenTime = null;
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

    final isLiveConnected = _lastLiveFrameTime != null &&
        DateTime.now().difference(_lastLiveFrameTime!).inSeconds < 4;

    // Mode Live: Jika belum ada data dari WebSocket / belum terkoneksi,
    // tampilkan jalan lurus bersih TANPA objek yang terdeteksi sama sekali.
    // Begitu data WebSocket tiba, otomatis menyesuaikan secara realtime.
    final effectiveObjects = _isLiveMode
        ? (isLiveConnected
            ? (_liveObjects ?? const <Detected3DObject>[])
            : const <Detected3DObject>[])
        : _getScenarioObjects(_currentScenario);

    final effectiveWaypoints = (_isLiveMode && isLiveConnected)
        ? _liveWaypoints
        : null;

    final effectiveSteering = _isLiveMode
        ? widget.steeringAngle
        : (_currentScenario.defaultSteeringAngle != 0.0
            ? _currentScenario.defaultSteeringAngle
            : widget.steeringAngle);

    final effectiveSpeed = _isLiveMode
        ? widget.speed
        : (_currentScenario == BevScenarioType.crossroad ? 0.0 : widget.speed);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        // Update instance kamera berdasarkan mode aktif
        switch (_cameraMode) {
          case BevCameraMode.chase:
            _camera = Bev3DCamera.chase();
            break;
          case BevCameraMode.free:
            _camera = Bev3DCamera.free(
              orbitYawDeg: _freeYaw,
              orbitPitchDeg: _freePitch,
              orbitDistance: _freeDist,
            );
            break;
        }

        return AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Layer interaksi gesture untuk mode Kamera Bebas
                if (_cameraMode == BevCameraMode.free)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (details) {
                        _lastPanPos = details.localPosition;
                      },
                      onPanUpdate: (details) {
                        if (_lastPanPos == null) {
                          _lastPanPos = details.localPosition;
                          return;
                        }
                        final dx = details.localPosition.dx - _lastPanPos!.dx;
                        final dy = details.localPosition.dy - _lastPanPos!.dy;
                        _lastPanPos = details.localPosition;
                        setState(() {
                          _freeYaw = (_freeYaw + dx * 0.45) % 360.0;
                          _freePitch = (_freePitch + dy * 0.35).clamp(8.0, 88.0);
                        });
                      },
                      onPanEnd: (_) => _lastPanPos = null,
                    ),
                  ),

                // 1. Background 3D Ground, Road Mesh, Trajectory Ribbon, & 3D Bounding Boxes
                Positioned.fill(
                  key: const ValueKey('bev-3d-ground-mesh'),
                  child: IgnorePointer(
                    ignoring: _cameraMode == BevCameraMode.free,
                    child: CustomPaint(
                      painter: Bev3DPainter(
                        camera: _camera,
                        scenario: _isLiveMode
                            ? BevScenarioType.straight
                            : _currentScenario,
                        steeringAngle: effectiveSteering,
                        speed: effectiveSpeed,
                        animationValue: _animController.value,
                        detectedObjects: effectiveObjects,
                        isLight: isLight,
                        liveWaypoints: effectiveWaypoints,
                        isLiveMode: _isLiveMode && isLiveConnected,
                        liveWaypointsEndDistance: _liveWaypointsEndDistance,
                        liveRoadScene: _liveRoadScene,
                      ),
                    ),
                  ),
                ),

                // 2. Ego Vehicle MEVI 3D Model Murni (Menghadap ke Depan / Chase View, Skala 1:1)
                // Memiliki posisi dan Key stabil di dalam Stack agar tidak pernah di-unmount
                _buildEgoVehicle3D(size, effectiveSteering, effectiveSpeed),

                // 3. Floating Badges Melayang di Atas Setiap 3D Bounding Box (Diisolasi ke Layer Sendiri)
                // Isolasi ini mencegah pergeseran child index Stack saat objek bertambah/berkurang
                Positioned.fill(
                  key: const ValueKey('bev-floating-badges-layer'),
                  child: IgnorePointer(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: _buildFloatingBadges(size, isLight, effectiveObjects),
                    ),
                  ),
                ),

                // 4. Panel Tombol Switcher Skenario Jalan / Live Control di Bawah Mobil MEVI
                _buildScenarioControlBar(size, isLight, isLiveConnected),

                // 5. Selector Mode Kamera Drop-up di Pojok Kanan Bawah (Kamera Ikut / Atas / Bebas)
                _buildCameraModeSelector(isLight),
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

    final img = _cachedEgoSnapshot;

    return Positioned(
      key: const ValueKey('bev-ego-car-position'),
      left: egoLeft,
      top: egoTop,
      width: carWidth,
      height: carHeight,
      child: RepaintBoundary(
        key: const ValueKey('bev-ego-car-repaint-boundary'),
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
                  child: img != null
                      ? RawImage(
                          image: img,
                          width: carWidth,
                          height: carHeight,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                        )
                      : Car3DViewerWidget(
                          key: const ValueKey('bev-ego-car-3d-model'),
                          speed: 0,
                          steeringAngle: 0,
                          cameraOrbit: '0deg 50deg 86%',
                          height: carHeight,
                          width: carWidth,
                          captureSnapshot: true,
                          onSnapshot: _onEgoSnapshot,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 4. Panel Kontrol Navigasi Live di Bawah MEVI 3D (Gaya Glassmorphism Dashboard)
  Widget _buildScenarioControlBar(Size size, bool isLight, bool isLiveConnected) {
    return Positioned(
      bottom: 12,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            color: isLight ? Colors.white : const Color(0xFF131B2B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isLight
                  ? const Color(0xFFE2E8F0)
                  : const Color(0xFF1E293B),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isLight
                    ? const Color(0x0A0F172A)
                    : Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tombol LIVE ROS (Metode 1: Waypoint-Corridor)
              _buildLiveRosButton(isLight, isLiveConnected),
              const SizedBox(width: 4),

              // Divider Vertikal
              Container(
                width: 1,
                height: 20,
                color: isLight
                    ? const Color(0xFFE2E8F0)
                    : Colors.white.withValues(alpha: 0.12),
                margin: const EdgeInsets.symmetric(horizontal: 4),
              ),
              const SizedBox(width: 4),

              // Tombol Speaker (Mute / Unmute Suara Navigasi Otonom)
              _buildSpeakerButton(isLight),

              // CATATAN: Tombol-tombol contoh skenario jalan (1 Lurus, 2 Belok Kanan,
              // 3 Belok Kiri, 4 Pertigaan, 5 Berhenti, dan AUTO) sengaja tidak dipanggil
              // di sini sesuai kebutuhan user. Method pembangunnya (_buildScenarioButton
              // & _buildAutoButton) tetap dipertahankan di bawah ini agar sewaktu-waktu
              // jika dibutuhkan tinggal disisipkan kembali ke Row ini.
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveRosButton(bool isLight, bool isLiveConnected) {
    final isSelected = _isLiveMode;
    final Color dotColor = isLiveConnected
        ? const Color(0xFF10B981)
        : const Color(0xFFF59E0B);
    final Color textColor = isLiveConnected
        ? (isLight ? const Color(0xFF15803D) : const Color(0xFF4ADE80))
        : (isLight ? const Color(0xFFB45309) : const Color(0xFFFBBF24));
    final Color bgColor = isLiveConnected
        ? (isLight ? const Color(0xFFF0FDF4) : const Color(0x1A10B981))
        : (isLight ? const Color(0xFFFFFBEB) : const Color(0x1AF59E0B));
    final Color borderColor = isLiveConnected
        ? (isLight
            ? const Color(0xFFBBF7D0)
            : const Color(0xFF10B981).withValues(alpha: 0.4))
        : (isLight
            ? const Color(0xFFFDE68A)
            : const Color(0xFFF59E0B).withValues(alpha: 0.4));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _isLiveMode = true;
            _isAutoCycle = false;
            _lastAnnouncedManeuverKey = null;
            _lastSpokenTime = null;
            _autoCycleTimer?.cancel();
          });
          VoiceNavigationService().announce(
            const NavigationInstruction(
              text: 'Live Autonomous Navigation Active',
              spokenText: 'Live autonomous navigation active',
              distanceText: 'Live',
              icon: LucideIcons.radio,
              bannerColor: Color(0xFF00C853),
            ),
            playVoice: true,
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? bgColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? borderColor : Colors.transparent,
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.6),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'LIVE ROS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? textColor
                      : (isLight ? const Color(0xFF64748B) : Colors.white70),
                  letterSpacing: 0.3,
                ),
              ),
              if (isSelected && isLiveConnected) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isLight
                        ? const Color(0xFFDCFCE7)
                        : const Color(0x2A10B981),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_liveFrameIdx != null ? "#$_liveFrameIdx " : ""}${_liveWaypoints?.length ?? 0}wp${_livePointCount > 0 ? " • ${_livePointCount}pts" : ""} • ${_liveRoadScene != null ? (_roadHoldCount > 0 ? "jalan tahan ${_roadHoldCount}f" : "jalan ada") : "tanpa jalan"}',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: isLight
                          ? const Color(0xFF15803D)
                          : const Color(0xFF4ADE80),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  // ignore: unused_element
  Widget _buildScenarioButton(BevScenarioType scenario, bool isLight) {
    final isSelected = !_isLiveMode && _currentScenario == scenario && !_isAutoCycle;

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

  // ignore: unused_element
  Widget _buildAutoButton(bool isLight) {
    final isSelected = !_isLiveMode && _isAutoCycle;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleAutoCycle,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF00C853)
                : (isLight ? const Color(0xFFF0F4F8) : const Color(0xFF1E2838)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF69F0AE)
                  : Colors.transparent,
              width: 1.4,
            ),
            boxShadow: isSelected
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

    final Color activeColor =
        isMuted ? const Color(0xFFEF4444) : const Color(0xFF2563EB);
    final Color bgColor = isMuted
        ? (isLight ? const Color(0xFFFEF2F2) : const Color(0x1AEF4444))
        : (isLight ? const Color(0xFFEFF6FF) : const Color(0x1A2563EB));
    final Color borderColor = isMuted
        ? (isLight
            ? const Color(0xFFFECACA)
            : const Color(0xFFEF4444).withValues(alpha: 0.4))
        : (isLight
            ? const Color(0xFFBFDBFE)
            : const Color(0xFF2563EB).withValues(alpha: 0.4));
    final Color textColor = isMuted
        ? (isLight ? const Color(0xFFDC2626) : const Color(0xFFF87171))
        : (isLight ? const Color(0xFF2563EB) : const Color(0xFF60A5FA));

    return Tooltip(
      message: isMuted ? 'Unmute Navigation Voice' : 'Mute Navigation Voice',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            VoiceNavigationService().toggleMute();
            setState(() {
              _isVoiceMuted = VoiceNavigationService().isMuted;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor,
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isMuted ? LucideIcons.volumeX : LucideIcons.volume2,
                  size: 14,
                  color: activeColor,
                ),
                const SizedBox(width: 5),
                Text(
                  isMuted ? 'MUTED' : 'VOICE',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 5. Switch Mode Kamera di Pojok Kanan Bawah
  /// Mengganti mode secara instan antara Kamera Ikut (Chase) dan Kamera Bebas (Free Orbit).
  Widget _buildCameraModeSelector(bool isLight) {
    final isFree = _cameraMode == BevCameraMode.free;

    return Positioned(
      bottom: 12,
      right: 18,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              if (_cameraMode == BevCameraMode.chase) {
                _cameraMode = BevCameraMode.free;
                _freeYaw = 0.0;
                _freePitch = 32.0;
                _freeDist = 20.0;
              } else {
                _cameraMode = BevCameraMode.chase;
              }
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isLight ? Colors.white : const Color(0xFF131B2B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isLight
                    ? const Color(0xFFE2E8F0)
                    : const Color(0xFF1E293B),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isLight
                      ? const Color(0x0A0F172A)
                      : Colors.black.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Micro Icon Box
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isLight
                        ? const Color(0xFFEFF6FF)
                        : const Color(0x1A2563EB),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    isFree ? LucideIcons.orbit : LucideIcons.video,
                    size: 14,
                    color: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _cameraMode.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isLight ? const Color(0xFF0F172A) : Colors.white,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(width: 10),
                // Pill switch toggle indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 34,
                  height: 20,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isFree
                        ? const Color(0xFF2563EB)
                        : (isLight
                            ? const Color(0xFFE2E8F0)
                            : const Color(0xFF334155)),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    alignment:
                        isFree ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
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

