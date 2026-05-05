/**
 * Rules tests for `household_members` — locks the self-delete guarantee
 * that the burn orphan-sweep depends on.
 *
 * Run with: `npm test` (spins up the Firestore emulator automatically).
 *
 * If any of these tests start failing after a rule edit, the burn flow
 * for App Store-required account deletion (Guideline 5.1.1(v)) is broken:
 * users with stale orphan member docs would silently fail to fully wipe
 * their data.
 */

const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, deleteDoc, setDoc, getDoc, setLogLevel } = require('firebase/firestore');

let testEnv;

beforeAll(async () => {
  setLogLevel('error');
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-pacelli',
    firestore: {
      rules: fs.readFileSync(
        path.resolve(__dirname, '..', 'firestore.rules'),
        'utf8'
      ),
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

/**
 * Seeds documents bypassing rules — used only to set up state.
 */
async function seed(setupFn) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setupFn(ctx.firestore());
  });
}

describe('household_members rule — self-delete', () => {
  test('user CAN delete their own orphan member doc (null household_id)', async () => {
    const uid = 'user-A';
    await seed(async (db) => {
      await setDoc(doc(db, 'household_members', 'orphan_legacy_A'), {
        user_id: uid,
        // household_id deliberately omitted — orphan from pre-migration state
      });
    });

    const userCtx = testEnv.authenticatedContext(uid);
    await assertSucceeds(
      deleteDoc(doc(userCtx.firestore(), 'household_members', 'orphan_legacy_A'))
    );
  });

  test('user CAN delete their own member doc (valid household)', async () => {
    const uid = 'user-A';
    const hid = 'house-1';
    await seed(async (db) => {
      await setDoc(doc(db, 'household_members', `${uid}_${hid}`), {
        user_id: uid,
        household_id: hid,
      });
    });

    const userCtx = testEnv.authenticatedContext(uid);
    await assertSucceeds(
      deleteDoc(doc(userCtx.firestore(), 'household_members', `${uid}_${hid}`))
    );
  });

  test('user CANNOT delete another user\'s member doc when not co-resident', async () => {
    const attackerUid = 'user-A';
    const victimUid = 'user-B';
    const hid = 'house-victim';
    await seed(async (db) => {
      await setDoc(doc(db, 'household_members', `${victimUid}_${hid}`), {
        user_id: victimUid,
        household_id: hid,
      });
    });

    const attackerCtx = testEnv.authenticatedContext(attackerUid);
    await assertFails(
      deleteDoc(
        doc(attackerCtx.firestore(), 'household_members', `${victimUid}_${hid}`)
      )
    );
  });

  test('co-member CAN delete another user\'s member doc in same household (burn cascade)', async () => {
    const ownerUid = 'user-owner';
    const otherUid = 'user-other';
    const hid = 'house-shared';
    await seed(async (db) => {
      await setDoc(doc(db, 'household_members', `${ownerUid}_${hid}`), {
        user_id: ownerUid,
        household_id: hid,
      });
      await setDoc(doc(db, 'household_members', `${otherUid}_${hid}`), {
        user_id: otherUid,
        household_id: hid,
      });
    });

    const ownerCtx = testEnv.authenticatedContext(ownerUid);
    await assertSucceeds(
      deleteDoc(
        doc(ownerCtx.firestore(), 'household_members', `${otherUid}_${hid}`)
      )
    );
  });

  test('unauthenticated request CANNOT delete any member doc', async () => {
    const uid = 'user-A';
    await seed(async (db) => {
      await setDoc(doc(db, 'household_members', 'unauth_target'), {
        user_id: uid,
      });
    });

    const anonCtx = testEnv.unauthenticatedContext();
    await assertFails(
      deleteDoc(doc(anonCtx.firestore(), 'household_members', 'unauth_target'))
    );
  });
});

describe('household_members rule — read', () => {
  test('user can read their own member doc', async () => {
    const uid = 'user-A';
    const hid = 'house-1';
    await seed(async (db) => {
      await setDoc(doc(db, 'household_members', `${uid}_${hid}`), {
        user_id: uid,
        household_id: hid,
      });
    });

    const userCtx = testEnv.authenticatedContext(uid);
    await assertSucceeds(
      getDoc(doc(userCtx.firestore(), 'household_members', `${uid}_${hid}`))
    );
  });

  test('stranger cannot read someone else\'s member doc', async () => {
    const ownerUid = 'user-A';
    const strangerUid = 'user-Z';
    const hid = 'house-1';
    await seed(async (db) => {
      await setDoc(doc(db, 'household_members', `${ownerUid}_${hid}`), {
        user_id: ownerUid,
        household_id: hid,
      });
    });

    const strangerCtx = testEnv.authenticatedContext(strangerUid);
    await assertFails(
      getDoc(
        doc(strangerCtx.firestore(), 'household_members', `${ownerUid}_${hid}`)
      )
    );
  });
});
