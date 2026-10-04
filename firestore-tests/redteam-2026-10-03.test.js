/**
 * Exploit sequences from the 2026-10-03 rules red-team
 * (AUDIT_2026-10-03_rules_redteam.md). Every `assertFails` here was written
 * BEFORE the fix and was watched passing the attack against the old rules.
 *
 * Cast: ATTACKER is a genuine member of household A and knows household B's
 * ID (an ex-member, a removed member, anyone who was shown it). VICTIM owns B.
 */
const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc, collection, query, where, getDoc, getDocs,
  setDoc, updateDoc, deleteDoc, writeBatch, Timestamp, setLogLevel,
} = require('firebase/firestore');

const A = 'hh-a';
const B = 'hh-b';
const ATTACKER = 'uid-attacker';
const ATTACKER_EMAIL = 'attacker@example.com';
const VICTIM = 'uid-victim';
const CODE = 'K7QP4M2X';
const INVITE_A = 'invite-a';
const OLD_INVITE_B = 'invite-b-old';
const DAY = 24 * 60 * 60 * 1000;
const future = (ms) => Timestamp.fromMillis(Date.now() + ms);
const past = (ms) => Timestamp.fromMillis(Date.now() - ms);

// Every collection whose rule is the plain member read/update/delete pattern.
const CONTENT = [
  'tasks', 'subtasks', 'task_categories', 'checklists', 'checklist_items',
  'checklist_templates', 'scratch_plans', 'plan_entries', 'plan_checklist_items',
  'task_attachments', 'plan_attachments', 'inventory_items',
  'inventory_categories', 'inventory_locations', 'inventory_logs',
  'inventory_attachments', 'manual_entries', 'manual_categories', 'diagnostics',
];

let testEnv;

beforeAll(async () => {
  setLogLevel('error');
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-pacelli',
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });
});

afterAll(async () => { await testEnv.cleanup(); });

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const hh = (id, owner) => setDoc(doc(db, 'households', id), {
      id, name: 'enc:blob', created_by: owner, created_at: '2026-08-01T10:00:00.000Z',
    });
    const member = (uid, hid, role = 'member') =>
      setDoc(doc(db, 'household_members', `${uid}_${hid}`), {
        user_id: uid, household_id: hid, role, joined_at: '2026-08-01T10:00:00.000Z',
      });
    await hh(A, ATTACKER);
    await hh(B, VICTIM);
    await member(ATTACKER, A, 'admin');
    await member(VICTIM, B, 'admin');

    await setDoc(doc(db, 'household_join_codes', CODE), {
      household_id: A, encrypted_key: 'wrapped', created_by: ATTACKER,
      created_at: past(60_000), expires_at: future(7 * DAY),
    });
    await setDoc(doc(db, 'household_invites', INVITE_A), {
      id: INVITE_A, household_id: A, invited_email: 'friend@example.com',
      invited_by: ATTACKER, status: 'pending', created_at: '2026-10-01T10:00:00.000Z',
    });
    // The attacker was once invited into B, accepted, and has since been removed.
    await setDoc(doc(db, 'household_invites', OLD_INVITE_B), {
      id: OLD_INVITE_B, household_id: B, invited_email: ATTACKER_EMAIL,
      invited_by: VICTIM, status: 'accepted', created_at: '2026-09-01T10:00:00.000Z',
    });

    for (const c of CONTENT) {
      await setDoc(doc(db, c, `${c}-a`), { id: `${c}-a`, household_id: A, title: 'enc:x' });
    }
    await setDoc(doc(db, 'photos', 'photo-a'), {
      id: 'photo-a', household_id: A, created_by: ATTACKER, storage_path: 'p/a.enc',
    });
    await setDoc(doc(db, 'weekly_digests', `${B}_2026-09-28`), {
      id: `${B}_2026-09-28`, household_id: B, week_starting: '2026-09-28', tasks_created: 4,
    });
    await setDoc(doc(db, 'weekly_digests', `${A}_2026-09-28`), {
      id: `${A}_2026-09-28`, household_id: A, week_starting: '2026-09-28', tasks_created: 1,
    });
    await setDoc(doc(db, 'profiles', VICTIM), {
      full_name: 'enc:name', avatar_url: 'https://lh3.googleusercontent.com/victim',
    });
  });
});

