import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Wraps `sign_in_with_apple` so callers get a fully signed-in Firebase user.
///
/// Flow:
///   1. Generate a cryptographically random `rawNonce`.
///   2. Pass its SHA-256 hash to Apple (Apple signs that hash into the JWT).
///   3. Exchange the returned (idToken, rawNonce) for a Firebase OAuthCredential.
///   4. Sign in to FirebaseAuth.
///
/// The first sign-in is the only time Apple gives back the user's full name,
/// so we eagerly persist it to `currentUser.displayName`.
class AppleSignInService {
  AppleSignInService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// Returns the signed-in [User], or `null` if the user cancelled.
  /// Throws on any other failure (network, configuration, etc).
  Future<User?> signIn() async {
    final rawNonce = _generateNonce();
    final hashedNonce = _sha256(rawNonce);

    final AuthorizationCredentialAppleID appleCredential;
    try {
      appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return null;
      }
      rethrow;
    }

    final idToken = appleCredential.identityToken;
    if (idToken == null) {
      throw StateError('Apple did not return an identity token.');
    }

    final oauth = OAuthProvider('apple.com').credential(
      idToken: idToken,
      rawNonce: rawNonce,
    );

    final userCredential = await _auth.signInWithCredential(oauth);
    final user = userCredential.user;

    // Apple only returns the name on the first authorisation. Persist it now.
    final givenName = appleCredential.givenName;
    final familyName = appleCredential.familyName;
    if (user != null &&
        (user.displayName == null || user.displayName!.isEmpty) &&
        (givenName != null || familyName != null)) {
      final displayName = [givenName, familyName]
          .where((p) => p != null && p.isNotEmpty)
          .join(' ');
      if (displayName.isNotEmpty) {
        await user.updateDisplayName(displayName);
      }
    }

    return user;
  }

  String _generateNonce([int length = 32]) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
    final rng = Random.secure();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)])
        .join();
  }

  String _sha256(String input) =>
      sha256.convert(utf8.encode(input)).toString();
}
