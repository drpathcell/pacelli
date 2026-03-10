# Pacelli — Theme & Colour Scheme Management

## Purpose
Add, modify, or remove colour schemes and theme settings in Pacelli. Use this skill when changing existing palette colours, adding a new colour scheme option, adjusting shared colours (backgrounds, text, semantic), modifying the theme builder, or updating the Appearance screen.

## Project Location
Pacelli lives at the user's local path (typically `~/Developer/pacelli`). In Cowork sessions it is mounted at `/sessions/*/mnt/pacelli/`.

## Architecture Overview

The theming system has four layers:

```
┌─────────────────────────────────────────────────┐
│  app.dart                                       │
│  Watches themePreferencesProvider               │
│  Passes scheme to AppTheme.lightThemeFor/darkFor│
├─────────────────────────────────────────────────┤
│  theme_preferences.dart                         │
│  Riverpod StateNotifier + SharedPreferences     │
│  Persists: theme_mode + color_scheme keys       │
├─────────────────────────────────────────────────┤
│  app_theme.dart                                 │
│  _buildTheme() — takes primary, accent, bg,     │
│  surface, text colours → produces ThemeData     │
├─────────────────────────────────────────────────┤
│  color_schemes.dart                             │
│  AppColorScheme enum + SchemeColors per scheme  │
│  SharedColors (bg, text, semantic — shared)     │
└─────────────────────────────────────────────────┘
```

## Key Files

| Concern | File |
|---------|------|
| Scheme enum + palette definitions | `lib/config/theme/color_schemes.dart` |
| Riverpod provider + SharedPreferences persistence | `lib/config/theme/theme_preferences.dart` |
| Theme builder (ThemeData factory) | `lib/config/theme/app_theme.dart` |
| Legacy colour constants (backward compat) | `lib/config/theme/app_colors.dart` |
| Root widget (watches provider) | `lib/app.dart` |
| Appearance settings screen (UI) | `lib/features/settings/presentation/screens/appearance_screen.dart` |
| Route definition | `lib/config/routes/app_router.dart` (AppRoutes.appearance) |
| l10n keys | `lib/l10n/app_en.arb`, `app_es.arb`, `app_it.arb` (search `appearance`) |

## Current Schemes

| Enum value | Name | Primary (light) | Primary (dark) | Accent (light) | Accent (dark) |
|------------|------|------------------|----------------|----------------|---------------|
| `pacelli` | Pacelli | `#7EA87E` sage green | `#6BA3A0` muted teal | `#CF7B5F` terracotta | `#D4A06A` soft amber |
| `claude` | Claude | `#8B6CC1` warm purple | `#A78BDB` violet | `#D4785B` warm coral | `#E8A87C` soft peach |
| `gemini` | Gemini | `#4A86C8` ocean blue | `#6BA3E0` sky blue | `#E07A5F` coral | `#EDA07A` warm salmon |

## How to: Change an Existing Scheme's Colours

1. Open `lib/config/theme/color_schemes.dart`
2. Find the scheme in `schemeColorMap`
3. Update the hex `Color(0xFFxxxxxx)` values for any of: `primaryLight`, `primaryDark`, `accentLight`, `accentDark`
4. No other files need changing — the theme builder picks up colours automatically
5. Hot-reload to preview

### Colour choice guidelines
- **primaryLight**: The main brand colour in light mode. Used for AppBar tint, selected nav items, buttons, links, input focus borders. Should have good contrast on white surfaces.
- **primaryDark**: Same role in dark mode. Typically a lighter/more saturated variant of primaryLight so it reads well on dark backgrounds.
- **accentLight**: Secondary colour. Used for FAB, secondary buttons, decorative accents. Should complement but contrast with the primary.
- **accentDark**: Same role in dark mode.
- Aim for WCAG AA contrast (4.5:1 for text, 3:1 for large text/UI) against the corresponding background (`SharedColors.backgroundLight` = `#F8F5F0`, `SharedColors.backgroundDark` = `#1A1A1A`).

## How to: Add a New Colour Scheme

This is a **6-file, 3-ARB** change. Follow this exact checklist:

### Step 1: Define the palette — `color_schemes.dart`
- [ ] Add a new value to the `AppColorScheme` enum (e.g. `sunset`)
- [ ] Add a `SchemeColors` entry in `schemeColorMap` with 4 colours (primaryLight, primaryDark, accentLight, accentDark)

### Step 2: Persistence — `theme_preferences.dart`
- [ ] Add a `case` to `_parseColorScheme()` for the new enum name string (e.g. `'sunset'`)
- [ ] Add a `case` to `_colorSchemeToString()` for the new enum value

