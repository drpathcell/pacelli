import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/routes/app_router.dart';
import 'config/theme/app_theme.dart';

/// The root widget of the Pacelli app.
///
/// Sets up theming (light + dark), routing via GoRouter,
/// and any top-level configuration.
class PacelliApp extends ConsumerWidget {
  const PacelliApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Pacelli',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Follows system setting by default

      // Routing
      routerConfig: router,
    );
  }
}
