import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Row/column of 3 status toggle tiles (lamp / power / hazard).
///
/// REVISI: previously these were plain circular glass icon buttons with
/// no label, so it wasn't obvious what each one meant at a glance. Now
/// styled after the reference "CONTROL" panel (rounded-square tile,
/// icon + short label stacked inside): a bright blue gradient tile when
/// ON, a flat dark slate tile when OFF — same idea as the reference's
/// lit vs. unlit tiles, just applied to lamp/electric/hazard instead of
/// brightness/volume/lock.
class StatusIndicatorPanel extends StatefulWidget {
  final bool indicatorLampOn;
  final bool engineOn;
  final bool hazardOn;
  final Function(bool) onLampToggle;
  final Function(bool) onEngineToggle;
  final Function(bool) onHazardToggle;

  /// Layout direction for the 3 tiles. Defaults to [Axis.horizontal]
  /// (a row). Pass [Axis.vertical] to stack them top-to-bottom instead
  /// — used by the BEV page's right-side rail so the tiles read as a
  /// descending column.
  final Axis direction;

  const StatusIndicatorPanel({
    super.key,
    required this.indicatorLampOn,
    required this.engineOn,
    required this.hazardOn,
    required this.onLampToggle,
    required this.onEngineToggle,
    required this.onHazardToggle,
    this.direction = Axis.horizontal,
  });

  @override
  State<StatusIndicatorPanel> createState() => _StatusIndicatorPanelState();
}

class _StatusIndicatorPanelState extends State<StatusIndicatorPanel> {
  // Active tile: bright diagonal blue gradient, matching the reference
  // panel's lit tiles (Brightness/Volume/Lock/Trunk).
  static const _activeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4FC3F7), Color(0xFF1565C0)],
  );
  // Inactive tile: flat dark slate, matching the reference panel's
  // unlit tiles (Economy/Nap/Off/Custom).
  static const _inactiveFill = Color(0xFF1A212C);

  Widget _buildStatusTile({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 68,
        height: 68,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: active ? _activeGradient : null,
          color: active ? null : _inactiveFill,
          border: active
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.45),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: Colors.white.withValues(alpha: active ? 1.0 : 0.65),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: Colors.white.withValues(alpha: active ? 1.0 : 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _buildStatusTile(
        icon: LucideIcons.lightbulb,
        label: 'Lampu',
        active: widget.indicatorLampOn,
        onTap: () => widget.onLampToggle(!widget.indicatorLampOn),
      ),
      _buildStatusTile(
        icon: LucideIcons.zap,
        label: 'Listrik',
        active: widget.engineOn,
        onTap: () => widget.onEngineToggle(!widget.engineOn),
      ),
      _buildStatusTile(
        icon: LucideIcons.triangleAlert,
        label: 'Alert',
        active: widget.hazardOn,
        onTap: () => widget.onHazardToggle(!widget.hazardOn),
      ),
    ];

    if (widget.direction == Axis.vertical) {
      // mainAxisSize.min + explicit gaps (instead of spaceEvenly, which
      // needs a bounded height from the parent) so this can sit inside
      // a shrink-wrapped rail on the BEV page without needing an extra
      // fixed-height SizedBox at the call site.
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            tiles[i],
          ],
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          tiles[i],
        ],
      ],
    );
  }
}
