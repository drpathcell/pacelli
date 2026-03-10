import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'color_schemes.dart';

/// Pacelli theme configuration.
///
/// Builds both light and dark themes for any [AppColorScheme].
/// Uses Plus Jakarta Sans for a clean, friendly feel.
class AppTheme {
  AppTheme._();

  /// Returns a light [ThemeData] for the given colour scheme.
  /// Falls back to the default Pacelli palette if [scheme] is null.
  static ThemeData lightThemeFor([AppColorScheme scheme = AppColorScheme.pacelli]) {
    final colors = schemeColorMap[scheme]!;
    return _buildTheme(
      brightness: Brightness.light,
      primary: colors.primaryLight,
      accent: colors.accentLight,
      background: SharedColors.backgroundLight,
      surface: SharedColors.surfaceLight,
      textPrimary: SharedColors.textPrimaryLight,
      textSecondary: SharedColors.textSecondaryLight,
      borderColor: Colors.grey.shade200,
      inputBorderColor: Colors.grey.shade300,
    );
  }

  /// Returns a dark [ThemeData] for the given colour scheme.
  static ThemeData darkThemeFor([AppColorScheme scheme = AppColorScheme.pacelli]) {
    final colors = schemeColorMap[scheme]!;
    return _buildTheme(
      brightness: Brightness.dark,
      primary: colors.primaryDark,
      accent: colors.accentDark,
      background: SharedColors.backgroundDark,
      surface: SharedColors.surfaceDark,
      textPrimary: SharedColors.textPrimaryDark,
      textSecondary: SharedColors.textSecondaryDark,
      borderColor: const Color(0xFF3A3A3A),
      inputBorderColor: const Color(0xFF3A3A3A),
    );
  }

  /// Backward-compatible getters for the default Pacelli scheme.
  static ThemeData get lightTheme => lightThemeFor();
  static ThemeData get darkTheme => darkThemeFor();

  // ── Private builder ──

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color primary,
    required Color accent,
    required Color background,
    required Color surface,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
    required Color inputBorderColor,
  }) {
    final isLight = brightness == Brightness.light;
    final colorScheme = isLight
        ? ColorScheme.light(
            primary: primary,
            secondary: accent,
            surface: surface,
            error: AppColors.error,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: textPrimary,
            onError: Colors.white,
          )
        : ColorScheme.dark(
            primary: primary,
            secondary: accent,
            surface: surface,
            error: AppColors.error,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: textPrimary,
            onError: Colors.white,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,

      // Typography
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: textPrimary),
          displayMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: textPrimary),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
          bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: textPrimary),
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: textSecondary),
          labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),

      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
      ),

      // Elevated Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      // Outlined Buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: primary),
        ),
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: inputBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: inputBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 2,
      ),

      // Bottom Navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
