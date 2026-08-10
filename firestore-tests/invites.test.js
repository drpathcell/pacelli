/**
 * Rules tests for the household invite → acceptance handshake.
 *
 * Field failure (2026-08-09): an invited user installed the app, signed in
 * with the invited email, and silently landed in a brand-new empty household
 * instead of the inviter's one.
 *
 * Root cause locked by these tests: `MembershipService.checkAndAcceptInvite`
 * commits ONE batch that (a) creates `household_members/{uid}_{hh}` and
 * (b) flips the invite to `status: accepted`. Security rules never see the
 * uncommitted writes of their own batch, so (b) is evaluated while the caller
 * is still a non-member — `isMember()` is false, the whole batch is denied,
 * and the client swallows the error and auto-provisions a fresh household.
 *
 * The rules must therefore let the INVITED user flip their own invite to
 * accepted — and nothing else.
 *
 * Run with: `npm test` (spins up the Firestore emulator automatically).
 */

const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { GRACE_ACTIVE } = require('./grace');
const {
  doc,
  collection,
  query,
  where,
  getDocs,
  setDoc,
  updateDoc,
  writeBatch,
  setLogLevel,
} = require('firebase/firestore');

const HH = 'hh-1';
const OWNER_UID = 'uid-owner';
const INVITEE_UID = 'uid-invitee';
const INVITEE_EMAIL = 'invitee@example.com';
const STRANGER_UID = 'uid-stranger';
const STRANGER_EMAIL = 'stranger@example.com';
const INVITE_ID = 'invite-1';

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
      created_by: OWNER_UID,
      created_at: '2026-08-01T10:00:00.000Z',
    });
    await setDoc(doc(db, 'household_members', `${OWNER_UID}_${HH}`), {
      user_id: OWNER_UID,
      household_id: HH,
      role: 'admin',
      joined_at: '2026-08-01T10:00:00.000Z',
    });
    await setDoc(doc(db, 'household_invites', INVITE_ID), {
      id: INVITE_ID,
      household_id: HH,
      invited_email: INVITEE_EMAIL,
      invited_by: OWNER_UID,
      status: 'pending',
      created_at: '2026-08-09T10:00:00.000Z',
      encrypted_key: 'wrapped-household-key',
    });
  });
});

function invitee() {
  return testEnv
    .authenticatedContext(INVITEE_UID, {
      email: INVITEE_EMAIL,
      email_verified: true,
    })
    .firestore();
}

function stranger() {
  return testEnv
    .authenticatedContext(STRANGER_UID, {
      email: STRANGER_EMAIL,
      email_verified: true,
    })
    .firestore();
}

/** Exactly what MembershipService.checkAndAcceptInvite commits. */
function acceptBatch(db) {
  const batch = writeBatch(db);
  batch.set(doc(db, 'household_members', `${INVITEE_UID}_${HH}`), {
    user_id: INVITEE_UID,
    household_id: HH,
    role: 'member',
    joined_at: '2026-08-09T11:00:00.000Z',
    joined_via: INVITE_ID,
  });
  batch.update(doc(db, 'household_invites', INVITE_ID), { status: 'accepted' });
  return batch.commit();
}

describe('household_invites — discovery', () => {
  test('invitee CAN query their own pending invite by email', async () => {
    const db = invitee();
    await assertSucceeds(
      getDocs(
        query(
          collection(db, 'household_invites'),
          where('invited_email', '==', INVITEE_EMAIL),
          where('status', '==', 'pending')
        )
      )
    );
  });

  test('a stranger CANNOT read an invite addressed to someone else', async () => {
    const db = stranger();
    await assertFails(
      getDocs(
        query(
          collection(db, 'household_invites'),
          where('invited_email', '==', INVITEE_EMAIL),
          where('status', '==', 'pending')
        )
      )
    );
  });
});

describe('household_invites — acceptance (the shipped batch)', () => {
  test('invitee CAN create their own member doc on its own', async () => {
    const db = invitee();
    await assertSucceeds(
      setDoc(doc(db, 'household_members', `${INVITEE_UID}_${HH}`), {
        user_id: INVITEE_UID,
        household_id: HH,
        role: 'member',
        joined_at: '2026-08-09T11:00:00.000Z',
        joined_via: INVITE_ID,
      })
    );
  });

  test('invitee CANNOT create a member doc WITHOUT naming the invite', async () => {
    const db = invitee();
    await (GRACE_ACTIVE ? assertSucceeds : assertFails)(
      setDoc(doc(db, 'household_members', `${INVITEE_UID}_${HH}`), {
        user_id: INVITEE_UID,
        household_id: HH,
        role: 'member',
        joined_at: '2026-08-09T11:00:00.000Z',
      })
    );
  });

  test('invitee CAN commit the accept batch (member doc + status flip)', async () => {
    await assertSucceeds(acceptBatch(invitee()));
  });

  test('invitee CAN flip only their own invite status to accepted', async () => {
    const db = invitee();
    await assertSucceeds(
      updateDoc(doc(db, 'household_invites', INVITE_ID), { status: 'accepted' })
    );
  });

  test('invitee CANNOT rewrite any other field while accepting', async () => {
    const db = invitee();
    await assertFails(
      updateDoc(doc(db, 'household_invites', INVITE_ID), {
        status: 'accepted',
        household_id: 'hh-someone-elses',
      })
    );
    await assertFails(
      updateDoc(doc(db, 'household_invites', INVITE_ID), {
        status: 'accepted',
        encrypted_key: 'attacker-supplied',
      })
    );
    await assertFails(
      updateDoc(doc(db, 'household_invites', INVITE_ID), {
        status: 'accepted',
        invited_email: STRANGER_EMAIL,
      })
    );
  });

  test('invitee CANNOT set an arbitrary status', async () => {
    const db = invitee();
    await assertFails(
      updateDoc(doc(db, 'household_invites', INVITE_ID), { status: 'pending' })
    );
    await assertFails(
      updateDoc(doc(db, 'household_invites', INVITE_ID), { status: 'admin' })
    );
  });

  test('a stranger CANNOT accept an invite addressed to another email', async () => {
    const db = stranger();
    await assertFails(
      updateDoc(doc(db, 'household_invites', INVITE_ID), { status: 'accepted' })
    );
  });

  test('an already-accepted invite CANNOT be re-accepted (no replay)', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(
        doc(ctx.firestore(), 'household_invites', INVITE_ID),
        { status: 'accepted' }
      );
    });
    const db = invitee();
    await assertFails(
      updateDoc(doc(db, 'household_invites', INVITE_ID), { status: 'accepted' })
    );
  });

  test('invitee CANNOT delete the invite (revoke stays a member action)', async () => {
    const db = invitee();
    const { deleteDoc } = require('firebase/firestore');
    await assertFails(deleteDoc(doc(db, 'household_invites', INVITE_ID)));
  });
});

describe('household_keys — the invite key handshake', () => {
  test('invitee CAN write their own re-wrapped household key', async () => {
    const db = invitee();
    await assertSucceeds(
      setDoc(doc(db, 'household_keys', 'k1'), {
        household_id: HH,
        user_id: INVITEE_UID,
        encrypted_key: 'rewrapped',
      })
    );
  });

  test('invitee CANNOT write a key doc owned by another user', async () => {
    const db = invitee();
    await assertFails(
      setDoc(doc(db, 'household_keys', 'k2'), {
        household_id: HH,
        user_id: OWNER_UID,
        encrypted_key: 'rewrapped',
      })
    );
  });
});
