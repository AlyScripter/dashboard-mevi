import 'package:flutter/material.dart';

class AppColors {
  // Battery Colors
  static const Color batteryGood = Color(0xFF4CAF50); // Green
  static const Color batteryMedium = Color(0xFFFFEB3B); // Yellow
  static const Color batteryLow = Color(0xFFF44336); // Red
  // Primary Colors
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFF64B5F6);

  // Background Colors
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF121212);
  static const Color cardBackground = Color(0xFF1E1E1E);

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textHint = Color(0xFF666666);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Accent Colors
  static const Color accent = Color(0xFF00BCD4);
  static const Color accentLight = Color(0xFF4DD0E1);
  static const Color accentDark = Color(0xFF0097A7);

  // Gauge Colors
  static const Color gaugeBackground = Color(0xFF2A2A2A);
  static const Color gaugeForeground = Color(0xFF00E676);
  static const Color gaugeWarning = Color(0xFFFFEB3B);
  static const Color gaugeDanger = Color(0xFFFF5252);

  // Dashboard Specific
  static const Color dashboardPanel = Color(0xFF1A1A1A);
  static const Color dashboardBorder = Color(0xFF333333);
  static const Color dashboardShadow = Color(0x4D000000);

  // Additional Colors
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFFFFFFFF);

  // Blue-Black Glass Theme (destination bar, nav strip, search bar,
  // dropdowns, dialogs) — deep navy glass with a soft blue glow border,
  // used to give the floating widgets a premium "cockpit HUD" look.
  // REVISI: sebelumnya navy tint ini terlalu terang/tembus (0xFF0A0E1A @
  // opacity rendah di masing-masing widget) sehingga search bar, dropdown
  // hasil pencarian, dan bar destinasi terlihat "beda sendiri" dari panel
  // kiri yang solid hitam. Sekarang dibuat hitam pekat (senada dengan
  // gradient panel kiri 0xFF12161F -> 0xFF0A0D13) + border biru neon yang
  // lebih menyala, supaya semua widget kaca di dashboard senada.
  static const Color glassNavyTint = Color(0xFF090B10);
  static const Color glassBlueBorder = Color(0xFF22B2FF);
  static const Color glassBlueGlow = Color(0xFF22B2FF);
  static const Color glassSurface = Color(0xFF10151F);
  static const Color glassSurfaceAlt = Color(0xFF151B28);
  static const Color glassDivider = Color(0xFF232B3B);
  static const Color glassTextPrimary = Color(0xFFF3F6FC);
  static const Color glassTextSecondary = Color(0xFF9AA7BD);

  // Settings page — flat near-black shell + distinctly blue-navy section
  // cards (per the reference EV "CONTROL" panel: dark shell, lighter
  // blue-tinted tiles), so Data Source / About visibly pop off the page
  // instead of blending into it like the plain glassSurface tone did.
  static const Color settingsPageBg = Color(0xFF0E1116);
  static const Color settingsCardBg = Color(0xFF16273F);
  static const Color settingsCardBgAlt = Color(0xFF1C3252);
}
