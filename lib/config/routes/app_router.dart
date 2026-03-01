import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/tasks/presentation/screens/home_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

/// Route path constants — use these instead of hardcoded strings.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/home';
  static const String settings = '/settings';
}

/// GoRouter provider — accessible throughout the app via Riverpod.
///
/// GoRouter handles declarative routing, deep linking, and
/// redirect logic (e.g., redirecting unauthenticated users to login).
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      // Splash screen — checks auth status and redirects
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // Authentication routes
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),

      // Main app routes
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],

    // Error page for unknown routes
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(
          'Page not found: ${state.uri}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    ),
  );
});
