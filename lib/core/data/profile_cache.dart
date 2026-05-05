import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';

/// Caches user profiles from Firestore into local SQLite.
///
/// When data is stored in local SQLite, tasks reference user UUIDs for
/// `assigned_to` and `created_by` but there's no local profiles table
/// to join against. This class fetches profiles from Firestore
/// and caches them locally so that the UI can display names and avatars.
class ProfileCache {
  final Database _db;
  final FirebaseFirestore _firestore;

  ProfileCache({
    required Database db,
    FirebaseFirestore? firestore,
  })  : _db = db,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Gets a single profile by user ID, from cache or Firestore.
  ///
  /// Returns a map with `id`, `full_name`, `avatar_url` keys.
  /// Falls back to `{'id': userId, 'full_name': 'Unknown', 'avatar_url': null}`
  /// if the profile cannot be resolved.
  Future<Map<String, dynamic>> getProfile(String userId) async {
    // 1. Check local cache
    final cached = await _db.query(
      'profile_cache',
      where: 'id = ?',
      whereArgs: [userId],
    );

    if (cached.isNotEmpty) {
      return {
        'id': cached.first['id'],
        'full_name': cached.first['full_name'],
        'avatar_url': cached.first['avatar_url'],
      };
    }

    // 2. Fetch from Firestore
    try {
      final doc = await _firestore.collection('profiles').doc(userId).get();

      if (doc.exists) {
        final data = doc.data()!;
        final profile = {
          'id': userId,
          'full_name': data['full_name'] ?? 'Unknown',
          'avatar_url': data['avatar_url'],
        };

        // Cache it
        await _db.insert(
          'profile_cache',
          {
            'id': userId,
            'full_name': profile['full_name'],
            'avatar_url': profile['avatar_url'],
            'updated_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return profile;
      }
    } catch (_) {
      // Network error — return fallback
    }

    // 3. Fallback for local-only mode: if this is the currently signed-in
    // user, use their Firebase Auth displayName or the locally-stashed
    // signup name from secure storage. Avoids "Unknown" appearing for the
    // user's own creations when there's no Firestore profile to fetch.
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid == userId) {
        String? name = currentUser.displayName;
        if (name == null || name.trim().isEmpty) {
          const secureStorage = FlutterSecureStorage();
          name = await secureStorage.read(key: 'profile_name_$userId');
        }
        if (name != null && name.trim().isNotEmpty) {
          // Cache locally so subsequent reads are instant.
          await _db.insert(
            'profile_cache',
            {
              'id': userId,
              'full_name': name,
              'avatar_url': null,
              'updated_at': DateTime.now().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          return {'id': userId, 'full_name': name, 'avatar_url': null};
        }
      }
    } catch (_) {
      // Fall through to Unknown.
    }

    return {'id': userId, 'full_name': 'Unknown', 'avatar_url': null};
  }

  /// Syncs all profiles for a given household into the local cache.
  ///
  /// Call this after fetching the household member list.
  Future<void> syncHouseholdProfiles(String householdId) async {
    try {
      // Fetch all members of this household from Firestore
      final membersSnapshot = await _firestore
          .collection('household_members')
          .where('household_id', isEqualTo: householdId)
          .get();

      final now = DateTime.now().toIso8601String();

      for (final memberDoc in membersSnapshot.docs) {
        final userId = memberDoc.data()['user_id'] as String?;
        if (userId == null) continue;

        // Fetch this member's profile
        final profileDoc =
            await _firestore.collection('profiles').doc(userId).get();
        if (!profileDoc.exists) continue;

        final profileData = profileDoc.data()!;
        await _db.insert(
          'profile_cache',
          {
            'id': userId,
            'full_name': profileData['full_name'] ?? 'Unknown',
            'avatar_url': profileData['avatar_url'],
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (_) {
      // Silently fail — stale cache is better than no data
    }
  }

  /// Clears the entire profile cache.
  Future<void> clear() async {
    await _db.delete('profile_cache');
  }
}
