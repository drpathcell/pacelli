import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'color_schemes.dart';

// ── SharedPreferences keys ──
const _kThemeMode = 'theme_mode'; // "system" | "light" | "dark"
const _kColorScheme = 'color_scheme'; // "pacelli" | "claude" | "gemini"

/// Holds the user's theme preferences.
@immutable
class ThemePreferences {
  final ThemeMode themeMode;
  final AppColorScheme colorScheme;

  const ThemePreferences({
    this.themeMode = ThemeMode.system,
    this.colorScheme = AppColorScheme.pacelli,
  });

  ThemePreferences copyWith({
    ThemeMode? themeMode,
    AppColorScheme? colorScheme,
  }) {
    return ThemePreferences(
      themeMode: themeMode ?? this.themeMode,
      colorScheme: colorScheme ?? this.colorScheme,
    );
  }
}

/// Notifier that reads/writes theme preferences to SharedPreferences.
class ThemePreferencesNotifier extends StateNotifier<ThemePreferences> {
  ThemePreferencesNotifier() : super(const ThemePreferences()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    final modeString = prefs.getString(_kThemeMode) ?? 'system';
    final schemeString = prefs.getString(_kColorScheme) ?? 'pacelli';

    state = ThemePreferences(
      themeMode: _parseThemeMode(modeString),
      colorScheme: _parseColorScheme(schemeString),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, _themeModeToString(mode));
  }

  Future<void> setColorScheme(AppColorScheme scheme) async {
    state = state.copyWith(colorScheme: scheme);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kColorScheme, _colorSchemeToString(scheme));
  }

  // ── Serialisation helpers ──

  static ThemeMode _parseThemeMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static AppColorScheme _parseColorScheme(String value) {
    switch (value) {
      case 'claude':
        return AppColorScheme.claude;
      case 'gemini':
        return AppColorScheme.gemini;
      default:
        return AppColorScheme.pacelli;
    }
  }

  static String _colorSchemeToString(AppColorScheme scheme) {
    switch (scheme) {
      case AppColorScheme.pacelli:
        return 'pacelli';
      case AppColorScheme.claude:
        return 'claude';
      case AppColorScheme.gemini:
        return 'gemini';
    }
  }
}

/// Global theme preferences provider.
final themePreferencesProvider =
    StateNotifierProvider<ThemePreferencesNotifier, ThemePreferences>(
  (ref) => ThemePreferencesNotifier(),
);
