import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../core/data/data_repository_provider.dart';
import '../../../../core/data/local_database.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/extensions.dart';

/// Full-screen fire animation shown while all user data is being deleted.
class BurnDataScreen extends ConsumerStatefulWidget {
  const BurnDataScreen({super.key});

  @override
  ConsumerState<BurnDataScreen> createState() => _BurnDataScreenState();
}

class _BurnDataScreenState extends ConsumerState<BurnDataScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fireController;
  late final AnimationController _textFadeController;
  late final AnimationController _particleController;

  String _statusText = '';
  bool _isComplete = false;
  bool _hasFailed = false;
  bool _burnStarted = false;

  @override
  void initState() {
    super.initState();

    // Fire pulse animation — loops continuously.
    _fireController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    // Text fade-in animation.
    _textFadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    // Particle animation — loops for floating embers.
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_burnStarted) {
      _burnStarted = true;
      _statusText = context.l10n.burnStatusBurning;
      WidgetsBinding.instance.addPostFrameCallback((_) => _burnEverything());
    }
  }

  @override
  void dispose() {
    _fireController.dispose();
    _textFadeController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  /// Shows a password prompt for email/password users. Returns the password,
  /// or null if the user cancels.
  Future<String?> _promptForPassword() async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.lock_outline_rounded,
          size: 40,
          color: Colors.red.shade600,
        ),
        title: Text(l10n.burnPasswordTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.burnPasswordMessage),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.burnPasswordHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: Text(l10n.burnPasswordConfirm),
          ),
        ],
      ),
    );
    // Dispose after a frame so the dialog exit animation finishes.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    return result;
  }

  Future<void> _burnEverything() async {
    final l10n = context.l10n;
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final userId = currentUser?.uid;
      debugPrint('[BURN] Starting burn for userId=$userId');

      // For email/password users, prompt for password upfront so we can
      // re-authenticate later for account deletion.
      String? emailPassword;
      if (currentUser != null) {
        final providerIds =
            currentUser.providerData.map((p) => p.providerId).toSet();
        if (!providerIds.contains('google.com')) {
          emailPassword = await _promptForPassword();
          if (emailPassword == null || !mounted) return; // User cancelled.
        }
      }

      // ── Step 0: Cancel all pending notifications ──
      try {
        await ref.read(notificationServiceProvider).cancelAll();
        debugPrint('[BURN] ✓ All notifications cancelled');
      } catch (e) {
        debugPrint('[BURN] Notification cancel: $e');
      }

      // ── Step 1: Wipe user data via the active DataRepository ──
      // Must happen FIRST — we still have a valid auth token.
      // If this fails, do NOT proceed to sign out — the data wasn't deleted.
      _updateStatus(l10n.burnStatusDestroying);
      await Future.delayed(const Duration(milliseconds: 600));
      final repo = ref.read(dataRepositoryProvider);
      if (userId != null) {
        try {
          await repo.wipeAllData(userId);
          debugPrint('[BURN] ✓ wipeAllData completed');
        } catch (e) {
          debugPrint('[BURN] ✗ wipeAllData failed: $e');
          _updateStatus(l10n.burnStatusError);
          if (mounted) setState(() => _hasFailed = true);
          return; // Do NOT proceed — data was not deleted.
        }
      }

      // ── Step 2: Delete local SQLite database file ──
      // Even if backend is Firebase — user might have used local before.
      _updateStatus(l10n.burnStatusClearingLocal);
      await Future.delayed(const Duration(milliseconds: 600));
      try {
        await LocalDatabase.deleteDatabase();
        debugPrint('[BURN] ✓ Local DB deleted');
      } catch (e) {
        debugPrint('[BURN] Local DB delete: $e (may not exist)');
      }
      ref.read(localDatabaseProvider.notifier).state = null;

      // ── Step 3: Clear encryption keys from secure storage ──
      _updateStatus(l10n.burnStatusClearingKeys);
      await Future.delayed(const Duration(milliseconds: 600));
      try {
        const secureStorage = FlutterSecureStorage();
        await secureStorage.deleteAll();
        debugPrint('[BURN] ✓ Secure storage (encryption keys) cleared');
      } catch (e) {
        debugPrint('[BURN] ✗ Secure storage clear: $e');
      }

      // ── Step 4: Delete Firebase Auth account, then sign out ──
      _updateStatus(l10n.burnStatusSigningOut);
      await Future.delayed(const Duration(milliseconds: 600));

      // Delete the Firebase Auth account (must happen while still authenticated).
      // Firebase requires a recent credential for account deletion.
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final providerIds =
              user.providerData.map((p) => p.providerId).toSet();
          if (providerIds.contains('google.com')) {
            // Re-authenticate with Google before deleting.
            final googleUser = await GoogleSignIn().signIn();
            if (googleUser != null) {
              final googleAuth = await googleUser.authentication;
              final credential = GoogleAuthProvider.credential(
                accessToken: googleAuth.accessToken,
                idToken: googleAuth.idToken,
              );
              await user.reauthenticateWithCredential(credential);
            }
          } else if (emailPassword != null && user.email != null) {
            // Re-authenticate with email/password.
            final credential = EmailAuthProvider.credential(
              email: user.email!,
              password: emailPassword,
            );
            await user.reauthenticateWithCredential(credential);
          }
          await user.delete();
          debugPrint('[BURN] ✓ Firebase Auth account deleted');
        } catch (e) {
          debugPrint('[BURN] ✗ Auth account delete failed: $e');
          if (e.toString().contains('wrong-password') ||
              e.toString().contains('invalid-credential')) {
            _updateStatus(l10n.burnPasswordError);
            if (mounted) setState(() => _hasFailed = true);
            return;
          }
          // Other errors — account stays but all data is gone.
        }
      }

      // Firebase sign out.
      try {
        await FirebaseAuth.instance.signOut();
        debugPrint('[BURN] ✓ Firebase signOut completed');
      } catch (e) {
        debugPrint('[BURN] ✗ Firebase signOut: $e');
      }

      // Google Sign-In: clear cached account + revoke access.
      try {
        final googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();
        await googleSignIn.disconnect();
        debugPrint('[BURN] ✓ Google sign-out + disconnect');
      } catch (e) {
        debugPrint('[BURN] Google sign-out: $e');
      }

      // ── Step 5: Clear SharedPreferences (belt & suspenders) ──
      // Catches any leftover tokens, backend choice, and all other app
      // preferences.
      _updateStatus(l10n.burnStatusRemovingSettings);
      await Future.delayed(const Duration(milliseconds: 600));
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        debugPrint('[BURN] ✓ SharedPreferences cleared');
      } catch (e) {
        debugPrint('[BURN] ✗ SharedPreferences clear: $e');
      }

      // ── Step 6: Done ──
      _updateStatus(l10n.burnStatusComplete);
      debugPrint('[BURN] ══ Burn complete ══');
      setState(() => _isComplete = true);

      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;
      context.go(AppRoutes.login);
    } catch (e) {
      debugPrint('[BURN] Fatal error: $e');
      _updateStatus(l10n.burnStatusError);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) context.go(AppRoutes.login);
    }
  }

  void _updateStatus(String text) {
    if (!mounted) return;
    setState(() => _statusText = text);
    // Re-trigger text fade animation.
    _textFadeController.reset();
    _textFadeController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Floating ember particles.
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, _) => CustomPaint(
              painter: _EmberPainter(_particleController.value),
              size: MediaQuery.of(context).size,
            ),
          ),

          // Main content — centred fire icon + status text.
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulsing fire icon.
                AnimatedBuilder(
                  animation: _fireController,
                  builder: (context, child) {
                    final scale = 1.0 + (_fireController.value * 0.15);
                    final glow = 0.3 + (_fireController.value * 0.4);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withValues(alpha: glow),
                              blurRadius: 60,
                              spreadRadius: 20,
                            ),
                            BoxShadow(
                              color: Colors.red.withValues(alpha: glow * 0.6),
                              blurRadius: 100,
                              spreadRadius: 40,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.local_fire_department_rounded,
                          size: 100,
                          color: Color.lerp(
                            Colors.orange,
                            Colors.red.shade400,
                            _fireController.value,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 40),

                // Status text with fade.
                FadeTransition(
                  opacity: _textFadeController,
                  child: Text(
                    _statusText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                if (_hasFailed) ...[
                  const SizedBox(height: 8),
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red,
                    size: 28,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _hasFailed = false);
                      _burnEverything();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(context.l10n.commonRetry),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade300,
                      side: BorderSide(color: Colors.orange.shade300),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.settings),
                    child: Text(
                      context.l10n.commonCancel,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ),
                ],

                if (_isComplete) ...[
                  const SizedBox(height: 8),
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Colors.green,
                    size: 28,
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      context.l10n.settingsBurnDriveWarning,
                      style: TextStyle(
                        color: Colors.orange.shade300,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter that draws floating ember particles rising upward.
class _EmberPainter extends CustomPainter {
  final double progress;
  static final _random = Random(42); // Fixed seed for consistent pattern.
  static final _embers = List.generate(30, (_) => _Ember.random(_random));

  _EmberPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final ember in _embers) {
      final y = size.height -
          ((progress + ember.offset) % 1.0) * (size.height + 40);
      final x = ember.x * size.width +
          sin((progress + ember.offset) * pi * 4) * ember.drift;
      final opacity = (1.0 - ((progress + ember.offset) % 1.0)) * ember.alpha;

      final paint = Paint()
        ..color = Color.lerp(
          Colors.orange,
          Colors.red.shade700,
          ember.colorMix,
        )!
            .withValues(alpha: opacity.clamp(0.0, 1.0));

      canvas.drawCircle(Offset(x, y), ember.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EmberPainter oldDelegate) => true;
}

/// Represents a single ember particle.
class _Ember {
  final double x; // Horizontal position (0–1).
  final double offset; // Phase offset (0–1).
  final double size; // Radius in pixels.
  final double drift; // Horizontal sway amplitude.
  final double alpha; // Max opacity.
  final double colorMix; // 0 = orange, 1 = red.

  const _Ember({
    required this.x,
    required this.offset,
    required this.size,
    required this.drift,
    required this.alpha,
    required this.colorMix,
  });

  factory _Ember.random(Random rng) => _Ember(
        x: rng.nextDouble(),
        offset: rng.nextDouble(),
        size: 1.5 + rng.nextDouble() * 3,
        drift: 10 + rng.nextDouble() * 20,
        alpha: 0.3 + rng.nextDouble() * 0.5,
        colorMix: rng.nextDouble(),
      );
}
