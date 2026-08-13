import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/dimensions.dart';
import '../../../core/theme/glass_container.dart';
import '../../../services/ros_service.dart'; // Import RosService
import 'status_indicator_panel.dart';
import '../widgets/dashboard/speed_display_widget.dart';
import '../widgets/dashboard/battery_indicator_widget.dart';
import '../widgets/dashboard/gear_selector_widget.dart';
import '../widgets/dashboard/distance_cards_widget.dart';
import '../widgets/sensors/vehicle_stage_widget.dart';

class LeftPanel extends StatefulWidget {
  final VoidCallback? onSettingsPressed;
  final VoidCallback? onTogglePanel;
  final bool isExpanded;

  const LeftPanel({
    super.key,
    this.onSettingsPressed,
    this.onTogglePanel,
    this.isExpanded = true,
  });

  @override
  State<LeftPanel> createState() => _LeftPanelState();
}

class _LeftPanelState extends State<LeftPanel> {
  // Panel state
  bool _indicatorLampOn = true;
  bool _engineOn = true;
  bool _hazardOn = false;
  double _batteryPercent = 0.6;
  String _gear = 'P';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        // Dark gradient panel to match the reference dashboard's dark
        // cluster theme (was a plain white sidebar before).
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF12161F), Color(0xFF0A0D13)],
        ),
        border: Border(right: BorderSide(color: Color(0xFF1E2430), width: 1.0)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Battery + efficiency — moved to the very top of the panel and
          // restyled as a blue glass card, matching the reference
          // dashboard's "Battery 72% / Fuel 83%" header.
          BatteryIndicatorWidget(
            batteryPercent: _batteryPercent,
            onTap: () {
              setState(() {
                _batteryPercent = _batteryPercent > 0.95
                    ? 0.35
                    : (_batteryPercent + 0.1).clamp(0.0, 1.0);
              });
            },
          ),

          SizedBox(height: AppDimensions.spacingM),

          // Distance / range cards — also moved up here (also blue glass)
          // so both top-level stats sit together above the fold, like the
          // reference.
          DistanceCardsWidget(batteryPercent: _batteryPercent),

          SizedBox(height: AppDimensions.spacingXL),

          // Status indicators
          StatusIndicatorPanel(
            indicatorLampOn: _indicatorLampOn,
            engineOn: _engineOn,
            hazardOn: _hazardOn,
            onLampToggle: (value) => setState(() => _indicatorLampOn = value),
            onEngineToggle: (value) => setState(() => _engineOn = value),
            onHazardToggle: (value) => setState(() => _hazardOn = value),
          ),

          SizedBox(height: AppDimensions.spacingXL),

          // Speed display
          const SpeedDisplayWidget(),

          SizedBox(height: AppDimensions.spacingM),

          // Vehicle stage: road/LIDAR visualization (FrontBevWidget, kept
          // exactly as before) + 3D car model, painted directly over the
          // panel's own dark gradient background — no card/box around it,
          // so the road visually merges into the dashboard rather than
          // reading as a separate boxed widget.
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableHeight = constraints.maxHeight;
                  final availableWidth = constraints.maxWidth;
                  // ---------------------------------------------------
                  // 3D MODEL SIZE KNOB — tune these 3 numbers to make
                  // the car bigger/smaller:
                  //   - 0.34  : fraction of the available stage height
                  //             used as the base "carSize" (was 0.52 —
                  //             lower = smaller model).
                  //   - 110/200 : min/max clamp on that base size in
                  //             logical pixels (was 160/280).
                  // carSize is the base unit the whole stage scales
                  // from — the on-screen car box itself ends up
                  // ~1.45x this value (see the `carSize * 1.45` in
                  // VehicleStageWidget, `lib/ui/core/widgets/sensors/
                  // vehicle_stage_widget.dart` — shrink that 1.45
                  // multiplier too if you want the model smaller
                  // relative to its glow/beam effect specifically,
                  // rather than everything together).
                  // ---------------------------------------------------
                  final carSize = (availableHeight * 0.34)
                      .clamp(110.0, 200.0)
                      .clamp(0.0, availableWidth / 1.45);

                  return StreamBuilder<double>(
                    stream: RosService().steeringAngleStream,
                    builder: (context, steerSnap) {
                      final steeringAngle = steerSnap.data ?? 0.0;

                      return StreamBuilder<double>(
                        stream: RosService().speedometerRosStream,
                        builder: (context, speedSnap) {
                          final speed = speedSnap.data ?? 0.0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: VehicleStageWidget(
                              speed: speed,
                              steeringAngle: steeringAngle,
                              carSize: carSize,
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),

          SizedBox(height: AppDimensions.spacingM),

          // Bottom row: Settings (icon only, bottom-left) — Gear selector
          // (P/R/N/D, moved here from under the gauge, smaller + thinner
          // font) centered — Collapse (icon only, bottom-right).
          Row(
            children: [
              _buildIconButton(
                icon: LucideIcons.settings,
                onTap: widget.onSettingsPressed,
              ),
              Expanded(
                child: Center(
                  child: GearSelectorWidget(
                    selectedGear: _gear,
                    onGearChanged: (gear) => setState(() => _gear = gear),
                    circleSize: 30,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              _buildIconButton(
                icon: LucideIcons.panelLeftClose,
                onTap: widget.onTogglePanel,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Shared icon-only glass button for the bottom row (Settings /
  /// Collapse) — dark ("putih/hitam glass") by default. Pass
  /// `active: true` for a blue glass variant if a button ever needs to
  /// show an on/selected state.
  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback? onTap,
    bool active = false,
  }) {
    const blue = Color(0xFF2196F3);
    return GlassChip(
      onTap: onTap,
      borderRadius: 12,
      padding: const EdgeInsets.all(10),
      tint: active ? blue : Colors.black,
      tintOpacity: active ? 0.38 : 0.30,
      child: Icon(
        icon,
        size: 18,
        color: Colors.white.withValues(alpha: active ? 1.0 : 0.85),
      ),
    );
  }
}
