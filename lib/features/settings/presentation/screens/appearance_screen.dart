import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/color_schemes.dart';
import '../../../../config/theme/theme_preferences.dart';
import '../../../../core/utils/extensions.dart';

/// Appearance settings — theme mode toggle and colour scheme picker.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(themePreferencesProvider);
    final notifier = ref.read(themePreferencesProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.appearanceTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Theme Mode ────────────────────────────────────────
          Text(
            context.l10n.appearanceThemeMode,
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.appearanceThemeModeSubtitle,
            style: context.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          _ThemeModeSelector(
            currentMode: prefs.themeMode,
            onChanged: notifier.setThemeMode,
          ),

          const SizedBox(height: 32),

          // ── Colour Scheme ─────────────────────────────────────
          Text(
            context.l10n.appearanceColorScheme,
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.appearanceColorSchemeSubtitle,
            style: context.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          ...AppColorScheme.values.map(
            (scheme) => _ColorSchemeCard(
              scheme: scheme,
              isSelected: prefs.colorScheme == scheme,
              onTap: () => notifier.setColorScheme(scheme),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Theme Mode Selector ──────────────────────────────────────────

class _ThemeModeSelector extends StatelessWidget {
  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeModeSelector({
    required this.currentMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ThemeMode>(
      segments: [
        ButtonSegment(
          value: ThemeMode.system,
          icon: const Icon(Icons.brightness_auto_rounded, size: 18),
          label: Text(context.l10n.appearanceModeSystem),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          icon: const Icon(Icons.light_mode_rounded, size: 18),
          label: Text(context.l10n.appearanceModeLight),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          icon: const Icon(Icons.dark_mode_rounded, size: 18),
          label: Text(context.l10n.appearanceModeDark),
        ),
      ],
      selected: {currentMode},
      onSelectionChanged: (s) => onChanged(s.first),
      showSelectedIcon: false,
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ── Colour Scheme Card ───────────────────────────────────────────

class _ColorSchemeCard extends StatelessWidget {
  final AppColorScheme scheme;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorSchemeCard({
    required this.scheme,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = schemeColorMap[scheme]!;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final primary = isLight ? colors.primaryLight : colors.primaryDark;
    final accent = isLight ? colors.accentLight : colors.accentDark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isSelected
              ? BorderSide(color: primary, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Colour preview circles
                _SwatchCircle(color: primary, size: 36),
                const SizedBox(width: 8),
                _SwatchCircle(color: accent, size: 36),
                const SizedBox(width: 16),

                // Name + description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _schemeName(context, scheme),
                        style: context.textTheme.titleMedium,
                      ),
                      Text(
                        _schemeDesc(context, scheme),
                        style: context.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),

                // Selected indicator
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: primary,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _schemeName(BuildContext context, AppColorScheme s) {
    switch (s) {
      case AppColorScheme.pacelli:
        return context.l10n.appearanceSchemePacelli;
      case AppColorScheme.claude:
        return context.l10n.appearanceSchemeClaude;
      case AppColorScheme.gemini:
        return context.l10n.appearanceSchemeGemini;
    }
  }

  String _schemeDesc(BuildContext context, AppColorScheme s) {
    switch (s) {
      case AppColorScheme.pacelli:
        return context.l10n.appearanceSchemePacelliDesc;
      case AppColorScheme.claude:
        return context.l10n.appearanceSchemeClaudeDesc;
      case AppColorScheme.gemini:
        return context.l10n.appearanceSchemeGeminiDesc;
    }
  }
}

// ── Colour Swatch Circle ─────────────────────────────────────────

class _SwatchCircle extends StatelessWidget {
  final Color color;
  final double size;

  const _SwatchCircle({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.black.withOpacity(0.08),
          width: 1,
        ),
      ),
    );
  }
}
