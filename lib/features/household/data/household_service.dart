import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../core/crypto/encryption_service.dart';
import '../../../core/crypto/key_manager.dart';

/// Service for household CRUD operations via Cloud Firestore.
///
/// Household names are end-to-end encrypted. Profile names in this service
/// are decrypted for display.
class HouseholdService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static const _uuid = Uuid();

  /// The [KeyManager] instance — must be set before calling household
  /// operations that need encryption/decryption.
  static KeyManager? keyManager;

  static String? get _uid => _auth.currentUser?.uid;

  /// The household key (if loaded).
  static String? get _key => keyManager?.householdKey;

  static String _enc(String plaintext) =>
      _key != null ? EncryptionService.encrypt(plaintext, _key!) : plaintext;

  // ignore: unused_element
  static String _dec(String ciphertext) =>
      _key != null ? EncryptionService.decrypt(ciphertext, _key!) : ciphertext;

  // ═══════════════════════════════════════════════════════════════════
  //  CREATE HOUSEHOLD
  // ═══════════════════════════════════════════════════════════════════

  /// Creates a new household and adds the current user as admin.
  ///
  /// Generates a per-household encryption key, encrypts the household name,
  /// and stores the key encrypted for the current user.
  ///
  /// Returns the created household data.
  static Future<Map<String, dynamic>> createHousehold(String name) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');

    final householdId = _uuid.v4();
    final now = DateTime.now();
    final km = keyManager ?? KeyManager.instance;

    // Generate a new household encryption key.
    final householdKey = await km.createHouseholdKey(householdId);

    // Now encrypt the household name with the new key.
    final encryptedName = EncryptionService.encrypt(name, householdKey);

    final batch = _db.batch();

    // Create household doc.
    batch.set(_db.collection('households').doc(householdId), {
      'id': householdId,
      'name': encryptedName,
      'created_by': uid,
      'created_at': now.toIso8601String(),
    });

    // Add creator as admin member.
    // Doc ID = {uid}_{householdId} — deterministic for Firestore security rules.
    final memberId = '${uid}_$householdId';
    batch.set(_db.collection('household_members').doc(memberId), {
      'household_id': householdId,
      'user_id': uid,
      'role': 'admin',
      'joined_at': now.toIso8601String(),
    });

    await batch.commit();

    debugPrint('[HouseholdService] ✓ Created household $householdId');

    // Encrypt and store the profile name now that we have a household key.
    await _encryptProfileName(uid, householdKey);

    return {
      'id': householdId,
      'name': name,
      'created_by': uid,
      'created_at': now.toIso8601String(),
    };
  }

  // ═══════════════════════════════════════════════════════════════════
  //  GET CURRENT HOUSEHOLD
  // ═══════════════════════════════════════════════════════════════════

  /// Fetches the current user's household (if any).
  ///
  /// Also loads the household encryption key so data can be decrypted.
  /// Returns null if the user hasn't joined a household yet.
  static Future<Map<String, dynamic>?> getCurrentHousehold() async {
    final uid = _uid;
    if (uid == null) return null;

    try {
      // Find the user's household membership.
      final memberSnap = await _db
          .collection('household_members')
          .where('user_id', isEqualTo: uid)
          .limit(1)
          .get();

      if (memberSnap.docs.isEmpty) return null;

      final membership = memberSnap.docs.first.data();
      final householdId = membership['household_id'] as String;

      // Load the household encryption key.
      final km = keyManager ?? KeyManager.instance;
      await km.loadHouseholdKey(householdId);

      // Fetch the household doc.
      final householdDoc =
          await _db.collection('households').doc(householdId).get();
      if (!householdDoc.exists) return null;

      final householdData = householdDoc.data()!;

      // Decrypt name using the now-loaded key.
      final decryptedName = km.householdKey != null
          ? EncryptionService.decrypt(
              householdData['name'] as String, km.householdKey!)
          : householdData['name'] as String;

      return {
        'membership': membership,
        'household': {
          'id': householdId,
          'name': decryptedName,
          'created_by': householdData['created_by'],
          'created_at': householdData['created_at'],
        },
        'role': membership['role'],
      };
    } catch (e) {
      debugPrint('[HouseholdService] ✗ getCurrentHousehold: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  MEMBERS
  // ═══════════════════════════════════════════════════════════════════

  /// Fetches all members of a household with their profile info.
  static Future<List<Map<String, dynamic>>> getHouseholdMembers(
      String householdId) async {
    // Ensure the household key is loaded so profile names can be decrypted.
    final km = keyManager ?? KeyManager.instance;
    await km.loadHouseholdKey(householdId);

    final memberSnap = await _db
        .collection('household_members')
        .where('household_id', isEqualTo: householdId)
        .get();

    final results = <Map<String, dynamic>>[];

    for (final doc in memberSnap.docs) {
      final data = doc.data();
      final userId = data['user_id'] as String;

      // Fetch profile.
      Map<String, dynamic>? profile;
      final profileDoc = await _db.collection('profiles').doc(userId).get();
      if (profileDoc.exists) {
        final pData = profileDoc.data()!;
        final rawName = pData['full_name'] as String?;
        // Decrypt using the key we just loaded — don't rely on the static
        // _key getter which may be null if keyManager was not set.
        profile = {
          'id': userId,
          'full_name': (km.householdKey != null && rawName != null && rawName.isNotEmpty)
              ? EncryptionService.decryptNullable(rawName, km.householdKey!)
              : rawName,
          'avatar_url': pData['avatar_url'] as String?,
        };
      }

      results.add({
        'user_id': userId,
        'role': data['role'],
        'joined_at': data['joined_at'],
        'profiles': profile,
      });
    }

    return results;
  }

  // ═══════════════════════════════════════════════════════════════════
  //  INVITES
  // ═══════════════════════════════════════════════════════════════════

  /// Invites a user to the household by email.
  static Future<void> inviteByEmail({
    required String householdId,
    required String email,
  }) async {
    final id = _uuid.v4();
    await _db.collection('household_invites').doc(id).set({
      'id': id,
      'household_id': householdId,
      'invited_email': email,
      'invited_by': _uid,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Checks if the current user has a pending invite and accepts it.
  ///
  /// When accepting, the inviter's device must share the household key
  /// with the new member. For now, we handle this by having the accepting
  /// user request the key from an existing member's device.
  static Future<Map<String, dynamic>?> checkAndAcceptInvite() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return null;

    final inviteSnap = await _db
        .collection('household_invites')
        .where('invited_email', isEqualTo: user.email!)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (inviteSnap.docs.isEmpty) return null;

    final invite = inviteSnap.docs.first.data();
    final householdId = invite['household_id'] as String;

    final batch = _db.batch();

    // Add user as member.
    // Doc ID = {uid}_{householdId} — deterministic for Firestore security rules.
    final memberId = '${user.uid}_$householdId';
    batch.set(_db.collection('household_members').doc(memberId), {
      'household_id': householdId,
      'user_id': user.uid,
      'role': 'member',
      'joined_at': DateTime.now().toIso8601String(),
    });

    // Mark invite as accepted.
    batch.update(inviteSnap.docs.first.reference, {'status': 'accepted'});

    await batch.commit();

    // Load the household key and encrypt the profile name.
    final km = keyManager ?? KeyManager.instance;
    final hKey = await km.loadHouseholdKey(householdId);
    if (hKey != null) {
      await _encryptProfileName(user.uid, hKey);
    }

    // Fetch the household info.
    final householdDoc =
        await _db.collection('households').doc(householdId).get();
    if (!householdDoc.exists) return null;

    final hData = householdDoc.data()!;
    return {
      'id': householdId,
      'name': hData['name'], // Still encrypted — caller will decrypt.
    };
  }

  /// Removes a member from the household.
  static Future<void> removeMember({
    required String householdId,
    required String userId,
  }) async {
    final batch = _db.batch();

    // Direct delete using deterministic doc ID.
    batch.delete(
      _db.collection('household_members').doc('${userId}_$householdId'),
    );

    // Also clean up any legacy random-UUID member docs (migration safety).
    final legacySnap = await _db
        .collection('household_members')
        .where('household_id', isEqualTo: householdId)
        .where('user_id', isEqualTo: userId)
        .get();
    for (final doc in legacySnap.docs) {
      if (doc.id != '${userId}_$householdId') {
        batch.delete(doc.reference);
      }
    }

    // Also delete the member's household key.
    final keySnap = await _db
        .collection('household_keys')
        .where('household_id', isEqualTo: householdId)
        .where('user_id', isEqualTo: userId)
        .get();
    for (final doc in keySnap.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  /// Reads the locally-cached profile name, encrypts it with the household
  /// key, and writes it to the Firestore profile doc.
  static Future<void> _encryptProfileName(String uid, String householdKey) async {
    try {
      const secureStorage = FlutterSecureStorage();
      final localName = await secureStorage.read(key: 'profile_name_$uid');
      if (localName != null && localName.isNotEmpty) {
        final encryptedName = EncryptionService.encrypt(localName, householdKey);
        await _db.collection('profiles').doc(uid).update({
          'full_name': encryptedName,
        });
        debugPrint('[HouseholdService] ✓ Encrypted profile name for $uid');
      }
    } catch (e) {
      debugPrint('[HouseholdService] ✗ Failed to encrypt profile name: $e');
    }
  }

  /// Updates the household name (encrypted).
  static Future<void> updateHouseholdName({
    required String householdId,
    required String name,
  }) async {
    await _db.collection('households').doc(householdId).update({
      'name': _enc(name),
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  //  DATA MIGRATION
  // ═══════════════════════════════════════════════════════════════════

  /// Migrates household_members docs from random UUIDs to deterministic
  /// `{userId}_{householdId}` doc IDs.
  ///
  /// This is required for Firestore security rules that use `exists()` to
  /// verify household membership. Safe to call multiple times (idempotent).
  static Future<void> migrateMemberDocIds() async {
    final uid = _uid;
    if (uid == null) return;

    try {
      // Find all memberships for the current user.
      final snap = await _db
          .collection('household_members')
          .where('user_id', isEqualTo: uid)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final householdId = data['household_id'] as String;
        final expectedId = '${uid}_$householdId';

        // Skip if already using the correct deterministic ID.
        if (doc.id == expectedId) continue;

        debugPrint(
          '[HouseholdService] Migrating member doc ${doc.id} → $expectedId',
        );

        final batch = _db.batch();

        // Create new doc with deterministic ID.
        batch.set(
          _db.collection('household_members').doc(expectedId),
          data,
        );

        // Delete the old random-UUID doc.
        batch.delete(doc.reference);

        await batch.commit();
      }
    } catch (e) {
      debugPrint('[HouseholdService] ✗ migrateMemberDocIds: $e');
    }
  }
}
