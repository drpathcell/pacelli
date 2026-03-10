import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'encryption_service.dart';

/// Manages per-household encryption keys.
///
/// Each household has a single AES-256 symmetric key. This key is stored
/// in Firestore encrypted individually for each household member (using a
/// key derived from their Firebase UID). The decrypted household key is
/// cached in memory for the duration of the session.
///
/// Flow:
///   1. User logs in → [loadHouseholdKey] fetches their encrypted key
///      from `household_keys`, decrypts it with their user key, caches it.
///   2. User creates a household → [createHouseholdKey] generates a fresh
///      key and stores it encrypted for the creator.
///   3. New member joins → [shareKeyWithMember] re-encrypts the household
///      key for the new member's UID.
class KeyManager {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FlutterSecureStorage _secureStorage;

  /// In-memory cache of the decrypted household key (hex string).
  /// Null until [loadHouseholdKey] succeeds.
  String? _cachedHouseholdKey;

  /// The household ID whose key is currently cached.
  String? _cachedHouseholdId;

  KeyManager({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FlutterSecureStorage? secureStorage,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Returns the decrypted household key, or null if not yet loaded.
  String? get householdKey => _cachedHouseholdKey;

  /// Whether a household key is currently available.
  bool get hasKey => _cachedHouseholdKey != null;

  /// Returns the current user's UID, or null if not signed in.
  String? get _uid => _auth.currentUser?.uid;

  // ═══════════════════════════════════════════════════════════════════
  //  LOAD — Retrieve & decrypt the key for a household
  // ═══════════════════════════════════════════════════════════════════

  /// Loads the household key for [householdId] from Firestore.
  ///
  /// 1. Derives the user key from their UID.
  /// 2. Fetches the encrypted household key from `household_keys`.
  /// 3. Decrypts it and caches in memory.
  ///
  /// Returns the decrypted key, or null if no key doc exists.
  Future<String?> loadHouseholdKey(String householdId) async {
    final uid = _uid;
    if (uid == null) return null;

    // Check in-memory cache first.
    if (_cachedHouseholdId == householdId && _cachedHouseholdKey != null) {
      return _cachedHouseholdKey;
    }

    try {
      final userKey = EncryptionService.deriveUserKey(uid);

      // Try local secure storage first (faster, works offline).
      final localKey = await _secureStorage.read(
        key: 'hk_$householdId',
      );
      if (localKey != null) {
        _cachedHouseholdKey = localKey;
        _cachedHouseholdId = householdId;
        return localKey;
      }

      // Fetch from Firestore.
      final snapshot = await _db
          .collection('household_keys')
          .where('household_id', isEqualTo: householdId)
          .where('user_id', isEqualTo: uid)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('[KeyManager] No key found for household=$householdId');
        return null;
      }

      final encryptedKey = snapshot.docs.first.data()['encrypted_key'] as String;
      final decryptedKey =
          EncryptionService.decryptKeyForUser(encryptedKey, userKey);

      // Cache in memory + secure storage.
      _cachedHouseholdKey = decryptedKey;
      _cachedHouseholdId = householdId;
      await _secureStorage.write(key: 'hk_$householdId', value: decryptedKey);

      debugPrint('[KeyManager] ✓ Loaded household key for $householdId');
      return decryptedKey;
    } catch (e) {
      debugPrint('[KeyManager] ✗ Failed to load key: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  CREATE — Generate & store a new household key
  // ═══════════════════════════════════════════════════════════════════

  /// Generates a new AES-256 key for a household and stores it
  /// encrypted for the current user.
  ///
  /// Called when creating a new household.
  /// Returns the plaintext household key.
  Future<String> createHouseholdKey(String householdId) async {
    final uid = _uid;
    if (uid == null) throw StateError('Not signed in');

    final householdKey = EncryptionService.generateHouseholdKey();
    final userKey = EncryptionService.deriveUserKey(uid);
    final encryptedKey =
        EncryptionService.encryptKeyForUser(householdKey, userKey);

    await _db.collection('household_keys').add({
      'household_id': householdId,
      'user_id': uid,
      'encrypted_key': encryptedKey,
      'created_at': FieldValue.serverTimestamp(),
    });

    // Cache locally.
    _cachedHouseholdKey = householdKey;
    _cachedHouseholdId = householdId;
    await _secureStorage.write(key: 'hk_$householdId', value: householdKey);

    debugPrint('[KeyManager] ✓ Created household key for $householdId');
    return householdKey;
  }

  // ═══════════════════════════════════════════════════════════════════
  //  SHARE — Encrypt the household key for a new member
  // ═══════════════════════════════════════════════════════════════════

  /// Re-encrypts the current household key for a new member.
  ///
  /// Called when a member accepts a household invite. The inviter's
  /// device (which already has the decrypted key) encrypts it for the
  /// new member's UID and writes a new `household_keys` doc.
  Future<void> shareKeyWithMember(
    String householdId,
    String newMemberUid,
  ) async {
    final householdKey = _cachedHouseholdKey;
    if (householdKey == null) {
      throw StateError('No household key loaded — cannot share');
    }

    final newMemberUserKey = EncryptionService.deriveUserKey(newMemberUid);
    final encryptedKey =
        EncryptionService.encryptKeyForUser(householdKey, newMemberUserKey);

    await _db.collection('household_keys').add({
      'household_id': householdId,
      'user_id': newMemberUid,
      'encrypted_key': encryptedKey,
      'created_at': FieldValue.serverTimestamp(),
    });

    debugPrint('[KeyManager] ✓ Shared key with member $newMemberUid');
  }

  // ═══════════════════════════════════════════════════════════════════
  //  CLEANUP — Clear cached keys
  // ═══════════════════════════════════════════════════════════════════

  /// Clears in-memory and local key caches. Called on sign-out or burn.
  Future<void> clearKeys() async {
    _cachedHouseholdKey = null;
    _cachedHouseholdId = null;
    await _secureStorage.deleteAll();
    debugPrint('[KeyManager] ✓ All keys cleared');
  }

  /// Deletes the user's key document from Firestore.
  /// Called during "Burn All My Data".
  Future<void> deleteKeyFromFirestore(String householdId) async {
    final uid = _uid;
    if (uid == null) return;

    try {
      final snapshot = await _db
          .collection('household_keys')
          .where('household_id', isEqualTo: householdId)
          .where('user_id', isEqualTo: uid)
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
      debugPrint('[KeyManager] ✓ Deleted key doc for $householdId');
    } catch (e) {
      debugPrint('[KeyManager] ✗ Failed to delete key: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  RIVERPOD PROVIDER
// ═══════════════════════════════════════════════════════════════════════

final keyManagerProvider = Provider<KeyManager>((ref) {
  return KeyManager();
});
