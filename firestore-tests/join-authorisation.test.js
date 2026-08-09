/**
 * Rules tests for `household_members` create — proof of authorisation.
 *
 * Self-join-only is not enough on its own: it still lets anyone who learns a
 * household ID walk into that household. So a member doc must name, in
 * `joined_via`, the `household_invites` or `household_join_codes` doc that
 * authorised it, and the rules re-read that doc server-side.
 *
 * The one branch without a proof is founding, because `createHousehold`
 * writes the household doc and the member doc in ONE batch and rules never
 * see a batch's own uncommitted writes — the household genuinely does not
 * exist at evaluation time. These tests pin that branch shut the moment the
 * household is committed.
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
  writeBatch,
  Timestamp,
  setLogLevel,
} = require('firebase/firestore');

const HH = 'hh-1';
const OTHER_HH = 'hh-2';
// A second household the founder DOES own, with no member doc yet.
const OWN_HH = 'hh-3';
const FOUNDER_UID = 'uid-founder';
const INVITEE_UID = 'uid-invitee';
const INVITEE_EMAIL = 'invitee@example.com';
const RELAY_UID = 'uid-relay';
const RELAY_EMAIL = 'a1b2c3@privaterelay.appleid.com';
const INTRUDER_UID = 'uid-intruder';
const JOINER_MISS_UID = 'uid-not-a-member';

const INVITE_ID = 'invite-uuid-1';
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
    await setDoc(doc(db, 'households', HH), {
      id: HH,
      name: 'enc:blob',
      created_by: FOUNDER_UID,
      created_at: '2026-08-01T10:00:00.000Z',
    });
    await setDoc(doc(db, 'households', OWN_HH), {
      id: OWN_HH,
      name: 'enc:blob',
      created_by: FOUNDER_UID,
      created_at: '2026-08-01T10:00:00.000Z',
    });
    await setDoc(doc(db, 'households', OTHER_HH), {
      id: OTHER_HH,
      name: 'enc:blob',
      created_by: 'someone-else',
      created_at: '2026-08-01T10:00:00.000Z',
    });
    await setDoc(doc(db, 'household_members', `${FOUNDER_UID}_${HH}`), {
      user_id: FOUNDER_UID,
      household_id: HH,
      role: 'admin',
      joined_at: '2026-08-01T10:00:00.000Z',
    });
    await setDoc(doc(db, 'household_invites', INVITE_ID), {
      id: INVITE_ID,
      household_id: HH,
      invited_email: INVITEE_EMAIL,
      invited_by: FOUNDER_UID,
      status: 'pending',
      created_at: '2026-08-09T10:00:00.000Z',
    });
    await setDoc(doc(db, 'household_join_codes', CODE), {
      household_id: HH,
      encrypted_key: 'wrapped',
      created_by: FOUNDER_UID,
      created_at: past(60_000),
      expires_at: future(7 * DAY),
    });
    await setDoc(doc(db, 'household_join_codes', STALE_CODE), {
      household_id: HH,
      encrypted_key: 'wrapped',
      created_by: FOUNDER_UID,
      created_at: past(30 * DAY),
      expires_at: past(DAY),
    });
  });
});

const ctxFor = (uid, email) =>
  testEnv.authenticatedContext(uid, email ? { email, email_verified: true } : {}).firestore();

const memberDoc = (uid, hh, extra = {}) => ({
  user_id: uid,
  household_id: hh,
  role: 'member',
  joined_at: '2026-08-09T12:00:00.000Z',
  ...extra,
});

describe('founding branch', () => {
  test('founder CAN create household + member doc in one batch', async () => {
    const db = ctxFor('uid-new-founder', 'new@example.com');
    const NEW_HH = 'hh-brand-new';
    const batch = writeBatch(db);
    batch.set(doc(db, 'households', NEW_HH), {
      id: NEW_HH,
      name: 'enc',
      created_by: 'uid-new-founder',
      created_at: '2026-08-09T12:00:00.000Z',
    });
    batch.set(
      doc(db, 'household_members', `uid-new-founder_${NEW_HH}`),
      memberDoc('uid-new-founder', NEW_HH, { role: 'admin' })
    );
    await assertSucceeds(batch.commit());
  });

  test('the founding branch is CLOSED once the household exists', async () => {
    // No joined_via, household already committed — this is the exact attack
    // that "self-join only" alone did not stop.
    const db = ctxFor(INTRUDER_UID, 'intruder@example.com');
    await assertFails(
      setDoc(
        doc(db, 'household_members', `${INTRUDER_UID}_${HH}`),
        memberDoc(INTRUDER_UID, HH)
      )
    );
  });

  test('the original founder CAN re-add themselves to a household they created', async () => {
    // Recovery path: the member doc was lost (burn orphan sweep, botched
    // migration) but the household is theirs — created_by proves it.
    const db = ctxFor(FOUNDER_UID, 'founder@example.com');
    await assertSucceeds(
      setDoc(
        doc(db, 'household_members', `${FOUNDER_UID}_${OWN_HH}`),
        memberDoc(FOUNDER_UID, OWN_HH, { role: 'admin' })
      )
    );
  });

  test('a non-founder CANNOT join a household they did not create', async () => {
    const db = ctxFor(INTRUDER_UID, 'intruder@example.com');
    await assertFails(
      setDoc(
        doc(db, 'household_members', `${INTRUDER_UID}_${OWN_HH}`),
        memberDoc(INTRUDER_UID, OWN_HH)
      )
    );
  });
});

describe('households create', () => {
  test('created_by must be the caller', async () => {
    const db = ctxFor(INTRUDER_UID, 'intruder@example.com');
    await assertFails(
      setDoc(doc(db, 'households', 'hh-forged'), {
        id: 'hh-forged',
        name: 'enc',
        created_by: FOUNDER_UID,
        created_at: '2026-08-09T12:00:00.000Z',
      })
    );
    await assertSucceeds(
      setDoc(doc(db, 'households', 'hh-own'), {
        id: 'hh-own',
        name: 'enc',
        created_by: INTRUDER_UID,
        created_at: '2026-08-09T12:00:00.000Z',
      })
    );
  });
});

describe('email-invite proof', () => {
  test('invitee CAN join naming their invite doc', async () => {
    const db = ctxFor(INVITEE_UID, INVITEE_EMAIL);
    await assertSucceeds(
      setDoc(
        doc(db, 'household_members', `${INVITEE_UID}_${HH}`),
        memberDoc(INVITEE_UID, HH, { joined_via: INVITE_ID })
      )
    );
  });

  test('someone else CANNOT reuse that invite doc as proof', async () => {
    const db = ctxFor(INTRUDER_UID, 'intruder@example.com');
    await assertFails(
      setDoc(
        doc(db, 'household_members', `${INTRUDER_UID}_${HH}`),
        memberDoc(INTRUDER_UID, HH, { joined_via: INVITE_ID })
      )
    );
  });

  test('an invite for household A CANNOT authorise joining household B', async () => {
    const db = ctxFor(INVITEE_UID, INVITEE_EMAIL);
    await assertFails(
      setDoc(
        doc(db, 'household_members', `${INVITEE_UID}_${OTHER_HH}`),
        memberDoc(INVITEE_UID, OTHER_HH, { joined_via: INVITE_ID })
      )
    );
  });

  test('a made-up joined_via reference CANNOT authorise a join', async () => {
    const db = ctxFor(INTRUDER_UID, 'intruder@example.com');
    await assertFails(
      setDoc(
        doc(db, 'household_members', `${INTRUDER_UID}_${HH}`),
        memberDoc(INTRUDER_UID, HH, { joined_via: 'does-not-exist' })
      )
    );
  });
});

describe('join-code proof (the SIWA private-relay path)', () => {
  test('a hidden-email SIWA user CAN join with a live code', async () => {
    const db = ctxFor(RELAY_UID, RELAY_EMAIL);
    await assertSucceeds(
      setDoc(
        doc(db, 'household_members', `${RELAY_UID}_${HH}`),
        memberDoc(RELAY_UID, HH, { joined_via: CODE })
      )
    );
  });

  test('the full redemption batch (member + wrapped key) commits', async () => {
    const db = ctxFor(RELAY_UID, RELAY_EMAIL);
    const batch = writeBatch(db);
    batch.set(
      doc(db, 'household_members', `${RELAY_UID}_${HH}`),
      memberDoc(RELAY_UID, HH, { joined_via: CODE })
    );
    batch.set(doc(db, 'household_keys', 'relay-key'), {
      household_id: HH,
      user_id: RELAY_UID,
      encrypted_key: 'rewrapped',
    });
    await assertSucceeds(batch.commit());
  });

  test('an EXPIRED code CANNOT authorise a join', async () => {
    const db = ctxFor(RELAY_UID, RELAY_EMAIL);
    await assertFails(
      setDoc(
        doc(db, 'household_members', `${RELAY_UID}_${HH}`),
        memberDoc(RELAY_UID, HH, { joined_via: STALE_CODE })
      )
    );
  });

  test('a code for household A CANNOT authorise joining household B', async () => {
    const db = ctxFor(RELAY_UID, RELAY_EMAIL);
    await assertFails(
      setDoc(
        doc(db, 'household_members', `${RELAY_UID}_${OTHER_HH}`),
        memberDoc(RELAY_UID, OTHER_HH, { joined_via: CODE })
      )
    );
  });

  test('an anonymous (no-email) user CAN still redeem a code', async () => {
    // Guest sessions have no token email at all — the code path must not
    // depend on one, or guest-first onboarding breaks.
    const db = ctxFor('uid-guest', null);
    await assertSucceeds(
      setDoc(
        doc(db, 'household_members', `uid-guest_${HH}`),
        memberDoc('uid-guest', HH, { joined_via: CODE })
      )
    );
  });
});

describe('reading a member doc that does not exist', () => {
  // Field lesson (2026-08-09 E2E): a GET on a missing document evaluates the
  // read rule with `resource` == null, so `resource.data.user_id` is an
  // evaluation error — PERMISSION_DENIED, not an empty result. Any client
  // "am I already a member?" pre-check must be a query, never a get.
  test('a GET on a non-existent member doc is DENIED, not empty', async () => {
    const db = ctxFor(JOINER_MISS_UID, 'miss@example.com');
    await assertFails(
      getDoc(doc(db, 'household_members', `${JOINER_MISS_UID}_${HH}`))
    );
  });

  test('the equivalent QUERY succeeds and returns nothing', async () => {
    const db = ctxFor(JOINER_MISS_UID, 'miss@example.com');
    await assertSucceeds(
      getDocs(
        query(
          collection(db, 'household_members'),
          where('user_id', '==', JOINER_MISS_UID),
          where('household_id', '==', HH)
        )
      )
    );
  });
});

describe('still self-only', () => {
  test('a valid code CANNOT be used to add somebody else', async () => {
    const db = ctxFor(RELAY_UID, RELAY_EMAIL);
    await assertFails(
      setDoc(
        doc(db, 'household_members', `victim_${HH}`),
        memberDoc('victim', HH, { joined_via: CODE })
      )
    );
  });
});
