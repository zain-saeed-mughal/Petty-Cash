import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryNavy = Color(0xFF0F172A); // Slate 900
  static const Color primaryBlue = Color(0xFF2563EB); // Royal Blue
  static const Color accentTeal = Color(0xFF0D9488); // Teal
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceLight = Colors.white;
  static const Color surfaceMuted = Color(0xFFF1F5F9); // Slate 100
  static const Color borderLight = Color(0xFFE2E8F0); // Slate 200

  // Status Colors
  static const Color statusPending = Color(0xFFF59E0B); // Amber 500
  static const Color statusPendingBg = Color(0xFFFEF3C7); // Amber 100
  static const Color statusApproved = Color(0xFF10B981); // Emerald 500
  static const Color statusApprovedBg = Color(0xFFD1FAE5); // Emerald 100
  static const Color statusRejected = Color(0xFFEF4444); // Red 500
  static const Color statusRejectedBg = Color(0xFFFEE2E2); // Red 100
  static const Color statusPaid = Color(0xFF0EA5E9); // Sky 500
  static const Color statusPaidBg = Color(0xFFE0F2FE); // Sky 100

  // Role Badges
  static const Color roleSuperAdmin = Color(0xFF8B5CF6); // Violet 500
  static const Color roleAdmin = Color(0xFF3B82F6); // Blue 500
  static const Color roleFinance = Color(0xFF10B981); // Emerald 500
  static const Color roleOfficeBoy = Color(0xFFF59E0B); // Amber 500

  // Custom Shadow for Premium Feel
  static List<BoxShadow> get premiumShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        onPrimary: Colors.white,
        secondary: accentTeal,
        surface: surfaceLight,
        error: statusRejected,
      ),
      scaffoldBackgroundColor: backgroundLight,
      textTheme: baseTextTheme.copyWith(
        titleLarge: baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        titleMedium: baseTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.3),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(letterSpacing: 0),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(letterSpacing: 0),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0, // Prevents tinting on scroll
        backgroundColor: surfaceLight,
        foregroundColor: primaryNavy,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: primaryNavy,
          letterSpacing: -0.8,
        ),
        iconTheme: IconThemeData(color: primaryNavy),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceLight,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderLight, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: statusRejected, width: 1.5),
        ),
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 15, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.pressed)) {
                return Colors.white.withValues(alpha: 0.1);
              }
              return null;
            },
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryNavy,
          side: const BorderSide(color: borderLight, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceLight,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderLight,
        thickness: 1,
        space: 24,
      ),
    );
  }
}

