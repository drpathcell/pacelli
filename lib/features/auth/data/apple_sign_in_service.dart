import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Wraps `sign_in_with_apple` so callers get a fully signed-in Firebase user.
///
/// Flow:
///   1. Generate a cryptographically random `rawNonce`.
///   2. Pass its SHA-256 hash to Apple (Apple signs that hash into the JWT).
///   3. Exchange the returned (idToken, rawNonce) for a Firebase OAuthCredential.
///   4. Sign in to FirebaseAuth.
///
/// **Display name persistence**
///
/// Apple only returns the user's name on the FIRST authorization for an App
/// ID. On every subsequent sign-in (re-grant after revoke, sign-out + sign-in,
/// etc) the name fields come back null. To prevent the user from becoming
/// "Hello, Friend" forever, we mirror the name across three layers on first
/// sign-in:
///
///   1. `FirebaseAuth.currentUser.displayName` (server-side, persistent)
///   2. Flutter secure storage at `profile_name_<uid>` (device-local, also
///      written by the signup flow before the encryption key exists)
///   3. The encrypted `profiles/{uid}.full_name` Firestore doc (after the
///      household is created — handled by `HouseholdService`, not here).
///
/// On every later sign-in, if FirebaseAuth's displayName is empty we hydrate
/// it from secure storage.
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
    if (user == null) return null;

    await _hydrateDisplayName(
      user,
      apple: pair.appleCredential,
    );
    return user;
  }

  /// Mirrors Apple's name across FirebaseAuth.displayName + secure storage,
  /// or hydrates displayName from secure storage if Apple didn't return one.
  Future<void> _hydrateDisplayName(
    User user, {
    required AuthorizationCredentialAppleID apple,
  }) async {
    const storage = FlutterSecureStorage();
    final secureKey = 'profile_name_${user.uid}';

    // Did Apple return a name this time? (Only on first authorization.)
    final givenName = apple.givenName;
    final familyName = apple.familyName;
    final fromApple = [givenName, familyName]
        .where((p) => p != null && p.isNotEmpty)
        .join(' ')
        .trim();

    if (fromApple.isNotEmpty) {
      // First sign-in path — persist everywhere we can reach.
      await user.updateDisplayName(fromApple);
      await storage.write(key: secureKey, value: fromApple);
      return;
    }

    // Re-sign-in path — Apple sent nothing. If FirebaseAuth still has a
    // displayName from a prior session, we're done. Otherwise try secure
    // storage as the last line of defence.
    final current = user.displayName?.trim() ?? '';
    if (current.isNotEmpty) return;

    final stored = (await storage.read(key: secureKey))?.trim();
    if (stored != null && stored.isNotEmpty) {
      await user.updateDisplayName(stored);
    }
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
