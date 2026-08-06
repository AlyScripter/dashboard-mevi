// lib/ui/shared/glass_container.dart
//
// Reusable glassmorphism container.
// Pakai ini untuk mengganti Container putih solid / _overlayBoxDecoration
// di seluruh dashboard supaya konsisten "kaca" nya.

import 'dart:ui';
import 'package:flutter/material.dart';

enum GlassVariant { light, dark }

class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final GlassVariant variant;

  /// Opacity dasar kaca. 0.35–0.55 biasanya paling enak dilihat.
  final double opacity;

  final Border? border;
  final List<BoxShadow>? boxShadow;
  final double? width;
  final double? height;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 24,
    this.blur = 24,
    this.variant = GlassVariant.light,
    this.opacity = 0.45,
    this.border,
    this.boxShadow,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = variant == GlassVariant.dark;

    // Base tint kaca: putih untuk panel di atas map/kamera gelap,
    // gelap untuk panel di atas background terang.
    final baseColor = isDark ? const Color(0xFF0B0F14) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.6);
    final highlightColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.85);

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ?? Border.all(color: borderColor, width: 1.2),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  baseColor.withValues(alpha: opacity),
                  baseColor.withValues(alpha: (opacity - 0.15).clamp(0.05, 1.0)),
                ],
              ),
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [highlightColor.withValues(alpha: isDark ? 0.05 : 0.25), Colors.transparent],
                stops: const [0.0, 0.4],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Tombol bulat kaca — pengganti Container abu-abu di tombol Settings /
/// Collapse / Cancel supaya seragam dengan tema glass.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final GlassVariant variant;
  final Color? iconColor;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 44,
    this.variant = GlassVariant.light,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: GlassContainer(
          width: size,
          height: size,
          borderRadius: size / 2,
          variant: variant,
          blur: 16,
          opacity: 0.5,
          child: Icon(
            icon,
            size: size * 0.45,
            color: iconColor ??
                (variant == GlassVariant.dark ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }
}