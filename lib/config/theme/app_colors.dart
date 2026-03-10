import 'package:flutter/material.dart';

import 'color_schemes.dart';

/// Pacelli colour palette.
///
/// Default values point to the Pacelli scheme.
/// Use [SharedColors] for backgrounds, text, and semantic colours (shared
/// across all schemes).  Use [schemeColorMap] for scheme-specific primaries.
class AppColors {
  AppColors._();

  // ── Light Mode (Pacelli defaults — kept for backward compatibility) ──

  static const Color primaryLight = Color(0xFF7EA87E);
  static const Color backgroundLight = Color(0xFFF8F5F0);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color accentLight = Color(0xFFCF7B5F);
  static const Color textPrimaryLight = Color(0xFF2D2D2D);
  static const Color textSecondaryLight = Color(0xFF6B6B6B);

  // ── Dark Mode (Pacelli defaults) ──

  static const Color primaryDark = Color(0xFF6BA3A0);
  static const Color backgroundDark = Color(0xFF1A1A1A);
  static const Color surfaceDark = Color(0xFF242424);
  static const Color accentDark = Color(0xFFD4A06A);
  static const Color textPrimaryDark = Color(0xFFE8E8E8);
  static const Color textSecondaryDark = Color(0xFF9E9E9E);

  // ── Semantic Colours (shared) ──

  static const Color success = Color(0xFF6BAF6B);
  static const Color warning = Color(0xFFD4A44A);
  static const Color error = Color(0xFFCF6B6B);
  static const Color info = Color(0xFF6B9ECF);
}
