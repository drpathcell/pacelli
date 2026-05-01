import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../config/constants/app_constants.dart';
import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/apple_sign_in_service.dart';
import '../utils/post_auth_nav.dart';
import '../widgets/apple_sign_in_button.dart';

/// Login screen — Google Sign-In + email/password authentication.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Google Sign-In ──────────────────────────────────────────

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);

    try {
      final googleSignIn = GoogleSignIn(
        // iOS client ID is auto-read from GoogleService-Info.plist.
        serverClientId: AppConstants.googleWebClientId,
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the sign-in
        if (mounted) setState(() => _isGoogleLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw Exception('No ID token received from Google');
      }

      // Sign in to Firebase with the Google credential.
      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      if (mounted) {
        await goAfterAuth(context);
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(
          context.l10n.authGoogleSignInFailed,
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  // ── Apple Sign-In ───────────────────────────────────────────

  Future<void> _handleAppleSignIn() async {
    setState(() => _isAppleLoading = true);
    try {
      final user = await AppleSignInService().signIn();
      if (user == null) {
        if (mounted) setState(() => _isAppleLoading = false);
        return;
      }
      if (mounted) await goAfterAuth(context);
    } catch (e) {
      if (mounted) {
        context.showSnackBar(
          context.l10n.authAppleSignInFailed,
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isAppleLoading = false);
    }
  }

  // ── Email/Password Sign-In ──────────────────────────────────

  Future<void> _handleEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        await goAfterAuth(context);
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(
          context.l10n.authLoginFailed,
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),

              // Header
              Text(
                context.l10n.authWelcomeBack,
                style: context.textTheme.displayLarge,
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.authSignInToHousehold,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 40),

              // ── Apple Sign-In Button (iOS/macOS only) ───────
              if (AppleSignInButton.isAvailable) ...[
                AppleSignInButton(
                  isLoading: _isAppleLoading,
                  onPressed: _handleAppleSignIn,
                ),
                const SizedBox(height: 12),
              ],

              // ── Google Sign-In Button ───────────────────────
              _GoogleSignInButton(
                isLoading: _isGoogleLoading,
                onPressed: _handleGoogleSignIn,
              ),
              const SizedBox(height: 24),

              // ── Divider ─────────────────────────────────────
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      context.l10n.authOrSignInWithEmail,
                      style: context.textTheme.bodyMedium,
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
              const SizedBox(height: 24),

              // ── Email/Password Form ─────────────────────────
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Email field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: context.l10n.authEmail,
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return context.l10n.authEnterEmail;
                        }
                        if (!value.trim().isValidEmail) {
                          return context.l10n.authEnterValidEmail;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: context.l10n.authPassword,
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(
                                () => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return context.l10n.authEnterPassword;
                        }
                        if (value.length < 6) {
                          return context.l10n.authPasswordMinLength;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    // Forgot password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () async {
                          if (_emailController.text.trim().isEmpty) {
                            context.showSnackBar(context.l10n.authEnterEmailFirst, isError: true);
                            return;
                          }
                          final l10n = context.l10n;
                          final messenger = ScaffoldMessenger.of(context);
                          final primaryColor = Theme.of(context).colorScheme.primary;
                          final errorColor = Theme.of(context).colorScheme.error;
                          try {
                            await FirebaseAuth.instance.sendPasswordResetEmail(
                              email: _emailController.text.trim(),
                            );
                            if (mounted) {
                              messenger.showSnackBar(SnackBar(
                                content: Text(l10n.authPasswordResetSent),
                                backgroundColor: primaryColor,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                margin: const EdgeInsets.all(16),
                              ));
                            }
                          } catch (e) {
                            if (mounted) {
                              messenger.showSnackBar(SnackBar(
                                content: Text(l10n.commonError(e.toString())),
                                backgroundColor: errorColor,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                margin: const EdgeInsets.all(16),
                              ));
                            }
                          }
                        },
                        child: Text(context.l10n.authForgotPassword),
                      ),
                    ),
                    const SizedBox(height: 16),


                    // Login button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleEmailLogin,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(context.l10n.authSignIn),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Signup link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    context.l10n.authNoAccount,
                    style: context.textTheme.bodyMedium,
                  ),
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.signup),
                    child: Text(
                      context.l10n.authSignUp,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A styled Google Sign-In button matching Google's brand guidelines.
class _GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _GoogleSignInButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimaryLight,
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Google "G" logo using text (avoids needing an image asset)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(
                    child: Text(
                      'G',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4285F4), // Google blue
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  context.l10n.authContinueWithGoogle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
    );
  }
}
