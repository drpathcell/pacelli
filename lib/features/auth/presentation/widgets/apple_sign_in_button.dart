import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../../core/utils/extensions.dart';

/// Apple-branded sign-in button. iOS/macOS only — hides itself elsewhere
/// because Apple's review will reject SIWA on Android, and there's no native
/// Apple SDK on web for our use case.
///
/// Required by App Review guideline 4.8 whenever any third-party login
/// (Google, Facebook, etc.) is offered. MUST appear at least as prominently
/// as the other social login buttons.
class AppleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const AppleSignInButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
  });

  /// Whether the current platform should show this button.
  static bool get isAvailable {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isMacOS;
  }

  @override
  Widget build(BuildContext context) {
    if (!isAvailable) return const SizedBox.shrink();

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.apple, size: 22, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  context.l10n.authContinueWithApple,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
    );
  }
}
