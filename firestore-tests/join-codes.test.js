/**
 * Rules tests for `household_join_codes` — the SIWA-proof way into a
 * household.
 *
 * Email-addressed invites match on `request.auth.token.email`. For Sign in
 * with Apple with "Hide My Email" that is an `@privaterelay.appleid.com`
 * address the inviter cannot know, so those invites can never land. A join
 * code inverts the direction: the household publishes a bearer secret.
 *
 * The security of that rests entirely on three properties, all locked here:
 *   1. `get` by exact code is open to any signed-in user (that IS the flow),
 *      but `list` is member-only — so codes cannot be enumerated.
 *   2. Expiry is enforced server-side, so a patched client gains nothing.
 *   3. Only members can mint a code, and only for their own household.
 *
 * Also locks the tightened `household_members` create rule: self-join only.
 * It was previously a bare `isAuth()`, which let any signed-in user mint a
 * membership for anyone, in any household.
 */

const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  collection,
  query,
  where,
  getDoc,
  getDocs,
  setDoc,
  deleteDoc,
  writeBatch,
  Timestamp,
  setLogLevel,
} = require('firebase/firestore');

const HH = 'hh-1';
const OTHER_HH = 'hh-2';
const OWNER_UID = 'uid-owner';
const JOINER_UID = 'uid-joiner';
const CODE = 'K7QP4M2X';
const STALE_CODE = 'M3NPQRST';

const DAY = 24 * 60 * 60 * 1000;
const future = (ms) => Timestamp.fromMillis(Date.now() + ms);
const past = (ms) => Timestamp.fromMillis(Date.now() - ms);

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
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'household_members', `${OWNER_UID}_${HH}`), {
      user_id: OWNER_UID,
      household_id: HH,
      role: 'admin',
      joined_at: '2026-08-01T10:00:00.000Z',
    });
    await setDoc(doc(db, 'household_join_codes', CODE), {
      household_id: HH,
      encrypted_key: 'household-key-wrapped-for-the-code',
      created_by: OWNER_UID,
      created_at: past(60_000),
      expires_at: future(7 * DAY),
    });
    await setDoc(doc(db, 'household_join_codes', STALE_CODE), {
      household_id: HH,
      encrypted_key: 'stale',
      created_by: OWNER_UID,
      created_at: past(30 * DAY),
      expires_at: past(DAY),
    });
  });
});

/** A signed-in stranger — SIWA private-relay email, i.e. useless for invites. */
function joiner() {
  return testEnv
    .authenticatedContext(JOINER_UID, {
      email: 'a1b2c3d4e5@privaterelay.appleid.com',
      email_verified: true,
    })
    .firestore();
}

function owner() {
  return testEnv
    .authenticatedContext(OWNER_UID, { email: 'owner@example.com' })
    .firestore();
}

describe('household_join_codes — bearer lookup', () => {
  test('any signed-in user CAN get a live code by exact id', async () => {
    await assertSucceeds(getDoc(doc(joiner(), 'household_join_codes', CODE)));
  });

  test('an unauthenticated user CANNOT get a code', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'household_join_codes', CODE)));
  });

  test('an EXPIRED code CANNOT be fetched (server-side expiry)', async () => {
    await assertFails(
      getDoc(doc(joiner(), 'household_join_codes', STALE_CODE))
    );
  });

  test('a non-member CANNOT list/enumerate codes', async () => {
    const db = joiner();
    await assertFails(getDocs(collection(db, 'household_join_codes')));
    await assertFails(
      getDocs(
        query(
          collection(db, 'household_join_codes'),
          where('household_id', '==', HH)
        )
      )
    );
  });

  test('a member CAN list their own household codes, expired included', async () => {
    await assertSucceeds(
      getDocs(
        query(
          collection(owner(), 'household_join_codes'),
          where('household_id', '==', HH)
        )
      )
    );
  });
});

