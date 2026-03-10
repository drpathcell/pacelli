import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../crypto/key_manager.dart';
import 'data_repository.dart';
import 'firebase_data_repository.dart';
import 'local_data_repository.dart';

// ─── Storage backend preference ──────────────────────────────────

/// Key used in SharedPreferences to store the chosen backend.
const _kStorageBackend = 'storage_backend';

/// Provider that exposes the currently selected storage backend type.
///
/// Returns 'firebase', 'local', or null (not yet configured).
final storageBackendProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_kStorageBackend);
});

/// Whether the user has completed the storage setup onboarding.
final isStorageConfiguredProvider = FutureProvider<bool>((ref) async {
  final backend = await ref.watch(storageBackendProvider.future);
  return backend != null;
});

// ─── Local database holder ───────────────────────────────────────

/// Holds the opened SQLite [Database] instance.
///
/// Starts as null. Set at runtime by either:
/// - `main()` when the app launches with a previously-chosen 'local' backend.
/// - [StorageSetupScreen] when the user first selects "On This Device".
///
/// [dataRepositoryProvider] watches this — when non-null it returns a
/// [LocalDataRepository]; when null it falls back to Firebase.
final localDatabaseProvider = StateProvider<Database?>((ref) => null);

// ─── DataRepository DI ───────────────────────────────────────────

/// The main entry point: provides the correct [DataRepository] based on
/// the user's storage preference.
///
/// Defaults to [FirebaseDataRepository] with E2E encryption.
/// When a local database is available AND the backend is 'local', uses
/// [LocalDataRepository] instead.
final dataRepositoryProvider = Provider<DataRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  // If a local database has been opened, use it.
  if (db != null) {
    return LocalDataRepository(db, userId: userId);
  }

  // Default: Firebase with E2E encryption.
  final keyManager = ref.watch(keyManagerProvider);
  return FirebaseDataRepository(keyManager: keyManager);
});

// ─── Helpers for storage setup ───────────────────────────────────

/// Saves the chosen backend to SharedPreferences.
Future<void> saveStorageBackend(String backend) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kStorageBackend, backend);
}
