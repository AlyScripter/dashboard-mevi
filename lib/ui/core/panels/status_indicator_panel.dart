import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:dashboardmevi/core/theme/colors.dart';

/// Row/column of 3 status toggle tiles (lamp / power / hazard).
///
/// REVISI: Mengadopsi visual style & hierarki cockpit EV modern:
/// - Light mode: White cards saat inaktif dengan border halus (0xFFE2E8F0) dan soft shadow.
/// - Dark mode: Dark navy cards saat inaktif.
/// - Active Lampu & Listrik: Tech-blue gradient dengan soft glow.
/// - Active Alert (Hazard): Warm warning red gradient dengan soft glow.
/// - Interaktif & theme-aware di light maupun dark mode.
class StatusIndicatorPanel extends StatefulWidget {
  final bool indicatorLampOn;
  final bool engineOn;
  final bool hazardOn;
  final Function(bool) onLampToggle;
  final Function(bool) onEngineToggle;
  final Function(bool) onHazardToggle;

  /// Layout direction for the 3 tiles. Defaults to [Axis.horizontal]
  /// (a row). Pass [Axis.vertical] to stack them top-to-bottom.
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
  static const _blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
  );

  static const _alertGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
  );

  Widget _buildStatusTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool active,
    required bool isAlert,
    required VoidCallback onTap,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    final cardBg = isLight ? Colors.white : AppColors.glassNavyTint;
    final cardBorder = isLight
        ? const Color(0xFFE2E8F0)
        : AppColors.glassBlueBorder.withValues(alpha: 0.65);
    final cardShadow = isLight
        ? const Color(0x0A0F172A)
        : Colors.black.withValues(alpha: 0.35);

    final textClr = active
        ? Colors.white
        : (isLight ? const Color(0xFF64748B) : AppColors.glassTextSecondary);

    final LinearGradient? gradient = active
        ? (isAlert ? _alertGradient : _blueGradient)
        : null;

    final List<BoxShadow> shadows = active
        ? [
            BoxShadow(
              color: (isAlert ? const Color(0xFFEF4444) : const Color(0xFF2563EB))
                  .withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ]
        : [
            BoxShadow(
              color: cardShadow,
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: 62,
          height: 62,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: gradient,
            color: active ? null : cardBg,
            border: active ? null : Border.all(color: cardBorder, width: 1.0),
            boxShadow: shadows,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: textClr),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: textClr,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _buildStatusTile(
        context: context,
        icon: LucideIcons.lightbulb,
        label: 'Lampu',
        active: widget.indicatorLampOn,
        isAlert: false,
        onTap: () => widget.onLampToggle(!widget.indicatorLampOn),
      ),
      _buildStatusTile(
        context: context,
        icon: LucideIcons.zap,
        label: 'Listrik',
        active: widget.engineOn,
        isAlert: false,
        onTap: () => widget.onEngineToggle(!widget.engineOn),
      ),
      _buildStatusTile(
        context: context,
        icon: LucideIcons.triangleAlert,
        label: 'Alert',
        active: widget.hazardOn,
        isAlert: true,
        onTap: () => widget.onHazardToggle(!widget.hazardOn),
      ),
    ];

    if (widget.direction == Axis.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            tiles[i],
          ],
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          tiles[i],
        ],
      ],
    );
  }
}
