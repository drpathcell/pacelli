/**
 * Rules tests for `household_members` — locks the self-delete guarantee
 * that the burn orphan-sweep depends on, and the owner-only cascade that
 * replaced "any co-member may delete any member" on 2026-08-24.
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

  // CONTRACT CHANGED 2026-08-24. This used to assert that ANY co-member could
  // delete any other member's doc, in the name of the burn cascade. That was
  // the hole `AUDIT_2026-08-21_ai_link.md` reported: since 1.7.0 a paired AI
  // assistant is a co-member, so "any co-member" included it, and it could
  // evict the household's own people.
  //
  // The cascade is now the OWNER's, anchored on `households.created_by` rather
  // than on the member row's own `role` field, which the client writes.
  // `BurnService.wipeHousehold` was changed to match: a non-owner burning
  // their account leaves other memberships — and the household doc — standing.
  // Full boundary lives in member-authority.test.js; these two keep the burn
  // cascade itself pinned where the burn tests will look for it.
  test('household OWNER CAN delete another member\'s doc (burn cascade)', async () => {
    const ownerUid = 'user-owner';
    const otherUid = 'user-other';
    const hid = 'house-shared';
    await seed(async (db) => {
      await setDoc(doc(db, 'households', hid), { created_by: ownerUid });
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

  test('a non-owner co-member CANNOT delete another member\'s doc', async () => {
    const ownerUid = 'user-owner';
    const otherUid = 'user-other';
    const hid = 'house-shared';
    await seed(async (db) => {
      await setDoc(doc(db, 'households', hid), { created_by: ownerUid });
      await setDoc(doc(db, 'household_members', `${ownerUid}_${hid}`), {
        user_id: ownerUid,
        household_id: hid,
      });
      await setDoc(doc(db, 'household_members', `${otherUid}_${hid}`), {
        user_id: otherUid,
        household_id: hid,
      });
    });

    const otherCtx = testEnv.authenticatedContext(otherUid);
    await assertFails(
      deleteDoc(
        doc(otherCtx.firestore(), 'household_members', `${ownerUid}_${hid}`)
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