describe('household_join_codes — minting', () => {
  test('a member CAN mint a code for their own household', async () => {
    await assertSucceeds(
      setDoc(doc(owner(), 'household_join_codes', 'NEWCODE1'), {
        household_id: HH,
        encrypted_key: 'wrapped',
        created_by: OWNER_UID,
        created_at: Timestamp.now(),
        expires_at: future(7 * DAY),
      })
    );
  });

  test('a non-member CANNOT mint a code for a household', async () => {
    await assertFails(
      setDoc(doc(joiner(), 'household_join_codes', 'NEWCODE2'), {
        household_id: HH,
        encrypted_key: 'wrapped',
        created_by: JOINER_UID,
        created_at: Timestamp.now(),
        expires_at: future(7 * DAY),
      })
    );
  });

  test('a member CANNOT mint a code for a household they are not in', async () => {
    await assertFails(
      setDoc(doc(owner(), 'household_join_codes', 'NEWCODE3'), {
        household_id: OTHER_HH,
        encrypted_key: 'wrapped',
        created_by: OWNER_UID,
        created_at: Timestamp.now(),
        expires_at: future(7 * DAY),
      })
    );
  });

  test('a code CANNOT be minted already-expired or long-lived', async () => {
    const db = owner();
    await assertFails(
      setDoc(doc(db, 'household_join_codes', 'NEWCODE4'), {
        household_id: HH,
        encrypted_key: 'wrapped',
        created_by: OWNER_UID,
        created_at: Timestamp.now(),
        expires_at: past(DAY),
      })
    );
    await assertFails(
      setDoc(doc(db, 'household_join_codes', 'NEWCODE5'), {
        household_id: HH,
        encrypted_key: 'wrapped',
        created_by: OWNER_UID,
        created_at: Timestamp.now(),
        expires_at: future(365 * DAY),
      })
    );
  });

  test('a member CAN revoke (delete) a code; a non-member CANNOT', async () => {
    await assertFails(deleteDoc(doc(joiner(), 'household_join_codes', CODE)));
    await assertSucceeds(deleteDoc(doc(owner(), 'household_join_codes', CODE)));
  });
});

describe('join redemption — the shipped batch', () => {
  test('joiner CAN commit member doc + their own wrapped key in one batch', async () => {
    const db = joiner();
    const batch = writeBatch(db);
    batch.set(doc(db, 'household_members', `${JOINER_UID}_${HH}`), {
      user_id: JOINER_UID,
      household_id: HH,
      role: 'member',
      joined_at: '2026-08-09T12:00:00.000Z',
    });
    batch.set(doc(db, 'household_keys', 'joiner-key'), {
      household_id: HH,
      user_id: JOINER_UID,
      encrypted_key: 'rewrapped-for-joiner',
    });
    // Neither write depends on a membership this batch is creating — the
    // trap that broke email invites does not exist on this path.
    await assertSucceeds(batch.commit());
  });
});

describe('household_members — self-join only', () => {
  test('a user CAN create their own member doc', async () => {
    await assertSucceeds(
      setDoc(doc(joiner(), 'household_members', `${JOINER_UID}_${HH}`), {
        user_id: JOINER_UID,
        household_id: HH,
        role: 'member',
        joined_at: '2026-08-09T12:00:00.000Z',
      })
    );
  });

  test('a user CANNOT mint a membership for someone else', async () => {
    await assertFails(
      setDoc(doc(joiner(), 'household_members', `victim_${HH}`), {
        user_id: 'victim',
        household_id: HH,
        role: 'member',
        joined_at: '2026-08-09T12:00:00.000Z',
      })
    );
  });

  test('an admin CANNOT self-promote someone else into their household', async () => {
    await assertFails(
      setDoc(doc(owner(), 'household_members', `outsider_${HH}`), {
        user_id: 'outsider',
        household_id: HH,
        role: 'admin',
        joined_at: '2026-08-09T12:00:00.000Z',
      })
    );
  });
});