const attacker = () => testEnv
  .authenticatedContext(ATTACKER, { email: ATTACKER_EMAIL, email_verified: true })
  .firestore();

describe('C1 - join codes cannot be retargeted', () => {
  test('a member CANNOT point their code at another household', async () => {
    await assertFails(updateDoc(doc(attacker(), 'household_join_codes', CODE), { household_id: B }));
  });
  test('a member CANNOT extend a code past the 8-day window', async () => {
    await assertFails(updateDoc(doc(attacker(), 'household_join_codes', CODE),
      { expires_at: future(365 * DAY) }));
  });
  test('a member CANNOT overwrite a code with setDoc either', async () => {
    await assertFails(setDoc(doc(attacker(), 'household_join_codes', CODE), {
      household_id: B, encrypted_key: 'x', created_by: ATTACKER,
      created_at: past(1000), expires_at: future(DAY),
    }));
  });
  test('regression: a member CAN still delete (revoke) their code', async () => {
    await assertSucceeds(deleteDoc(doc(attacker(), 'household_join_codes', CODE)));
  });
});

describe('C2 - invites cannot be retargeted or replayed', () => {
  test('a member CANNOT retarget an invite to another household', async () => {
    await assertFails(updateDoc(doc(attacker(), 'household_invites', INVITE_A), {
      household_id: B, invited_email: ATTACKER_EMAIL,
    }));
  });
  test('a member CANNOT readdress an invite to a different email', async () => {
    await assertFails(updateDoc(doc(attacker(), 'household_invites', INVITE_A),
      { invited_email: ATTACKER_EMAIL }));
  });
  test('a member CANNOT flip an accepted invite back to pending', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), 'household_invites', INVITE_A), { status: 'accepted' });
    });
    await assertFails(updateDoc(doc(attacker(), 'household_invites', INVITE_A), { status: 'pending' }));
  });
  test('a removed member CANNOT rejoin by replaying their old accepted invite', async () => {
    await assertFails(setDoc(doc(attacker(), 'household_members', `${ATTACKER}_${B}`), {
      user_id: ATTACKER, household_id: B, role: 'member',
      joined_at: '2026-10-03T10:00:00.000Z', joined_via: OLD_INVITE_B,
    }));
  });
});

describe('M1 - content cannot be moved between households', () => {
  for (const c of CONTENT) {
    test(`${c}: a member CANNOT move a doc into another household`, async () => {
      await assertFails(updateDoc(doc(attacker(), c, `${c}-a`), { household_id: B }));
    });
  }
  test('regression: a member CAN still edit content in place', async () => {
    await assertSucceeds(updateDoc(doc(attacker(), 'tasks', 'tasks-a'), { title: 'enc:y' }));
  });
});

describe('Mo1 - photos keep their household and author', () => {
  test('a member CANNOT move a photo into another household', async () => {
    await assertFails(updateDoc(doc(attacker(), 'photos', 'photo-a'), { household_id: B }));
  });
  test('a member CANNOT rewrite who took a photo', async () => {
    await assertFails(updateDoc(doc(attacker(), 'photos', 'photo-a'), { created_by: VICTIM }));
  });
});

describe('M2 - weekly digests', () => {
  test('a member of A CANNOT take over B\'s digest (guessable id)', async () => {
    await assertFails(updateDoc(doc(attacker(), 'weekly_digests', `${B}_2026-09-28`),
      { household_id: A }));
  });
  test('a client CANNOT forge a digest (only the server writes them)', async () => {
    await assertFails(setDoc(doc(attacker(), 'weekly_digests', `${A}_2026-10-05`),
      { id: `${A}_2026-10-05`, household_id: A, tasks_created: 999 }));
  });
  test('a member CAN delete their own household\'s digest - the client wipe depends on it', async () => {
    await assertSucceeds(deleteDoc(doc(attacker(), 'weekly_digests', `${A}_2026-09-28`)));
  });
  test('a member CANNOT delete another household\'s digest', async () => {
    await assertFails(deleteDoc(doc(attacker(), 'weekly_digests', `${B}_2026-09-28`)));
  });
});

