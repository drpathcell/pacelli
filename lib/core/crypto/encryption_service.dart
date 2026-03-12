import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// AES-256-CBC end-to-end encryption service for Pacelli.
///
/// Encrypts human-readable content fields (titles, descriptions, names)
/// before they leave the device. Only household members who hold the
/// symmetric household key can decrypt.
///
/// **What is encrypted**: task titles, descriptions, subtask titles,
/// checklist titles/items, plan titles/entries/labels, category names,
/// household name, display name.
///
/// **What is NOT encrypted**: IDs, status, priority, timestamps,
/// booleans, sort orders, icons, colors — structural metadata needed
/// for Firestore queries.
class EncryptionService {
  /// Encrypts [plaintext] using AES-256-CBC with the given [key].
  /// Returns a Base64 string containing IV + ciphertext.
  ///
  /// Each call generates a fresh random IV for semantic security
  /// (identical plaintexts produce different ciphertexts).
  static String encrypt(String plaintext, String key) {
    final keyBytes = _keyFromString(key);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(keyBytes, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);

    // Prepend the IV so we can extract it on decrypt.
    // Format: base64(iv_bytes + ciphertext_bytes)
    final combined = Uint8List.fromList(iv.bytes + encrypted.bytes);
    return base64Encode(combined);
  }

  /// Decrypts a Base64 string produced by [encrypt] using the given [key].
  /// Returns the original plaintext.
  static String decrypt(String ciphertext, String key) {
    final keyBytes = _keyFromString(key);
    final combined = base64Decode(ciphertext);

    // First 16 bytes = IV, rest = ciphertext
    final iv = enc.IV(Uint8List.fromList(combined.sublist(0, 16)));
    final encryptedBytes = combined.sublist(16);
    final encrypted = enc.Encrypted(Uint8List.fromList(encryptedBytes));

    final encrypter = enc.Encrypter(enc.AES(keyBytes, mode: enc.AESMode.cbc));
    return encrypter.decrypt(encrypted, iv: iv);
  }

  /// Encrypts a nullable field. Returns null if input is null or empty.
  static String? encryptNullable(String? plaintext, String key) {
    if (plaintext == null || plaintext.isEmpty) return plaintext;
    return encrypt(plaintext, key);
  }

  /// Decrypts a nullable field. Returns null if input is null or empty.
  ///
  /// On decryption failure (wrong key, corrupt data, or unencrypted plaintext),
  /// logs a warning and returns `'[encrypted]'` rather than leaking ciphertext
  /// to the UI.
  static String? decryptNullable(String? ciphertext, String key) {
    if (ciphertext == null || ciphertext.isEmpty) return ciphertext;
    try {
      return decrypt(ciphertext, key);
    } catch (e) {
      // Don't leak raw ciphertext to the UI — show a safe placeholder.
      assert(() {
        // Only print in debug mode.
        // ignore: avoid_print
        print('[EncryptionService] decryptNullable failed: $e');
        return true;
      }());
      return '[encrypted]';
    }
  }

  // ── Key management helpers ──

  /// Generates a new random 256-bit key for a household.
  /// Returns the key as a 64-character hex string.
  static String generateHouseholdKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Legacy v1 key derivation (raw HMAC) — kept for migration only.
  static String _deriveUserKeyV1(String uid) {
    final salt = utf8.encode('pacelli_e2e_key_derivation_v1');
    final hmacSha256 = Hmac(sha256, salt);
    final digest = hmacSha256.convert(utf8.encode(uid));
    return digest.toString();
  }

  /// Derives a 256-bit user-specific key from their Firebase UID using HKDF.
  ///
  /// HKDF (HMAC-based Key Derivation Function) provides proper key stretching
  /// with extract-then-expand pattern per RFC 5869. Used only to wrap/unwrap
  /// the household key, NOT to encrypt user data directly.
  static String deriveUserKey(String uid) {
    // HKDF-Extract: create a pseudorandom key from uid + salt
    final salt = utf8.encode('pacelli_hkdf_salt_v2');
    final ikm = utf8.encode(uid);
    final prk = Hmac(sha256, salt).convert(ikm);

    // HKDF-Expand: derive output key material from PRK + info
    final info = utf8.encode('pacelli_e2e_user_key_v2');
    final expandInput = [...info, 0x01]; // info || counter byte
    final okm = Hmac(sha256, prk.bytes).convert(expandInput);

    return okm.toString(); // 64-char hex string = 256-bit key
  }

  /// Attempts to decrypt with v2 (HKDF) key first, falls back to v1 (HMAC).
  ///
  /// Used during key migration to support existing encrypted household keys.
  static String decryptKeyWithMigration(String encryptedKey, String uid) {
    // Try v2 first
    try {
      final v2Key = deriveUserKey(uid);
      return decrypt(encryptedKey, v2Key);
    } catch (_) {}

    // Fall back to v1
    final v1Key = _deriveUserKeyV1(uid);
    return decrypt(encryptedKey, v1Key);
  }

  /// Encrypts [householdKey] using [userKey] for secure storage.
  /// Used when storing the household key in Firestore per-user.
  static String encryptKeyForUser(String householdKey, String userKey) {
    return encrypt(householdKey, userKey);
  }

  /// Decrypts a stored household key using the user's derived key.
  static String decryptKeyForUser(String encryptedKey, String userKey) {
    return decrypt(encryptedKey, userKey);
  }

  // ── Internal ──

  /// Converts a 64-character hex key string to an AES Key object.
  static enc.Key _keyFromString(String hexKey) {
    final bytes = <int>[];
    for (var i = 0; i < hexKey.length; i += 2) {
      bytes.add(int.parse(hexKey.substring(i, i + 2), radix: 16));
    }
    return enc.Key(Uint8List.fromList(bytes));
  }
}
