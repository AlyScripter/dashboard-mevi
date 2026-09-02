import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/dimensions.dart';
import '../../../services/ros_service.dart';
import '../../core/panels/status_indicator_panel.dart';
import '../../core/widgets/dashboard/speed_display_widget.dart';
import '../../core/widgets/dashboard/battery_indicator_widget.dart';
import '../../core/widgets/dashboard/gear_selector_widget.dart';
import '../../core/widgets/sensors/topdown_bev_widget.dart';
import '../navigation/bloc/navigation_cubit.dart';
import '../navigation/bloc/navigation_state.dart';

/// BEV page — REVISI #4:
///  - The 3D car model + glow-road + raw per-point LIDAR rendering
///    (`VehicleStageWidget` / `FrontBevWidget`) is REMOVED from this
///    page — it was too heavy to paint every frame. Replaced with
///    [TopDownBevWidget]: a flat, lightweight 2D bird's-eye scene
///    (single-lane boundary lines + a blue detection ring hugging MEVI
///    + MEVI as `assets/images/mevicar.png`), styled after the
///    reference 360° sensor illustration. Nearby traffic (currently
///    disabled) uses `assets/images/car.png`. `VehicleStageWidget`
///    itself is left untouched in the codebase in case it's needed
///    again — this page just no longer references it.
///  - REVISI #5: the road now follows the real Maps route — this page
///    reads the shared `NavigationCubit` (promoted to an app-wide
///    ancestor in `LayoutDashboard`, same instance the Maps page
///    itself uses) for `routePoints` + `current` position, and the
///    same IMU-yaw-with-fallback heading source already used by the
///    Maps page's heading HUD / car marker. A left turn on the map now
///    draws as a left turn here too, matching Maps 1:1. With no active
///    route yet, [TopDownBevWidget] falls back to its static straight
///    single-lane road on its own — no extra handling needed here.
///  - Everything else (speedometer top-center, battery top-left, gear
///    rail left / status rail right, no boxes, vertically centered
///    side rails) is unchanged from the previous revision.
///
/// All ROS stream wiring below is copied as-is from the old LeftPanel —
/// intentionally untouched, per existing project convention.
class BevPage extends StatefulWidget {
  const BevPage({super.key});

  @override
  State<BevPage> createState() => _BevPageState();
}

class _BevPageState extends State<BevPage> {
  bool _indicatorLampOn = true;
  bool _engineOn = true;
  bool _hazardOn = false;
  double _batteryPercent = 0.6;
  String _gear = 'P';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // 1. Full-bleed 2D top-down BEV scene (lanes + detection ring
          // + MEVI/nearby-traffic sprites) — fills the whole page.
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                top: 100,
                bottom: AppDimensions.spacingXL,
              ),
              child: BlocBuilder<NavigationCubit, NavigationState>(
                builder: (context, navState) {
                  return StreamBuilder<double>(
                    stream: RosService().steeringAngleStream,
                    builder: (context, steerSnap) {
                      final steeringAngle = steerSnap.data ?? 0.0;
                      return StreamBuilder<Map<String, double>>(
                        stream: RosService().imuStream,
                        builder: (context, imuSnap) {
                          // Same heading source as the Maps page's
                          // heading HUD / car marker: IMU yaw when
                          // available, else the cubit's fallback.
                          final imu = imuSnap.data;
                          final heading = (imu != null && imu['yaw'] != null)
                              ? imu['yaw']!
                              : navState.fallbackHeadingDeg;
                          return TopDownBevWidget(
                            steeringAngle: steeringAngle,
                            routePoints: navState.routePoints,
                            currentPosition: navState.current,
                            headingDeg: heading,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // 2. Speedometer — top-center, no surrounding box. The arc
          // gauge already paints its own glow, so it reads fine sitting
          // directly on the black background.
          Positioned(
            top: AppDimensions.spacingL,
            left: 0,
            right: 0,
            child: const Center(child: SpeedDisplayWidget()),
          ),

          // 3. Battery + range — top-left, no surrounding box.
          Positioned(
            top: AppDimensions.spacingL,
            left: AppDimensions.spacingL,
            child: SizedBox(
              width: 268,
              child: BatteryIndicatorWidget(
                batteryPercent: _batteryPercent,
                onTap: () {
                  setState(() {
                    _batteryPercent = _batteryPercent > 0.95
                        ? 0.35
                        : (_batteryPercent + 0.1).clamp(0.0, 1.0);
                  });
                },
              ),
            ),
          ),

          // 4. Gear selector (P R N D) — vertical rail on the LEFT edge,
          // no surrounding box, vertically CENTERED on the page.
          Positioned(
            top: 0,
            bottom: 0,
            left: AppDimensions.spacingL,
            child: Center(
              child: GearSelectorWidget(
                selectedGear: _gear,
                onGearChanged: (gear) => setState(() => _gear = gear),
                circleSize: 34,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                direction: Axis.vertical,
              ),
            ),
          ),

          // 5. Status tiles (lamp / electric / hazard) — vertical rail
          // on the RIGHT edge, no surrounding box, vertically CENTERED
          // on the page.
          Positioned(
            top: 0,
            bottom: 0,
            right: AppDimensions.spacingL,
            child: Center(
              child: StatusIndicatorPanel(
                indicatorLampOn: _indicatorLampOn,
                engineOn: _engineOn,
                hazardOn: _hazardOn,
                onLampToggle: (value) =>
                    setState(() => _indicatorLampOn = value),
                onEngineToggle: (value) => setState(() => _engineOn = value),
                onHazardToggle: (value) => setState(() => _hazardOn = value),
                direction: Axis.vertical,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