describe('Mi1 - profiles cannot be enumerated', () => {
  test('a signed-in stranger CANNOT list every profile', async () => {
    await assertFails(getDocs(collection(attacker(), 'profiles')));
  });
  test('an anonymous guest CANNOT list every profile', async () => {
    const guest = testEnv.authenticatedContext('uid-guest', {}).firestore();
    await assertFails(getDocs(collection(guest, 'profiles')));
  });
  test('regression: a signed-in user CAN still get a profile by exact uid', async () => {
    await assertSucceeds(getDoc(doc(attacker(), 'profiles', VICTIM)));
  });
});

// Found 2026-10-04 by the cold re-review, NOT in the original audit.
// isMember(H) only asks whether a doc NAMED {uid}_{H} exists, and the create
// rule never tied the doc ID to the body.
describe('X1 - membership cannot be forged through the document ID', () => {
  const guest = () => testEnv.authenticatedContext('uid-guest', {}).firestore();
  test('a guest CANNOT name a doc {uid}_B while founding an unused household', async () => {
    await assertFails(setDoc(doc(guest(), 'household_members', `uid-guest_${B}`), {
      user_id: 'uid-guest', household_id: 'hh-fresh-unused', role: 'admin',
      joined_at: '2026-10-04T10:00:00.000Z',
    }));
  });
  test('a member of A CANNOT name a doc {uid}_B with household_id A', async () => {
    await assertFails(setDoc(doc(attacker(), 'household_members', `${ATTACKER}_${B}`), {
      user_id: ATTACKER, household_id: A, role: 'member',
      joined_at: '2026-10-04T10:00:00.000Z',
    }));
  });
  test('the forged doc, if it existed, would really grant B (why X1 is critical)', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'household_members', `uid-guest_${B}`), {
        user_id: 'uid-guest', household_id: 'hh-fresh-unused', role: 'admin',
      });
      await setDoc(doc(ctx.firestore(), 'tasks', 'task-b'), { id: 'task-b', household_id: B, title: 'enc:b' });
    });
    await assertSucceeds(getDoc(doc(guest(), 'tasks', 'task-b')));
  });
});

describe('C2 residual - an invite only counts if this same write accepts it', () => {
  const invited = () => testEnv
    .authenticatedContext('uid-friend', { email: 'friend@example.com', email_verified: true })
    .firestore();
  const member = () => ({
    user_id: 'uid-friend', household_id: A, role: 'member',
    joined_at: '2026-10-04T10:00:00.000Z', joined_via: INVITE_A,
  });
  test('the invitee CANNOT join on the invite and leave it pending', async () => {
    await assertFails(setDoc(doc(invited(), 'household_members', `uid-friend_${A}`), member()));
  });
  test('regression: the shipped accept batch still commits', async () => {
    const db = invited();
    const batch = writeBatch(db);
    batch.set(doc(db, 'household_members', `uid-friend_${A}`), member());
    batch.update(doc(db, 'household_invites', INVITE_A), { status: 'accepted' });
    await assertSucceeds(batch.commit());
  });
});

// Decided 2026-10-04 (Juan): an email invite only works for a VERIFIED email.
// Otherwise anyone could sign up with email/password as the invited address,
// read the invite (whose key is wrapped under that address) and accept it.
describe('E1 - email invites need a verified email', () => {
  const squatter = () => testEnv
    .authenticatedContext('uid-squatter', { email: 'friend@example.com', email_verified: false })
    .firestore();
  const member = () => ({
    user_id: 'uid-squatter', household_id: A, role: 'member',
    joined_at: '2026-10-04T10:00:00.000Z', joined_via: INVITE_A,
  });
  test('an unverified account CANNOT read the invite addressed to its email', async () => {
    await assertFails(getDoc(doc(squatter(), 'household_invites', INVITE_A)));
  });
  test('an unverified account CANNOT query invites by its email', async () => {
    await assertFails(getDocs(query(collection(squatter(), 'household_invites'),
      where('invited_email', '==', 'friend@example.com'), where('status', '==', 'pending'))));
  });
  test('an unverified account CANNOT accept the invite (the shipped batch)', async () => {
    const db = squatter();
    const batch = writeBatch(db);
    batch.set(doc(db, 'household_members', `uid-squatter_${A}`), member());
    batch.update(doc(db, 'household_invites', INVITE_A), { status: 'accepted' });
    await assertFails(batch.commit());
  });
});
