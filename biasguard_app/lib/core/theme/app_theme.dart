// BiasGuard — Sentinel Obsidian Design System
// Exact color tokens from the Stitch project

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // ─── Surface Hierarchy ────────────────────────────────────────────
  static const background         = Color(0xFF13121C);
  static const surfaceContainerLowest = Color(0xFF0D0D16);
  static const surfaceContainerLow    = Color(0xFF1B1B24);
  static const surfaceContainer       = Color(0xFF1F1F28);
  static const surfaceContainerHigh   = Color(0xFF292933);
  static const surfaceContainerHighest= Color(0xFF34343E);
  static const surfaceBright          = Color(0xFF393843);
  static const surfaceVariant         = Color(0xFF34343E);

  // ─── Primary (Indigo) ─────────────────────────────────────────────
  static const primary            = Color(0xFFC0C1FF);
  static const primaryContainer   = Color(0xFF8083FF);
  static const onPrimary          = Color(0xFF1000A9);
  static const onPrimaryContainer = Color(0xFF0D0096);
  static const primaryFixed       = Color(0xFFE1E0FF);
  // Gradient
  static const gradientStart      = Color(0xFF6366F1);
  static const gradientEnd        = Color(0xFF8B5CF6);

  // ─── Secondary (Purple) ───────────────────────────────────────────
  static const secondary          = Color(0xFFD0BCFF);
  static const secondaryContainer = Color(0xFF571BC1);
  static const onSecondary        = Color(0xFF3C0091);

  // ─── Tertiary / Fair (Emerald) ────────────────────────────────────
  static const tertiary           = Color(0xFF4EDEA3);
  static const tertiaryContainer  = Color(0xFF00885D);
  static const onTertiary         = Color(0xFF003824);
  // Alias
  static const fairGreen          = Color(0xFF10B981);
  static const fairGreenContainer = Color(0xFF064E3B);

  // ─── Error / Critical (Red) ───────────────────────────────────────
  static const error              = Color(0xFFFFB4AB);
  static const errorContainer     = Color(0xFF93000A);
  static const onError            = Color(0xFF690005);
  static const criticalRed        = Color(0xFFEF4444);
  static const criticalRedDim     = Color(0xFF7F1D1D);

  // ─── Moderate (Amber) ─────────────────────────────────────────────
  static const moderateAmber      = Color(0xFFF59E0B);
  static const moderateAmberDim   = Color(0xFF78350F);

  // ─── Text ─────────────────────────────────────────────────────────
  static const onSurface          = Color(0xFFE4E1EE);
  static const onSurfaceVariant   = Color(0xFFC7C4D7);
  static const outline            = Color(0xFF908FA0);
  static const outlineVariant     = Color(0xFF464554);

  // ─── Light mode ───────────────────────────────────────────────────
  static const lightBackground    = Color(0xFFF1F5F9);
  static const lightSurface       = Color(0xFFFFFFFF);
  static const lightOnSurface     = Color(0xFF1A1A2E);
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        tertiaryContainer: AppColors.tertiaryContainer,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
        surface: AppColors.surfaceContainer,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
      ),
      textTheme: _buildTextTheme(AppColors.onSurface),
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.gradientStart,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 16,
        ),
        labelStyle: const TextStyle(color: AppColors.onSurfaceVariant),
        hintStyle: const TextStyle(color: AppColors.outline),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceContainerLow,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
        iconTheme: IconThemeData(color: AppColors.onSurface),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceContainerHigh,
        labelStyle: const TextStyle(
          color: AppColors.onSurfaceVariant,
          fontSize: 12,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outlineVariant,
        thickness: 1,
        space: 0,
      ),
    );
  }

  static ThemeData get light {
    return ThemeData.light(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.gradientStart,
        brightness: Brightness.light,
      ),
      textTheme: _buildTextTheme(AppColors.lightOnSurface),
    );
  }

  static TextTheme _buildTextTheme(Color baseColor) {
    return GoogleFonts.plusJakartaSansTextTheme().copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
        fontSize: 56, fontWeight: FontWeight.w700, color: baseColor,
        letterSpacing: -1.0,
      ),
      displayMedium: GoogleFonts.plusJakartaSans(
        fontSize: 45, fontWeight: FontWeight.w700, color: baseColor,
        letterSpacing: -0.5,
      ),
      displaySmall: GoogleFonts.plusJakartaSans(
        fontSize: 36, fontWeight: FontWeight.w700, color: baseColor,
      ),
      headlineLarge: GoogleFonts.plusJakartaSans(
        fontSize: 32, fontWeight: FontWeight.w700, color: baseColor,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 28, fontWeight: FontWeight.w600, color: baseColor,
      ),
      headlineSmall: GoogleFonts.plusJakartaSans(
        fontSize: 24, fontWeight: FontWeight.w600, color: baseColor,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 22, fontWeight: FontWeight.w600, color: baseColor,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 16, fontWeight: FontWeight.w600, color: baseColor,
        letterSpacing: 0.1,
      ),
      titleSmall: GoogleFonts.plusJakartaSans(
        fontSize: 14, fontWeight: FontWeight.w600, color: baseColor,
        letterSpacing: 0.1,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 16, fontWeight: FontWeight.w400,
        color: baseColor.withOpacity(0.87),
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 14, fontWeight: FontWeight.w400,
        color: baseColor.withOpacity(0.87),
      ),
      bodySmall: GoogleFonts.plusJakartaSans(
        fontSize: 12, fontWeight: FontWeight.w400,
        color: baseColor.withOpacity(0.6),
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 14, fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelMedium: GoogleFonts.plusJakartaSans(
        fontSize: 12, fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
      labelSmall: GoogleFonts.plusJakartaSans(
        fontSize: 11, fontWeight: FontWeight.w500,
        letterSpacing: 1.2,
      ),
    );
  }
}
