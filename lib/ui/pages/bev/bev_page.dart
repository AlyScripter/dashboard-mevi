import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/dimensions.dart';
import '../../../services/ros_service.dart';
import '../../core/panels/status_indicator_panel.dart';
import '../../core/widgets/dashboard/speed_display_widget.dart';
import '../../core/widgets/dashboard/battery_indicator_widget.dart';
import '../../core/widgets/dashboard/gear_selector_widget.dart';
import '../../core/widgets/sensors/perspective_bev_3d_widget.dart';
import '../../core/widgets/sensors/navigation_hud_banner.dart';
import '../navigation/bloc/navigation_cubit.dart';
import '../navigation/bloc/navigation_state.dart';

/// BEV page — 3D Perspective Edition:
///  - Visualisasi BEV 3D Perspective dengan Scenario Control Bar (1: Lurus, 2: Kanan,
///    3: Kiri, 4: Pertigaan, 5: Perempatan, dan AUTO cycle 5 detik).
///  - Menggunakan model 3D MEVI murni yang menghadap ke depan membelakangi layar (chase view).
///  - Waypoint ribbon bercahaya continuous dengan panah chevron bergerak.
///  - Pop-up HUD notifikasi navigasi dan peringatan otonom di bawah speedometer.
///  - Seluruh widget kontrol dashboard (Speedometer, Baterai & Jarak,
///    Perseneling P-R-N-D, Status Lampu/Listrik/Alert) 100% UTUH dan tidak disentuh.
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
    final isLight = Theme.of(context).brightness == Brightness.light;
    final pageBg = isLight ? Colors.white : Colors.black;

    return Container(
      color: pageBg,
      child: Stack(
        children: [
          // 1. Full-bleed 3D Perspective BEV scene (3D Road + Trajectory Ribbon
          // + 3D MEVI Ego Car + 3D Bounding Boxes & Floating Badges + Scenario Buttons).
          Positioned.fill(
            child: BlocBuilder<NavigationCubit, NavigationState>(
              builder: (context, navState) {
                return StreamBuilder<double>(
                  stream: RosService().steeringAngleStream,
                  builder: (context, steerSnap) {
                    final steeringAngle = steerSnap.data ?? 0.0;
                    return StreamBuilder<double>(
                      stream: RosService().speedometerRosStream,
                      builder: (context, speedSnap) {
                        final speed = speedSnap.data ?? 20.0;
                        return PerspectiveBev3DWidget(
                          steeringAngle: steeringAngle,
                          speed: speed,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          // 2. Speedometer & Navigation HUD Banner — top-center, no surrounding box.
          Positioned(
            top: AppDimensions.spacingL,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SpeedDisplayWidget(),
                  SizedBox(height: 8),
                  NavigationHudBanner(),
                ],
              ),
            ),
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
