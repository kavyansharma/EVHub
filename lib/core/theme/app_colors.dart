import 'package:flutter/material.dart';

class AppColors {
  // Phase 6 Premium Palette (Tesla/Statiq inspired)
  static const Color primaryCyan = Color(0xFF00D9FF);   // Electric Blue
  static const Color primaryGreen = Color(0xFF00FF9D);  // Neon Green
  static const Color accentPurple = Color(0xFF9E00FF);  // For Wallet Gradients
  
  // Background & Surfaces
  static const Color background = Color(0xFF07090D);
  static const Color card = Color(0xFF111827);

  // Status Colors
  static const Color success = Color(0xFF1ED760);
  static const Color warning = Color(0xFFFFC857);
  static const Color error = Color(0xFFFF5C5C);
  static const Color dangerRed = Color(0xFFFF5C5C); // Alias for legacy support

  // Text
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9CA3AF); // Cool Grey

  // ----------------------------------------------------
  // LEGACY COLORS (To avoid breaking existing screens before refactor)
  // ----------------------------------------------------
  static const Color primaryBlue = Color(0xFF00D9FF);
  static const Color primaryPurple = Color(0xFF9E00FF);
  static const Color accentCyan = Color(0xFF00D9FF);
  static const Color accentGreen = Color(0xFF1ED760);
  static const Color accentAmber = Color(0xFFFFC857);

  static const Color darkBackground = Color(0xFF07090D);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkSurfaceCard = Color(0xFF1E2638);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Color(0xFF9CA3AF);

  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceCard = Color(0xFFECEFF1);
  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF6B7280);

  // Brand Dynamic Themes
  static const Color brandTata = Color(0xFF00D9FF);      // Electric Blue
  static const Color brandMG = Color(0xFFFF5C5C);        // Red
  static const Color brandMahindra = Color(0xFFD84315);  // Copper
  static const Color brandBYD = Color(0xFFB0BEC5);       // Silver
  static const Color brandHyundai = Color(0xFF1E88E5);   // Blue
  static const Color brandKia = Color(0xFF00FF9D);       // Neon Green
  static const Color brandBMW = Color(0xFFFAFAFA);       // White
  static const Color brandMercedes = Color(0xFF212121);  // Black
  static const Color brandTesla = Color(0xFFE82127);     // Tesla Red

  // Glassmorphic Helpers
  static Color glassBorder([Brightness? brightness]) {
    return Colors.white.withOpacity(0.08);
  }

  static Color glassFill([Brightness? brightness]) {
    return card.withOpacity(0.65);
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
