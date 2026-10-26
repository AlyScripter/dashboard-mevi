import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/dimensions.dart';
import '../../../services/ros_service.dart';
import '../../../services/voice_navigation_service.dart';
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
  String _gear = 'P';

  @override
  void dispose() {
    VoiceNavigationService().stop();
    VoiceNavigationService().clearInstruction();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final pageBg = isLight ? const Color(0xFFF8FAFC) : Colors.black;

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

          // 3. Battery + range card — top-left modern cockpit card.
          // Nilai statis sesuai spesifikasi dan sisa daya mobil saat perekaman rosbag:
          // Baterai 85%, estimasi jarak tempuh 51 km (48V × 100Ah = 4.800 Wh; 85% = 4.080 Wh / 80 Wh/km = 51 km).
          Positioned(
            top: AppDimensions.spacingL,
            left: AppDimensions.spacingL,
            child: const SizedBox(
              width: 320,
              child: BatteryIndicatorWidget(
                batteryPercent: 0.85,
                distanceKm: 51.0,
                asCard: true,
              ),
            ),
          ),

          // 4. Gear selector card rail (P R N D) — vertical rail on the LEFT edge,
          // styled as compact modern squircle cards.
          Positioned(
            top: 0,
            bottom: 0,
            left: AppDimensions.spacingL,
            child: Center(
              child: GearSelectorWidget(
                selectedGear: _gear,
                onGearChanged: (gear) => setState(() => _gear = gear),
                useCard: true,
                cardSize: 42,
                cardBorderRadius: 11,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
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
