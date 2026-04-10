import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../../household/data/household_service.dart';

/// Splash screen — shown briefly on app launch.
///
/// Checks whether the user is already logged in and redirects:
/// - Logged in → Home screen (or storage setup if not configured)
/// - Not logged in → Login screen
///
/// Also listens for auth state changes (e.g., after Google Sign-In
/// redirect) and navigates accordingly.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final StreamSubscription<User?> _authSubscription;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    // Listen for Firebase auth state changes (login, logout, token refresh).
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (!mounted || _hasNavigated) return;

      if (user != null) {
        // Run one-time migration for deterministic member doc IDs.
        unawaited(HouseholdService.migrateMemberDocIds());
        // Accept any pending household invite for this user.
        unawaited(HouseholdService.checkAndAcceptInvite());

        // User is signed in — check storage backend before going home.
        final prefs = await SharedPreferences.getInstance();
        final backend = prefs.getString('storage_backend');
        if (!mounted || _hasNavigated) return;
        if (backend == null) {
          _hasNavigated = true;
          context.go(AppRoutes.storageSetup);
        } else {
          _hasNavigated = true;
          context.go(AppRoutes.home);
        }
      } else {
        _hasNavigated = true;
        context.go(AppRoutes.login);
      }
    });

    // Also check immediately after a brief delay.
    _checkAuthAndRedirect();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _checkAuthAndRedirect() async {
    // Small delay so the splash screen is visible briefly.
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted || _hasNavigated) return;

    // Check if a user session exists.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Accept any pending household invite for this user.
      unawaited(HouseholdService.checkAndAcceptInvite());

      // Check if storage backend is configured.
      final prefs = await SharedPreferences.getInstance();
      final backend = prefs.getString('storage_backend');
      if (!mounted || _hasNavigated) return;

      if (backend == null) {
        // Not configured yet — send to storage selection.
        _hasNavigated = true;
        context.go(AppRoutes.storageSetup);
      } else {
        _hasNavigated = true;
        context.go(AppRoutes.home);
      }
    } else {
      _hasNavigated = true;
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App icon placeholder — replace with actual logo later
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.home_rounded,
                size: 56,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.l10n.authAppName,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.authTagline,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
