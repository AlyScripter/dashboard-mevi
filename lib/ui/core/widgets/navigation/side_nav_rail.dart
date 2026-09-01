import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';

/// Single icon entry rendered by [SideNavRail].
class SideNavItem {
  final String id;
  final IconData icon;
  final String label;

  const SideNavItem({
    required this.id,
    required this.icon,
    required this.label,
  });
}

/// Slim vertical icon rail docked on the far left of the dashboard.
///
/// Replaces the old floating bottom navbar (map/camera/data icons) and
/// the separate settings gear that used to live inside the BEV panel —
/// every navigation entry (Maps, Camera, Data, Settings, BEV) now lives
/// here instead. Styled after the reference EV head-unit sidebar: a
/// flat dark column, the active item gets a blue gradient "pill" behind
/// its icon plus a thin blue accent bar on the rail's left edge.
class SideNavRail extends StatelessWidget {
  final List<SideNavItem> items;
  final String activeId;
  final ValueChanged<String> onSelect;
  final double width;

  const SideNavRail({
    super.key,
    required this.items,
    required this.activeId,
    required this.onSelect,
    this.width = 84,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: const BoxDecoration(
        // Same flat black-navy gradient already used elsewhere on the
        // dashboard (left panel / collapsed panel) so the new rail
        // reads as part of the same cockpit shell rather than a
        // bolted-on strip.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF12161F), Color(0xFF0A0D13)],
        ),
        border: Border(right: BorderSide(color: Color(0xFF1E2430), width: 1.0)),
      ),
      child: SafeArea(
        // REVISI: sebelumnya item numpuk di tengah dengan gap tetap
        // (22px) — sekarang di-spread rata dari atas sampai bawah rail
        // (spaceEvenly) dengan sedikit padding vertikal, supaya rail
        // terasa "terisi" penuh dari atas ke bawah, bukan cuma nongkrong
        // di tengah.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final item in items)
                _RailButton(
                  item: item,
                  isActive: item.id == activeId,
                  onTap: () => onSelect(item.id),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  final SideNavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _RailButton({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Thin blue accent bar on the rail edge — only visible for the
        // active item, mirroring the small selection indicator next to
        // the highlighted icon in the reference sidebar.
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 3,
          height: isActive ? 26 : 0,
          decoration: BoxDecoration(
            color: AppColors.glassBlueBorder,
            borderRadius: BorderRadius.circular(4),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.glassBlueGlow.withValues(alpha: 0.7),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: item.label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  // Active pill uses the app's blue accent as a gradient
                  // (same family as AppColors.primary/glassBlueBorder),
                  // matching the highlighted-tab look from the reference.
                  gradient: isActive
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2BB0FF), Color(0xFF1565C0)],
                        )
                      : null,
                  color: isActive ? null : Colors.white.withValues(alpha: 0.05),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppColors.glassBlueGlow.withValues(
                              alpha: 0.35,
                            ),
                            blurRadius: 16,
                            spreadRadius: -2,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  item.icon,
                  size: 22,
                  color: isActive ? Colors.white : Colors.white38,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
