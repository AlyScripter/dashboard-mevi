import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/dimensions.dart';
import '../widgets/sensors/lidar_2d_radar_widget.dart';
import 'status_indicator_panel.dart';
import '../widgets/dashboard/speed_display_widget.dart';
import '../widgets/dashboard/battery_indicator_widget.dart';
import '../widgets/dashboard/gear_selector_widget.dart';
import '../widgets/dashboard/distance_cards_widget.dart';

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
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey.shade200, width: 1.0),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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

          SizedBox(height: AppDimensions.spacingXL),

          // Car and radar visualization
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableHeight = constraints.maxHeight;

                  // Calculate proportional car size (65% of available space untuk lebih besar)
                  final carSize = (availableHeight * 0.65).clamp(280.0, 500.0);

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // LiDAR 2D Radar (80° FOV, 7 segments) - positioned at top
                      const Positioned(top: -100, child: Lidar2DRadarWidget()),
                      // Car image - centered both horizontally and vertically
                      Center(
                        child: Image.asset(
                          'assets/images/mevicar.png',
                          width: carSize,
                          height: carSize,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              SizedBox(
                            width: carSize,
                            height: carSize,
                            child: Center(
                              child: Icon(
                                Icons.directions_car,
                                size: carSize * 1.2,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // Battery and gear controls
          SizedBox(height: AppDimensions.spacingM),
          Center(
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

          SizedBox(height: AppDimensions.spacingS),

          GearSelectorWidget(
            selectedGear: _gear,
            onGearChanged: (gear) => setState(() => _gear = gear),
          ),

          SizedBox(height: AppDimensions.spacingM),

          // Distance cards
          DistanceCardsWidget(batteryPercent: _batteryPercent),

          SizedBox(height: AppDimensions.spacingM),

          // Bottom row: Settings & Collapse buttons
          Row(
            children: [
              // Settings button
              Expanded(child: _buildSettingsButton()),
              const SizedBox(width: 8),
              // Collapse button
              _buildCollapseButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCollapseButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTogglePanel,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            LucideIcons.panelLeftClose,
            size: 16,
            color: Colors.grey.shade500,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onSettingsPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.settings, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 8),
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
