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
    final pair = await _getAppleCredential();
    if (pair == null) return null;

    final userCredential = await _auth.signInWithCredential(pair.credential);
    final user = userCredential.user;

    // Apple only returns the name on the first authorisation. Persist it now.
    final givenName = pair.appleCredential.givenName;
    final familyName = pair.appleCredential.familyName;
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

  /// Re-authenticates [user] with a fresh Apple credential. Required before
  /// sensitive operations like `user.delete()` (used by the burn flow).
  ///
  /// Returns `true` on success, `false` if the user cancelled the SIWA sheet.
  /// Throws on any other failure (network, configuration, credential mismatch).
  Future<bool> reauthenticate(User user) async {
    final pair = await _getAppleCredential();
    if (pair == null) return false;
    await user.reauthenticateWithCredential(pair.credential);
    return true;
  }

  /// Drives the Apple Sign-In sheet and packages the result as a Firebase
  /// OAuth credential ready for [signIn] or [reauthenticate].
  ///
  /// Returns `null` if the user cancelled the sheet. Throws on any other
  /// SIWA failure.
  ///
  /// firebase_auth iOS bridge silently rejects credentials that only have
  /// idToken + rawNonce — the authorizationCode must also be passed via the
  /// accessToken field. Diagnosed 2026-04-30 by replaying captured JWTs
  /// directly against Firebase's signInWithIdp REST endpoint, which accepted
  /// them, proving the issue was client-side serialization, not server.
  Future<_AppleCredentialPair?> _getAppleCredential() async {
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

    final credential = OAuthProvider('apple.com').credential(
      idToken: idToken,
      rawNonce: rawNonce,
      accessToken: appleCredential.authorizationCode,
    );
    return _AppleCredentialPair(appleCredential, credential);
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

/// Bundles the raw Apple credential (for name extraction) with the Firebase
/// OAuth credential (for signIn / reauthenticate).
class _AppleCredentialPair {
  _AppleCredentialPair(this.appleCredential, this.credential);
  final AuthorizationCredentialAppleID appleCredential;
  final OAuthCredential credential;
}
