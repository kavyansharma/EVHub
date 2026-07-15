import 'package:flutter/material.dart';

class AppColors {
  // New Premium Palette (Tesla/Apple/Nothing UI inspired)
  static const Color primaryGreen = Color(0xFF00D26A); // Success / Primary EV color
  static const Color primaryBlue = Color(0xFF007AFF);  // Secondary / Trust
  static const Color accentCyan = Color(0xFF00E5FF);   // Highlights / Charging

  // Background & Surfaces
  static const Color background = Color(0xFF0D1117);
  static const Color card = Color(0xFF1A1F2E);

  // Status Colors
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFFF5252);

  // Text
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFE0E0E0); // Grey 300

  // ----------------------------------------------------
  // LEGACY COLORS (To be removed after redesign complete)
  // ----------------------------------------------------
  static const Color primaryCyan = Color(0xFF00E5FF);
  static const Color primaryPurple = Color(0xFF9E00FF);
  static const Color accentGreen = Color(0xFF00E676);
  static const Color accentAmber = Color(0xFFFFB300);
  static const Color dangerRed = Color(0xFFFF1744);

  static const Color darkBackground = Color(0xFF0A0E17);
  static const Color darkSurface = Color(0xFF151B26);
  static const Color darkSurfaceCard = Color(0xFF1E2638);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF90A4AE);

  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceCard = Color(0xFFECEFF1);
  static const Color lightTextPrimary = Color(0xFF1A237E);
  static const Color lightTextSecondary = Color(0xFF5C6BC0);

  // Brand Dynamic Themes (Fallback defaults)
  static const Color brandTata = Color(0xFF007AFF);      // Blue
  static const Color brandMG = Color(0xFFFF1744);        // Red
  static const Color brandMahindra = Color(0xFFD84315);  // Copper
  static const Color brandBYD = Color(0xFFB0BEC5);       // Silver
  static const Color brandHyundai = Color(0xFF1E88E5);   // Blue
  static const Color brandKia = Color(0xFF00C853);       // Green
  static const Color brandBMW = Color(0xFFFAFAFA);       // White
  static const Color brandMercedes = Color(0xFF212121);  // Black
  static const Color brandTesla = Color(0xFFE82127);     // Red

  // Glassmorphic Helpers
  static Color glassBorder([Brightness? brightness]) {
    return Colors.white.withOpacity(0.08);
  }

  static Color glassFill([Brightness? brightness]) {
    return const Color(0xFF1A1F2E).withOpacity(0.65);
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
  
  static List<BoxShadow> softShadow() {
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.2),
        blurRadius: 10,
        spreadRadius: 0,
        offset: const Offset(0, 4),
      ),
    ];
  }
}
