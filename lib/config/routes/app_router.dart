import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/household/presentation/screens/create_household_screen.dart';
import '../../features/household/presentation/screens/household_screen.dart';
import '../../features/tasks/presentation/screens/create_task_screen.dart';
import '../../features/tasks/presentation/screens/home_screen.dart';
import '../../features/tasks/presentation/screens/task_detail_screen.dart';
import '../../features/tasks/presentation/screens/tasks_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../shared/widgets/main_shell.dart';

/// Route path constants — use these instead of hardcoded strings.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/home';
  static const String tasks = '/tasks';
  static const String settings = '/settings';
  static const String createHousehold = '/create-household';
  static const String household = '/household';
}

/// Key for the shell navigator (bottom nav tabs).
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// GoRouter provider — accessible throughout the app via Riverpod.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      // Splash screen — checks auth status and redirects
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // Authentication routes (no bottom nav)
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),

      // Create household (no bottom nav — modal-style)
      GoRoute(
        path: AppRoutes.createHousehold,
        builder: (context, state) => const CreateHouseholdScreen(),
      ),

      // Household management
      GoRoute(
        path: AppRoutes.household,
        builder: (context, state) => const HouseholdScreen(),
      ),

      // Create task (full-screen, no bottom nav)
      GoRoute(
        path: '${AppRoutes.tasks}/create',
        builder: (context, state) {
          final householdId = state.extra as String;
          return CreateTaskScreen(householdId: householdId);
        },
      ),

      // Task detail (full-screen, no bottom nav)
      GoRoute(
        path: '${AppRoutes.tasks}/:taskId',
        builder: (context, state) {
          final taskId = state.pathParameters['taskId']!;
          return TaskDetailScreen(taskId: taskId);
        },
      ),

      // ── Main app with bottom navigation ──────────────────────
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          // Determine the current tab index based on the route
          int currentIndex = 0;
          final location = state.uri.path;
          if (location == AppRoutes.tasks) {
            currentIndex = 1;
          } else if (location == AppRoutes.settings) {
            currentIndex = 2;
          }

          return MainShell(
            currentIndex: currentIndex,
            onTabChanged: (index) {
              switch (index) {
                case 0:
                  context.go(AppRoutes.home);
                  break;
                case 1:
                  context.go(AppRoutes.tasks);
                  break;
                case 2:
                  context.go(AppRoutes.settings);
                  break;
              }
            },
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.tasks,
            builder: (context, state) => const TasksScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
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
