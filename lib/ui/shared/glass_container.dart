import 'dart:ui';
import 'package:flutter/material.dart';

/// Reusable frosted-glass container used across the dashboard.
///
/// Wraps [child] with a blurred, translucent background, a thin light
/// border, and a soft shadow. Works well over the map (which is always
/// colorful) or over a dark background — pass [tint] to bias it toward
/// white (light glass) or black (dark glass).
///
/// Usage:
/// ```dart
/// GlassContainer(
///   borderRadius: 20,
///   padding: const EdgeInsets.all(16),
///   child: MyContent(),
/// )
/// ```
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double blurSigma;
  final Color tint;

  /// Opacity of [tint] used as the glass fill. Lower = more see-through.
  final double tintOpacity;

  /// Opacity of the white border stroke.
  final double borderOpacity;

  final List<BoxShadow>? boxShadow;
  final double? width;
  final double? height;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.blurSigma = 18,
    this.tint = Colors.white,
    this.tintOpacity = 0.55,
    this.borderOpacity = 0.6,
    this.boxShadow,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow:
            boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              // Flat tint only — no diagonal gradient overlay. The
              // gradient used previously created a visible seam/crease
              // on wide bars (destination bar, nav icon strip), which
              // read as a rendering glitch rather than glass.
              color: tint.withValues(alpha: tintOpacity),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: borderOpacity),
                width: 1.0,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A smaller, borderless glass "chip" — for compact icon buttons, pills,
/// and status dots that need a frosted look without a full card border.
class GlassChip extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color tint;
  final double tintOpacity;
  final VoidCallback? onTap;

  const GlassChip({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(10),
    this.borderRadius = 14,
    this.tint = Colors.white,
    this.tintOpacity = 0.5,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: tintOpacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 0.8,
            ),
          ),
          child: child,
        ),
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      ),
    );
  }
}
