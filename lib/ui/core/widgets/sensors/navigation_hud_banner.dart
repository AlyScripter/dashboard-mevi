import 'package:flutter/material.dart';
import '../../../../services/voice_navigation_service.dart';

/// HUD Banner Pemandu Navigasi Otonom (Google Maps style)
/// Ditampilkan tepat di bawah speedometer untuk memberi panduan visual instruksi manuver & jarak.
class NavigationHudBanner extends StatelessWidget {
  const NavigationHudBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return StreamBuilder<NavigationInstruction?>(
      stream: VoiceNavigationService().instructionStream,
      builder: (context, snapshot) {
        final instruction = snapshot.data;
        if (instruction == null) return const SizedBox.shrink();

        final color = instruction.isWarning
            ? const Color(0xFFFF3D00)
            : instruction.bannerColor;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(scale: anim, child: child),
          ),
          child: Container(
            key: ValueKey(instruction.text),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isLight
                  ? Colors.white.withValues(alpha: 0.95)
                  : const Color(0xFF101926).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: color.withValues(alpha: 0.85),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: isLight ? 0.30 : 0.45),
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon Bulat Berpendar
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(instruction.icon, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 10),

                // Teks Instruksi Navigasi
                Text(
                  instruction.text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isLight ? const Color(0xFF1A2331) : Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),

                if (instruction.distanceText.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      instruction.distanceText,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
