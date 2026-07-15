import 'package:flutter/material.dart';

class AppColors {
  // Common Colors
  static const Color primaryCyan = Color(0xFF00E5FF);
  static const Color primaryPurple = Color(0xFF9E00FF);
  static const Color accentGreen = Color(0xFF00E676);
  static const Color accentAmber = Color(0xFFFFB300);
  static const Color dangerRed = Color(0xFFFF1744);

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF0A0E17);
  static const Color darkSurface = Color(0xFF151B26);
  static const Color darkSurfaceCard = Color(0xFF1E2638);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF90A4AE);

  // Light Theme Colors
  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceCard = Color(0xFFECEFF1);
  static const Color lightTextPrimary = Color(0xFF1A237E);
  static const Color lightTextSecondary = Color(0xFF5C6BC0);

  // Glassmorphic Helper Effects
  static Color glassBorder(Brightness brightness) {
    return brightness == Brightness.dark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.06);
  }

  static Color glassFill(Brightness brightness) {
    return brightness == Brightness.dark
        ? Color(0xFF1E2638).withOpacity(0.65)
        : Colors.white.withOpacity(0.75);
  }

  static List<BoxShadow> neonShadow({required Color color, double blurRadius = 12}) {
    return [
      BoxShadow(
        color: color.withOpacity(0.4),
        blurRadius: blurRadius,
        spreadRadius: 1,
        offset: const Offset(0, 2),
      ),
    ];
  }
}
