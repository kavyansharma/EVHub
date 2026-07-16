import 'package:flutter/material.dart';

class AppColors {
  // Premium Redesign V2 Color Palette
  static const Color background = Color(0xFF080A12);
  static const Color primary = Color(0xFF00E5FF);      // Cyan
  static const Color secondary = Color(0xFF00FF9C);    // Mint Green
  static const Color accent = Color(0xFF5B8CFF);       // Electric Blue
  static const Color warning = Color(0xFFFFC247);      // Amber
  static const Color danger = Color(0xFFFF4D67);       // Red
  static const Color error = Color(0xFFFF4D67);        // Red Alias

  // Surfaces
  static const Color card = Color(0xFF111524);         // Deep space card
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF8F9CAE); // Slate Grey

  // Gradients
  static const Gradient walletGradient = LinearGradient(
    colors: [Color(0xFF9E00FF), Color(0xFF5B8CFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient chargingGradient = LinearGradient(
    colors: [Color(0xFF5B8CFF), Color(0xFF00E5FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF00FF9C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ----------------------------------------------------
  // LEGACY COLORS (To avoid breaking existing screens before refactor)
  // ----------------------------------------------------
  static const Color primaryCyan = Color(0xFF00E5FF);
  static const Color primaryGreen = Color(0xFF00FF9C);
  static const Color accentPurple = Color(0xFF9E00FF);
  static const Color success = Color(0xFF00FF9C);
  static const Color dangerRed = Color(0xFFFF4D67);

  static const Color primaryBlue = Color(0xFF00E5FF);
  static const Color primaryPurple = Color(0xFF9E00FF);
  static const Color accentCyan = Color(0xFF00E5FF);
  static const Color accentGreen = Color(0xFF00FF9C);
  static const Color accentAmber = Color(0xFFFFC857);

  static const Color darkBackground = Color(0xFF080A12);
  static const Color darkSurface = Color(0xFF111524);
  static const Color darkSurfaceCard = Color(0xFF1F263E);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Color(0xFF8F9CAE);

  static const Color lightBackground = Color(0xFF080A12); // Forced Dark
  static const Color lightSurface = Color(0xFF111524);
  static const Color lightSurfaceCard = Color(0xFF1F263E);
  static const Color lightTextPrimary = Colors.white;
  static const Color lightTextSecondary = Color(0xFF8F9CAE);

  // Brand Dynamic Themes (Custom colored glows)
  static const Color brandTata = Color(0xFF00E5FF);
  static const Color brandMG = Color(0xFFFF4D67);
  static const Color brandMahindra = Color(0xFFFFC247);
  static const Color brandBYD = Color(0xFF5B8CFF);
  static const Color brandHyundai = Color(0xFF00FF9C);
  static const Color brandKia = Color(0xFF00FF9C);
  static const Color brandBMW = Color(0xFFFAFAFA);
  static const Color brandMercedes = Color(0xFF212121);
  static const Color brandTesla = Color(0xFFFF4D67);

  // Glassmorphic Helpers
  static Color glassBorder([Brightness? brightness]) {
    return Colors.white.withOpacity(0.08);
  }

  static Color glassFill([Brightness? brightness]) {
    return card.withOpacity(0.4);
  }

  static List<BoxShadow> neonShadow({required Color color, double blurRadius = 16}) {
    return [
      BoxShadow(
        color: color.withOpacity(0.25),
        blurRadius: blurRadius,
        spreadRadius: 1,
        offset: const Offset(0, 4),
      ),
    ];
  }
  
  static List<BoxShadow> softShadow() {
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.4),
        blurRadius: 16,
        spreadRadius: 0,
        offset: const Offset(0, 8),
      ),
    ];
  }
}

