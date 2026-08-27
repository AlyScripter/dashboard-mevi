import 'dart:ui';
import 'package:flutter/material.dart';

/// Reusable frosted-glass container used across the dashboard.
///
/// Wraps [child] with a blurred, translucent background, a thin border,
/// and a soft shadow. Works well over the map (which is always
/// colorful) or over a dark background — pass [tint] to bias it toward
/// white (light glass) or black/navy (dark glass), and [borderColor] to
/// switch between a classic white frosted edge or the blue glow edge
/// used by the "blue-black glass" cockpit theme.
///
/// Usage:
/// ```dart
/// GlassContainer(
///   borderRadius: 20,
///   padding: const EdgeInsets.all(16),
///   tint: AppColors.glassNavyTint,
///   borderColor: AppColors.glassBlueBorder,
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

  /// Color of the border stroke. Defaults to white (classic frosted
  /// glass). Pass a blue accent (e.g. AppColors.glassBlueBorder) for the
  /// blue-black glass cockpit style used on the dark dashboard pages.
  final Color borderColor;

  /// Opacity of the border stroke.
  final double borderOpacity;

  /// Width of the border stroke. Bumped up (e.g. 1.4-1.6) on the
  /// blue-black glass cockpit widgets so the neon edge actually reads as
  /// "glowing" instead of a faint hairline.
  final double borderWidth;

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
    this.borderColor = Colors.white,
    this.borderOpacity = 0.6,
    this.borderWidth = 1.0,
    this.boxShadow,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    // REVISI: kalau blurSigma <= 0, jangan pakai BackdropFilter sama
    // sekali — beberapa widget (search bar, dropdown, destination bar,
    // strip navigasi) sekarang dibuat solid/flat tanpa efek kaca blur,
    // cukup warna hitam pekat + border biru neon saja.
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: tintOpacity),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor.withValues(alpha: borderOpacity),
          width: borderWidth,
        ),
        gradient: blurSigma <= 0
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  borderColor.withValues(alpha: 0.10),
                  borderColor.withValues(alpha: 0.0),
                ],
              ),
      ),
      child: child,
    );

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
      child: blurSigma <= 0
          ? ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: content,
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                child: content,
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
  final Color borderColor;

  /// Opacity of the border stroke. Defaults to 0.5 (subtle) to keep
  /// existing chips (e.g. the lamp/power/hazard status icons) unchanged.
  /// Pass a higher value (e.g. 0.85) for a clearly visible neon edge.
  final double borderOpacity;

  /// Width of the border stroke. Defaults to 0.8 (thin/subtle).
  final double borderWidth;

  final VoidCallback? onTap;

  const GlassChip({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(10),
    this.borderRadius = 14,
    this.tint = Colors.white,
    this.tintOpacity = 0.5,
    this.borderColor = Colors.white,
    this.borderOpacity = 0.5,
    this.borderWidth = 0.8,
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
              color: borderColor.withValues(alpha: borderOpacity),
              width: borderWidth,
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
