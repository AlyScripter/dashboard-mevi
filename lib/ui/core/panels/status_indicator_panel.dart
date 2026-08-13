import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/glass_container.dart';

/// Row of 3 status toggle icons (lamp / power / hazard), styled after the
/// reference dashboard's circular glass icon buttons: solid blue glass
/// (+ soft blue glow) when active, dark/white glass when off — instead of
/// the old per-icon amber/green/red color scheme.
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
  static const _activeBlue = Color(0xFF2196F3);

  Widget _buildStatusIcon({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: _activeBlue.withValues(alpha: 0.45),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: GlassChip(
          borderRadius: 100,
          padding: const EdgeInsets.all(9),
          tint: active ? _activeBlue : Colors.black,
          tintOpacity: active ? 0.38 : 0.30,
          child: Icon(
            icon,
            size: 18,
            color: Colors.white.withValues(alpha: active ? 1.0 : 0.85),
          ),
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
          onTap: () => widget.onLampToggle(!widget.indicatorLampOn),
        ),
        _buildStatusIcon(
          icon: LucideIcons.zap,
          active: widget.engineOn,
          onTap: () => widget.onEngineToggle(!widget.engineOn),
        ),
        _buildStatusIcon(
          icon: LucideIcons.triangleAlert,
          active: widget.hazardOn,
          onTap: () => widget.onHazardToggle(!widget.hazardOn),
        ),
      ],
    );
  }
}
