import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'typography.dart';
import 'dimensions.dart';

enum AppThemeMode { light, dark, system }

class AppTheme {
  // Light Theme Colors
  static const Color lightPrimary = Color(0xFF2196F3);
  static const Color lightPrimaryVariant = Color(0xFF1976D2);
  static const Color lightSecondary = Color(0xFF03DAC6);
  static const Color lightBackground = Color(0xFFF2F2F2);
  static const Color lightSurface = Colors.white;
  static const Color lightError = Color(0xFFB00020);
  static const Color lightOnPrimary = Colors.white;
  static const Color lightOnSecondary = Colors.black;
  static const Color lightOnBackground = Colors.black87;
  static const Color lightOnSurface = Colors.black87;
  static const Color lightOnError = Colors.white;

  // Dark Theme Colors
  static const Color darkPrimary = Color(0xFF90CAF9);
  static const Color darkPrimaryVariant = Color(0xFF42A5F5);
  static const Color darkSecondary = Color(0xFF03DAC6);
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkError = Colors.white;
  static const Color darkOnPrimary = Colors.black;
  static const Color darkOnSecondary = Colors.black;
  static const Color darkOnBackground = Colors.white;
  static const Color darkOnSurface = Colors.white;
  static const Color darkOnError = Colors.black;

  // Dashboard specific colors
  static const Color dashboardCardLight = Colors.white;
  static const Color dashboardCardDark = Color(0xFF2C2C2C);
  static const Color dashboardPanelLight = Colors.white;
  static const Color dashboardPanelDark = Color(0xFF1A1A1A);

  // Status colors (same for both themes)
  static const Color statusGreen = Color(0xFF4CAF50);
  static const Color statusYellow = Color(0xFFFFC107);
  static const Color statusOrange = Color(0xFFFF9800);
  static const Color statusRed = Color(0xFFF44336);
  static const Color statusBlue = Color(0xFF2196F3);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: lightPrimary,
        primaryContainer: lightPrimaryVariant,
        secondary: lightSecondary,
        surface: lightBackground,
        surfaceContainerHighest: lightSurface,
        error: lightError,
        onPrimary: lightOnPrimary,
        onSecondary: lightOnSecondary,
        onSurface: lightOnBackground,
        onSurfaceVariant: lightOnSurface,
        onError: lightOnError,
      ),
      textTheme: AppTypography.textTheme,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: lightBackground,
        foregroundColor: lightOnBackground,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: dashboardCardLight,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: lightOnPrimary,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingLarge,
            vertical: AppDimensions.paddingMedium,
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: lightOnBackground),
      scaffoldBackgroundColor: lightBackground,
      dividerColor: Colors.grey.shade300,
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: darkPrimary,
        primaryContainer: darkPrimaryVariant,
        secondary: darkSecondary,
        surface: darkBackground,
        surfaceContainerHighest: darkSurface,
        error: darkError,
        onPrimary: darkOnPrimary,
        onSecondary: darkOnSecondary,
        onSurface: darkOnBackground,
        onSurfaceVariant: darkOnSurface,
        onError: darkOnError,
      ),
      textTheme: AppTypography.textTheme.apply(
        bodyColor: darkOnBackground,
        displayColor: darkOnBackground,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: darkBackground,
        foregroundColor: darkOnBackground,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: dashboardCardDark,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: darkOnPrimary,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingLarge,
            vertical: AppDimensions.paddingMedium,
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: darkOnBackground),
      scaffoldBackgroundColor: darkBackground,
      dividerColor: Colors.grey.shade700,
    );
  }

  // Dashboard specific theme extensions
  static Color getDashboardBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? lightBackground
        : darkBackground;
  }

  static Color getDashboardCard(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? dashboardCardLight
        : dashboardCardDark;
  }

  static Color getDashboardPanel(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? dashboardPanelLight
        : dashboardPanelDark;
  }

  static Color getTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? lightOnBackground
        : darkOnBackground;
  }

  static Color getSecondaryTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.black54
        : Colors.white70;
  }

  static Color getBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.grey.shade300
        : Colors.grey.shade700;
  }

  // Status colors with theme awareness
  static Color getStatusColor(String status, BuildContext context) {
    switch (status.toLowerCase()) {
      case 'good':
      case 'operational':
      case 'success':
        return statusGreen;
      case 'warning':
      case 'caution':
        return statusYellow;
      case 'error':
      case 'danger':
        return statusRed;
      case 'info':
        return statusBlue;
      default:
        return Theme.of(context).brightness == Brightness.dark
            ? Colors.grey.shade400
            : Colors.grey.shade600;
    }
  }

  // Chart colors with theme awareness
  static List<Color> getChartColors(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) {
      return [
        const Color(0xFF90CAF9), // Light blue
        const Color(0xFF81C784), // Light green
        const Color(0xFFFFB74D), // Light orange
        const Color(0xFFE57373), // Light red
        const Color(0xFFBA68C8), // Light purple
        const Color(0xFF4DB6AC), // Light teal
        const Color(0xFFF06292), // Light pink
        const Color(0xFF64B5F6), // Light cyan
      ];
    } else {
      return [
        Colors.blue,
        Colors.green,
        Colors.orange,
        Colors.red,
        Colors.purple,
        Colors.teal,
        Colors.pink,
        Colors.cyan,
      ];
    }
  }
}
