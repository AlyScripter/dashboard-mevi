import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_controller.dart';

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
/// Berisi item navigasi reguler (Maps, Camera, Data, BEV, Settings) plus
/// satu tombol khusus di bagian bawah untuk toggle Light/Dark mode.
/// Default mode = Light (biru + putih); saat Dark aktif rail tetap gelap
/// dengan aksen biru yang sama.
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
    // ValueListenableBuilder memastikan rail rebuild setiap kali theme berubah,
    // sehingga warna rail ikut menyesuaikan mode terang/gelap.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, themeMode, _) {
        final isDark = themeMode == ThemeMode.dark;

        // Warna rail: gelap (hitam-navy) saat dark mode,
        // biru tua + putih saat light mode.
        final railTopColor = isDark
            ? const Color(0xFF12161F)
            : const Color(0xFF1565C0);
        final railBottomColor = isDark
            ? const Color(0xFF0A0D13)
            : const Color(0xFF1976D2);
        final railBorderColor = isDark
            ? const Color(0xFF1E2430)
            : const Color(0xFF1E88E5);

        return Container(
          width: width,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [railTopColor, railBottomColor],
            ),
            border: Border(
              right: BorderSide(color: railBorderColor, width: 1.0),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Item navigasi reguler
                  for (final item in items)
                    _RailButton(
                      item: item,
                      isActive: item.id == activeId,
                      isDarkRail: isDark,
                      onTap: () => onSelect(item.id),
                    ),

                  // Divider tipis sebelum tombol theme toggle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.3),
                      thickness: 1,
                    ),
                  ),

                  // Tombol toggle tema (Light ↔ Dark)
                  _ThemeToggleButton(isDark: isDark),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Tombol toggle tema di bagian bawah rail.
/// Ikon berubah: sun (terang → gelap) | moon (gelap → terang).
class _ThemeToggleButton extends StatelessWidget {
  final bool isDark;

  const _ThemeToggleButton({required this.isDark});

  void _toggle() {
    appThemeMode.value = isDark ? ThemeMode.light : ThemeMode.dark;
  }

  @override
  Widget build(BuildContext context) {
    final icon = isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded;
    final label = isDark ? 'Mode Terang' : 'Mode Gelap';

    // Warna aksen tombol disesuaikan dengan state saat ini:
    // - di dark rail: ikon oranye-kuning (sun) dengan glow hangat
    // - di light rail: ikon putih (moon) dengan glow biru muda
    final iconColor = isDark ? const Color(0xFFFFC107) : Colors.white;
    final glowColor = isDark
        ? const Color(0xFFFFC107)
        : AppColors.glassBlueGlow;
    final bgColor = isDark
        ? const Color(0xFFFFC107).withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.15);

    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: bgColor,
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.25),
                  blurRadius: 12,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) =>
                  RotationTransition(turns: anim, child: child),
              child: Icon(
                icon,
                key: ValueKey(isDark),
                size: 22,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  final SideNavItem item;
  final bool isActive;
  final bool isDarkRail;
  final VoidCallback onTap;

  const _RailButton({
    required this.item,
    required this.isActive,
    required this.isDarkRail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Di light rail, ikon inaktif memakai putih agak transparan (senada
    // dengan background biru tua rail), aktif pakai pill putih + ikon biru.
    // Di dark rail, perilaku sama seperti sebelumnya (pill biru, ikon putih).
    final inactiveIconColor = isDarkRail
        ? Colors.white38
        : Colors.white.withValues(alpha: 0.7);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Thin accent bar on rail edge — visible only for active item.
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 3,
          height: isActive ? 26 : 0,
          decoration: BoxDecoration(
            color: isDarkRail ? AppColors.glassBlueBorder : Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: isDarkRail
                          ? AppColors.glassBlueGlow.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.5),
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
                  gradient: isActive
                      ? (isDarkRail
                            // Dark rail: pill biru seperti semula
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF2BB0FF), Color(0xFF1565C0)],
                              )
                            // Light rail: pill putih semi-transparan
                            : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.95),
                                  Colors.white.withValues(alpha: 0.75),
                                ],
                              ))
                      : null,
                  color: isActive ? null : Colors.white.withValues(alpha: 0.05),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: isDarkRail
                                ? AppColors.glassBlueGlow.withValues(
                                    alpha: 0.35,
                                  )
                                : Colors.black.withValues(alpha: 0.15),
                            blurRadius: 16,
                            spreadRadius: -2,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  item.icon,
                  size: 22,
                  // Aktif di light rail: ikon biru (kontras dengan pill putih)
                  // Aktif di dark rail: ikon putih (kontras dengan pill biru)
                  // Inaktif: transparan sesuai masing-masing mode
                  color: isActive
                      ? (isDarkRail ? Colors.white : const Color(0xFF1565C0))
                      : inactiveIconColor,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
