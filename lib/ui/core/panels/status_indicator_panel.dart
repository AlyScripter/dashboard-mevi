import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/dimensions.dart';

class StatusIndicatorPanel extends StatefulWidget {
  final bool indicatorLampOn;
  final bool engineOn;
  final bool hazardOn;
  final Function(bool) onLampToggle;
  final Function(bool) onEngineToggle;
  final Function(bool) onHazardToggle;

  const StatusIndicatorPanel({
    super.key,
    required this.indicatorLampOn,
    required this.engineOn,
    required this.hazardOn,
    required this.onLampToggle,
    required this.onEngineToggle,
    required this.onHazardToggle,
  });

  @override
  State<StatusIndicatorPanel> createState() => _StatusIndicatorPanelState();
}

class _StatusIndicatorPanelState extends State<StatusIndicatorPanel> {
  Widget _buildStatusIcon({
    required IconData icon,
    required bool active,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(AppDimensions.paddingS),
        decoration: BoxDecoration(
          color: active
              ? activeColor.withValues(alpha: 0.15)
              : Colors.grey.shade300,
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? activeColor : Colors.grey.shade500,
            width: 1.2,
          ),
        ),
        child: Icon(
          icon,
          size: AppDimensions.iconL,
          color: active ? activeColor : Colors.grey.shade600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatusIcon(
          icon: LucideIcons.lightbulb,
          active: widget.indicatorLampOn,
          activeColor: Colors.amber,
          onTap: () => widget.onLampToggle(!widget.indicatorLampOn),
        ),
        _buildStatusIcon(
          icon: LucideIcons.zap,
          active: widget.engineOn,
          activeColor: Colors.green,
          onTap: () => widget.onEngineToggle(!widget.engineOn),
        ),
        _buildStatusIcon(
          icon: LucideIcons.triangleAlert,
          active: widget.hazardOn,
          activeColor: Colors.red,
          onTap: () => widget.onHazardToggle(!widget.hazardOn),
        ),
      ],
    );
  }
}
