import 'package:flutter/material.dart';

/// Available colour schemes for Pacelli.
///
/// Each scheme defines primary + accent colours for both light and dark modes.
/// Text colours and semantic colours (success, warning, error, info) are shared
/// across all schemes.
enum AppColorScheme {
  /// Default Pacelli palette — sage green / teal.
  pacelli,

  /// Anthropic-inspired — warm purple / violet.
  claude,

  /// Google-inspired — ocean blue / indigo.
  gemini,
}

/// Colour palette for a single scheme in both light and dark modes.
class SchemeColors {
  final Color primaryLight;
  final Color primaryDark;
  final Color accentLight;
  final Color accentDark;

  const SchemeColors({
    required this.primaryLight,
    required this.primaryDark,
    required this.accentLight,
    required this.accentDark,
  });
}

/// Maps each scheme to its concrete colour values.
const Map<AppColorScheme, SchemeColors> schemeColorMap = {
  // ── Pacelli (current) ──────────────────────────────────────
  // Sage green / muted teal — calm, natural, peaceful.
  AppColorScheme.pacelli: SchemeColors(
    primaryLight: Color(0xFF7EA87E), // soft sage green
    primaryDark: Color(0xFF6BA3A0), // muted teal
    accentLight: Color(0xFFCF7B5F), // terracotta
    accentDark: Color(0xFFD4A06A), // soft amber
  ),

  // ── Claude ─────────────────────────────────────────────────
  // Warm purple / violet — Anthropic-inspired.
  AppColorScheme.claude: SchemeColors(
    primaryLight: Color(0xFF8B6CC1), // warm purple
    primaryDark: Color(0xFFA78BDB), // lighter violet for dark mode
    accentLight: Color(0xFFD4785B), // warm coral
    accentDark: Color(0xFFE8A87C), // soft peach
  ),

  // ── Gemini ─────────────────────────────────────────────────
  // Ocean blue / indigo — Google AI-inspired.
  AppColorScheme.gemini: SchemeColors(
    primaryLight: Color(0xFF4A86C8), // ocean blue
    primaryDark: Color(0xFF6BA3E0), // lighter sky blue for dark mode
    accentLight: Color(0xFFE07A5F), // coral accent
    accentDark: Color(0xFFEDA07A), // warm salmon
  ),
};

/// Shared colours that don't change with the scheme.
class SharedColors {
  SharedColors._();

  // ── Light mode backgrounds & text ──
  static const Color backgroundLight = Color(0xFFF8F5F0);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF2D2D2D);
  static const Color textSecondaryLight = Color(0xFF6B6B6B);

  // ── Dark mode backgrounds & text ──
  static const Color backgroundDark = Color(0xFF1A1A1A);
  static const Color surfaceDark = Color(0xFF242424);
  static const Color textPrimaryDark = Color(0xFFE8E8E8);
  static const Color textSecondaryDark = Color(0xFF9E9E9E);

  // ── Semantic (shared across all schemes & modes) ──
  static const Color success = Color(0xFF6BAF6B);
  static const Color warning = Color(0xFFD4A44A);
  static const Color error = Color(0xFFCF6B6B);
  static const Color info = Color(0xFF6B9ECF);
}
