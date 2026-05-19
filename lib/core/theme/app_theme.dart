import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryColor = Color(0xFF003527);
  static const Color primaryContainer = Color(0xFF064E3B);
  static const Color primaryFixed = Color(0xFFC3ECD7); // Light Emerald
  static const Color secondaryColor = Color(0xFF416656);
  static const Color secondaryContainer = Color(0xFFE8F5E9);
  static const Color tertiaryColor = Color(0xFFE67E22); // Orange Accent
  static const Color tertiaryFixed = Color(0xFFFFE0B2); // Light Orange
  static const Color accentColor = Color(0xFF10B981);
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color surfaceColor = Colors.white;
  static const Color onSurface = Color(0xFF191C1D);
  static const Color tertiaryContainer = Color(0xFFFF975E);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      primaryContainer: primaryContainer,
      secondary: secondaryColor,
      secondaryContainer: secondaryContainer,
      surface: surfaceColor,
      background: backgroundColor,
      onSurface: onSurface,
      tertiaryContainer: tertiaryContainer,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.02,
        color: primaryColor,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.01,
        color: primaryColor,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primaryContainer,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.05,
        color: secondaryColor,
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF95D3BA),
    scaffoldBackgroundColor: const Color(0xFF061A14),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF95D3BA),
      primaryContainer: Color(0xFF002117),
      secondary: Color(0xFFC3ECD7),
      surface: Color(0xFF191C1D),
      background: Color(0xFF061A14),
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
  );
}

// Glassmorphism Decoration Utility
BoxDecoration glassDecoration({
  double blur = 16,
  double opacity = 0.7,
  BorderRadius? borderRadius,
}) {
  return BoxDecoration(
    color: Colors.white.withOpacity(opacity),
    borderRadius: borderRadius ?? BorderRadius.circular(16),
    border: Border.all(
      color: Colors.white.withOpacity(0.4),
      width: 1.0,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 20,
        offset: const Offset(0, 4),
      ),
    ],
  );
}