### Step 3: l10n keys — all 3 ARB files
Add two new keys per locale:
- [ ] `app_en.arb`: `"appearanceScheme{Name}": "Display Name"` and `"appearanceScheme{Name}Desc": "Short colour description"`
- [ ] `app_es.arb`: Spanish translations for both keys
- [ ] `app_it.arb`: Italian translations for both keys

### Step 4: Appearance screen — `appearance_screen.dart`
- [ ] Add `case AppColorScheme.{name}:` to `_schemeName()` returning the l10n name key
- [ ] Add `case AppColorScheme.{name}:` to `_schemeDesc()` returning the l10n description key
- [ ] The colour cards auto-generate from `AppColorScheme.values` — no other changes needed

### Step 5: Regenerate & test
```bash
cd ~/Developer/pacelli
flutter gen-l10n
flutter run
```
- [ ] Verify the new scheme appears in the Appearance screen
- [ ] Select it — confirm colours apply to the entire app (AppBar, buttons, nav, cards)
- [ ] Toggle Light/Dark — confirm both mode variants look correct
- [ ] Kill and relaunch the app — confirm the selection persists via SharedPreferences

### Step 6: (Optional) Update this skill
- [ ] Add the new scheme to the "Current Schemes" table above

## How to: Remove a Colour Scheme

Reverse of adding: remove the enum value, remove the `schemeColorMap` entry, remove the persistence cases, remove the l10n keys (all 3 ARBs), remove the `_schemeName`/`_schemeDesc` cases. If the removed scheme was the user's saved preference, `_parseColorScheme` will fall through to the `default:` case which returns `AppColorScheme.pacelli`.

## How to: Change Shared Colours (backgrounds, text, semantic)

Shared colours live in `SharedColors` in `color_schemes.dart` and apply to ALL schemes:

| Colour | Light | Dark | Used for |
|--------|-------|------|----------|
| background | `#F8F5F0` warm off-white | `#1A1A1A` near-black | Scaffold background |
| surface | `#FFFFFF` white | `#242424` dark grey | Cards, inputs, nav bar |
| textPrimary | `#2D2D2D` | `#E8E8E8` | Headlines, body text |
| textSecondary | `#6B6B6B` | `#9E9E9E` | Subtitles, hints |
| success | `#6BAF6B` | same | Success states |
| warning | `#D4A44A` | same | Warning states |
| error | `#CF6B6B` | same | Error states, destructive actions |
| info | `#6B9ECF` | same | Info badges |

To change any of these, edit the static const in `SharedColors`. These propagate through `AppTheme._buildTheme()` into the ThemeData.

## How to: Modify the Theme Builder

`AppTheme._buildTheme()` in `app_theme.dart` is where colours become a Flutter `ThemeData`. It configures:

- `ColorScheme` (light/dark)
- `scaffoldBackgroundColor`
- `TextTheme` (Plus Jakarta Sans via Google Fonts)
- `AppBarTheme`
- `ElevatedButtonTheme`, `OutlinedButtonTheme`
- `InputDecorationTheme`
- `CardTheme`
- `FloatingActionButtonTheme`
- `BottomNavigationBarTheme`

When adding new themed widgets (e.g. `ChipTheme`, `DialogTheme`), add them inside `_buildTheme()` using the same `primary`, `accent`, `surface`, `textPrimary` etc. parameters.

## Backward Compatibility

`app_colors.dart` still exports static colour constants (`AppColors.primary`, `AppColors.success`, etc.) for any code that references them directly (e.g. hardcoded `AppColors.success` in privacy screen badges). These always return Pacelli-scheme values. Over time, migrate these usages to `Theme.of(context).colorScheme` or `context.colorScheme` for full dynamic theming.

To find remaining hardcoded colour references:
```bash
grep -rn 'AppColors\.' lib/ --include='*.dart' | grep -v 'app_colors.dart' | grep -v 'app_theme.dart'
```
Over time these should be migrated. As of March 2026, there are approximately 10-15 remaining `AppColors` references outside the theme files, mostly in `privacy_encryption_screen.dart` and `attachment_picker.dart`.

## When to Use This Skill

| Trigger | What to do |
|---------|------------|
| "Change the green to a different shade" | Modify existing scheme in `color_schemes.dart` |
| "Add a new colour theme called X" | Full 6-file checklist above |
| "Remove the Gemini theme" | Reverse removal checklist |
| "Make the dark mode background darker" | Edit `SharedColors.backgroundDark` |
| "The buttons should use the accent colour" | Modify `_buildTheme()` in `app_theme.dart` |
| "Add a ChipTheme that follows the scheme" | Add to `_buildTheme()` |
| "Migrate hardcoded AppColors references" | Use the grep command, replace with context.colorScheme |
