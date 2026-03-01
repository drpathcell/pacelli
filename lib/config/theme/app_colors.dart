import 'package:flutter/material.dart';

/// Pacelli colour palette.
///
/// Inspired by the serenity of a Sunday morning with coffee and a tidy house.
/// Calm, natural, warm — never corporate.
class AppColors {
  AppColors._();

  // ── Light Mode ────────────────────────────────────────────

  /// Soft sage green — calm, natural, peaceful
  static const Color primaryLight = Color(0xFF7EA87E);

  /// Warm cream / off-white — background warmth
  static const Color backgroundLight = Color(0xFFF8F5F0);

  /// Slightly warmer surface for cards
  static const Color surfaceLight = Color(0xFFFFFFFF);

  /// Terracotta / warm coral — buttons, highlights
  static const Color accentLight = Color(0xFFCF7B5F);

  /// Dark grey (not pure black) — easy on the eyes
  static const Color textPrimaryLight = Color(0xFF2D2D2D);

  /// Medium grey — secondary text
  static const Color textSecondaryLight = Color(0xFF6B6B6B);

  // ── Dark Mode ─────────────────────────────────────────────

  /// Muted teal — calm and readable in the dark
  static const Color primaryDark = Color(0xFF6BA3A0);

  /// Dark charcoal — true dark background
  static const Color backgroundDark = Color(0xFF1A1A1A);

  /// Slightly lighter surface for cards
  static const Color surfaceDark = Color(0xFF242424);

  /// Soft amber — warm accent in dark mode
  static const Color accentDark = Color(0xFFD4A06A);

  /// Light grey (not pure white) — easy on the eyes
  static const Color textPrimaryDark = Color(0xFFE8E8E8);

  /// Medium grey — secondary text in dark mode
  static const Color textSecondaryDark = Color(0xFF9E9E9E);

  // ── Semantic Colours (shared) ─────────────────────────────

  /// Task complete
  static const Color success = Color(0xFF6BAF6B);

  /// Due soon / warning
  static const Color warning = Color(0xFFD4A44A);

  /// Overdue / error
  static const Color error = Color(0xFFCF6B6B);

  /// Informational
  static const Color info = Color(0xFF6B9ECF);
}
