import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pacelli/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/routes/app_router.dart';
import 'config/theme/app_theme.dart';
import 'config/theme/theme_preferences.dart';

/// The root widget of the Pacelli app.
///
/// Sets up theming (light + dark), routing via GoRouter,
/// localisation, and any top-level configuration.
class PacelliApp extends ConsumerWidget {
  const PacelliApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themePref = ref.watch(themePreferencesProvider);

    return MaterialApp.router(
      title: 'Pacelli',
      debugShowCheckedModeBanner: false,

      // Localisation
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

      // Theme — driven by user preference
      theme: AppTheme.lightThemeFor(themePref.colorScheme),
      darkTheme: AppTheme.darkThemeFor(themePref.colorScheme),
      themeMode: themePref.themeMode,

      // Routing
      routerConfig: router,
    );
  }
}
