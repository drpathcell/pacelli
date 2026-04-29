import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../config/constants/app_constants.dart';
import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/apple_sign_in_service.dart';
import '../widgets/apple_sign_in_button.dart';

/// Signup screen — Google Sign-In + email/password registration.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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

      // For first-time Apple users, persist the (now-known) display name
      // and create a profile doc — same shape as Google signup.
      const secureStorage = FlutterSecureStorage();
      final profileSnap = await FirebaseFirestore.instance
          .collection('profiles')
          .doc(user.uid)
          .get();
      if (!profileSnap.exists) {
        await secureStorage.write(
          key: 'profile_name_${user.uid}',
          value: user.displayName ?? '',
        );
        await FirebaseFirestore.instance
            .collection('profiles')
            .doc(user.uid)
            .set({
          'full_name': '', // Encrypted later, once household key exists
          'avatar_url': '',
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) context.go(AppRoutes.home);
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
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      // Create a profile doc in Firestore for new Google users.
      // Store the display name locally only — it will be encrypted with
      // the household key once the user creates/joins a household.
      final user = userCredential.user;
      if (user != null && userCredential.additionalUserInfo?.isNewUser == true) {
        const secureStorage = FlutterSecureStorage();
        await secureStorage.write(
          key: 'profile_name_${user.uid}',
          value: user.displayName ?? '',
        );

        await FirebaseFirestore.instance.collection('profiles').doc(user.uid).set({
          'full_name': '', // Empty until household key is available
          'avatar_url': user.photoURL ?? '',
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        context.go(AppRoutes.home);
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

  // ── Email/Password Sign-Up ──────────────────────────────────

  Future<void> _handleEmailSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Create the Firebase Auth account.
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Set the display name on the Auth profile.
      await userCredential.user?.updateDisplayName(
        _nameController.text.trim(),
      );

      // Store name locally — it will be encrypted with the household key
      // once the user creates/joins a household.
      final uid = userCredential.user?.uid;
      if (uid != null) {
        const secureStorage = FlutterSecureStorage();
        await secureStorage.write(
          key: 'profile_name_$uid',
          value: _nameController.text.trim(),
        );

        await FirebaseFirestore.instance.collection('profiles').doc(uid).set({
          'full_name': '', // Empty until household key is available
          'avatar_url': '',
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        context.showSnackBar(context.l10n.authAccountCreated);
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(
          context.l10n.authSignupFailed,
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
              const SizedBox(height: 40),

              // Back button
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => context.go(AppRoutes.login),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Text(
                context.l10n.authCreateAccount,
                style: context.textTheme.displayLarge,
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.authStartOrganising,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 32),

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
                      context.l10n.authOrSignUpWithEmail,
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
                    // Name field
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: context.l10n.authFullName,
                        prefixIcon: const Icon(Icons.person_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return context.l10n.authEnterName;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

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
                          return context.l10n.authEnterAPassword;
                        }
                        if (value.length < 8) {
                          return context.l10n.authPasswordMin8;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Confirm password field
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: context.l10n.authConfirmPassword,
                        prefixIcon: const Icon(Icons.lock_outlined),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return context.l10n.authPasswordsDoNotMatch;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Signup button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleEmailSignup,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(context.l10n.authCreateAccountButton),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Login link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    context.l10n.authAlreadyHaveAccount,
                    style: context.textTheme.bodyMedium,
                  ),
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.login),
                    child: Text(
                      context.l10n.authSignIn,
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
                        color: Color(0xFF4285F4),
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
