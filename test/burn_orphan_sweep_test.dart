// Locks the orphan-sweep behaviour added to FirebaseDataRepository.wipeAllData
// in 2026-05. Seeds the same shape of bad data that triggered the
// "Burn verification failed: household docs still exist" rejection on macOS
// Pacelli build 16, and asserts the new sweep removes it.
//
// If this test ever fails, the burn flow has regressed in a way that would
// prevent App Store-required account deletion (Guideline 5.1.1(v)) from
// working for any user with stale member docs.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pacelli/core/crypto/key_manager.dart';
import 'package:pacelli/core/data/firebase_data_repository.dart';

const _userId = 'test-user-uid';

// Stub out flutter_secure_storage's platform channel so KeyManager.clearKeys()
// (which calls _secureStorage.deleteAll()) doesn't try to hit the real keychain
// during tests.
void _stubSecureStorageChannel() {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    // Return empty results / null for every method — sufficient for clearKeys.
    if (call.method == 'readAll' || call.method == 'containsKey') {
      return <String, String>{};
    }
    return null;
  });
}

FirebaseDataRepository _buildRepo({
  required FakeFirebaseFirestore firestore,
  required MockFirebaseAuth auth,
}) {
  final keyManager = KeyManager(
    firestore: firestore,
    auth: auth,
  );
  return FirebaseDataRepository(
    keyManager: keyManager,
    firestore: firestore,
    auth: auth,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _stubSecureStorageChannel();

  group('FirebaseDataRepository.wipeAllData orphan sweep', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late FirebaseDataRepository repo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: _userId, email: 'test@pacelli.app'),
      );
      repo = _buildRepo(firestore: firestore, auth: auth);
    });

    test('removes orphan member doc with null household_id', () async {
      // Pre-migration / orphaned member doc — no household_id field at all.
      // This is the exact shape that broke build 16.
      await firestore.collection('household_members').doc('legacy_orphan').set({
        'user_id': _userId,
        // 'household_id' deliberately omitted
      });

      await repo.wipeAllData(_userId);

      final survivors = await firestore
          .collection('household_members')
          .where('user_id', isEqualTo: _userId)
          .get();
      expect(
        survivors.docs,
        isEmpty,
        reason: 'Orphan member doc with null household_id must be swept',
      );
    });

    test('removes orphan member doc with empty-string household_id', () async {
      await firestore.collection('household_members').doc('empty_hid_orphan').set({
        'user_id': _userId,
        'household_id': '',
      });

      await repo.wipeAllData(_userId);

      final survivors = await firestore
          .collection('household_members')
          .where('user_id', isEqualTo: _userId)
          .get();
      expect(survivors.docs, isEmpty);
    });

    test('wipes a normal household membership end-to-end', () async {
      const hid = 'household-1';
      // Standard membership doc using the post-migration ID convention.
      await firestore
          .collection('household_members')
          .doc('${_userId}_$hid')
          .set({
        'user_id': _userId,
        'household_id': hid,
      });
      await firestore.collection('households').doc(hid).set({
        'name': 'Test House',
        'created_by': _userId,
      });
      // Add a sample task so _wipeHouseholdData has work to do.
      await firestore.collection('tasks').add({
        'household_id': hid,
        'title': 'doc to delete',
      });

      await repo.wipeAllData(_userId);

      final survivors = await firestore
          .collection('household_members')
          .where('user_id', isEqualTo: _userId)
          .get();
      final household = await firestore.collection('households').doc(hid).get();
      final tasks = await firestore
          .collection('tasks')
          .where('household_id', isEqualTo: hid)
          .get();
      expect(survivors.docs, isEmpty);
      expect(household.exists, isFalse);
      expect(tasks.docs, isEmpty);
    });

    test('handles mixed orphan + valid memberships in one wipe', () async {
      const hid = 'household-2';
      await firestore
          .collection('household_members')
          .doc('${_userId}_$hid')
          .set({'user_id': _userId, 'household_id': hid});
      await firestore.collection('households').doc(hid).set({
        'name': 'Mixed',
        'created_by': _userId,
      });
      // Plus an orphan
      await firestore
          .collection('household_members')
          .doc('orphan_x')
          .set({'user_id': _userId, 'household_id': null});

      await repo.wipeAllData(_userId);

      final survivors = await firestore
          .collection('household_members')
          .where('user_id', isEqualTo: _userId)
          .get();
      expect(survivors.docs, isEmpty);
    });

    test('does not touch unrelated users in unrelated households', () async {
      // The user being burned, in their own household.
      const hid = 'household-3';
      await firestore
          .collection('household_members')
          .doc('${_userId}_$hid')
          .set({'user_id': _userId, 'household_id': hid});
      await firestore.collection('households').doc(hid).set({'name': 'Mine'});

      // A completely unrelated user, in a separate household — must survive.
      const otherHid = 'unrelated-household';
      await firestore
          .collection('household_members')
          .doc('other-user_$otherHid')
          .set({'user_id': 'other-user', 'household_id': otherHid});
      await firestore
          .collection('households')
          .doc(otherHid)
          .set({'name': 'Theirs'});
      await firestore.collection('tasks').add({
        'household_id': otherHid,
        'title': 'their task',
      });

      await repo.wipeAllData(_userId);

      final mineLeft = await firestore
          .collection('household_members')
          .where('user_id', isEqualTo: _userId)
          .get();
      final theirsLeft = await firestore
          .collection('household_members')
          .where('user_id', isEqualTo: 'other-user')
          .get();
      final otherHousehold =
          await firestore.collection('households').doc(otherHid).get();
      final otherTasks = await firestore
          .collection('tasks')
          .where('household_id', isEqualTo: otherHid)
          .get();
      expect(mineLeft.docs, isEmpty);
      expect(
        theirsLeft.docs,
        isNotEmpty,
        reason: 'Burning user A must not touch user B in a different household',
      );
      expect(otherHousehold.exists, isTrue);
      expect(otherTasks.docs, isNotEmpty);
    });
  });
}
