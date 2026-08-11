/**
 * Rules tests for `feedback` — the one collection where a STRANGER writes to
 * us.
 *
 * Two things were wrong before 2026-08-11, and this file locks both fixes:
 *
 *   1. `create` required `isMember(request.resource.data.household_id)`. A
 *      fresh install's ability to report a bug therefore depended on
 *      household state that may not have settled. Now it only requires a
 *      signed-in user who pins `created_by` to their own uid.
 *
 *   2. Nothing stopped a submitted report being rewritten afterwards.
 *
 * Read and delete deliberately stay keyed to household membership: burn and
 * discardOwnEmptyHouseholds both sweep every content collection with a
 * `household_id ==` query, and narrowing this to created_by would deny those
 * queries and break burn. There is nothing to protect by narrowing it — the
 * message is sealed to the Pacelli public key, so a member who fetches one
 * gets ciphertext they hold no key for.
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
  updateDoc,
  deleteDoc,
  setLogLevel,
} = require('firebase/firestore');

const HH = 'hh-1';
const MEMBER_UID = 'uid-member';
const STRANGER_UID = 'uid-stranger';
const STRANGER_HH = 'hh-stranger';

// What the app actually writes now: sealed to the Pacelli public key.
const SEALED = 'pfb1:aGVsbG8td29ybGQtdGhpcy1pcy1ub3QtcmVhbC1jaXBoZXJ0ZXh0';

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
      created_by: MEMBER_UID,
      created_at: '2026-08-01T10:00:00.000Z',
    });
    await setDoc(doc(db, 'household_members', `${MEMBER_UID}_${HH}`), {
      user_id: MEMBER_UID,
      household_id: HH,
      role: 'admin',
      joined_at: '2026-08-01T10:00:00.000Z',
    });
    await setDoc(doc(db, 'feedback', 'fb-existing'), {
      id: 'fb-existing',
      household_id: HH,
      type: 'bug',
      rating: 'negative',
      message: SEALED,
      context: null,
      created_by: MEMBER_UID,
      created_at: '2026-08-01T11:00:00.000Z',
    });
  });
});

const member = () => testEnv.authenticatedContext(MEMBER_UID).firestore();
const stranger = () => testEnv.authenticatedContext(STRANGER_UID).firestore();
const anon = () => testEnv.unauthenticatedContext().firestore();

const entry = (overrides = {}) => ({
  id: 'fb-new',
  household_id: STRANGER_HH,
  type: 'bug',
  rating: 'negative',
  message: SEALED,
  context: null,
  created_by: STRANGER_UID,
  created_at: '2026-08-11T13:00:00.000Z',
  ...overrides,
});

describe('a stranger can report a bug', () => {
  // The regression that mattered: this used to require isMember().
  test('signed-in stranger, no membership anywhere, can create', async () => {
    await assertSucceeds(
      setDoc(doc(stranger(), 'feedback', 'fb-new'), entry())
    );
  });

  test('household_id it does not belong to is irrelevant to create', async () => {
    await assertSucceeds(
      setDoc(doc(stranger(), 'feedback', 'fb-new'), entry({ household_id: HH }))
    );
  });

  test('signed out cannot create', async () => {
    await assertFails(
      setDoc(doc(anon(), 'feedback', 'fb-new'), entry({ created_by: null }))
    );
  });
});

describe('the document shape is pinned', () => {
  // Dropping isMember() opened create to every signed-in user on the
  // internet. The document itself is the only thing left constraining them.
  test('rejects an unknown field', async () => {
    await assertFails(
      setDoc(
        doc(stranger(), 'feedback', 'fb-new'),
        entry({ exfiltrate: 'x'.repeat(100) })
      )
    );
  });

  test('rejects an unknown type', async () => {
    await assertFails(
      setDoc(doc(stranger(), 'feedback', 'fb-new'), entry({ type: 'whatever' }))
    );
  });

  test('rejects an unknown rating', async () => {
    await assertFails(
      setDoc(doc(stranger(), 'feedback', 'fb-new'), entry({ rating: '11/10' }))
    );
  });

  test('rejects a message over the size cap', async () => {
    await assertFails(
      setDoc(
        doc(stranger(), 'feedback', 'fb-new'),
        entry({ message: 'x'.repeat(100001) })
      )
    );
  });

  test('rejects a non-string message', async () => {
    await assertFails(
      setDoc(doc(stranger(), 'feedback', 'fb-new'), entry({ message: 42 }))
    );
  });

  // The version live on the App Store today still writes household-key
  // ciphertext with no "pfb1:" prefix. Rejecting it here would break "send
  // feedback" for every user on the current build.
  test('still accepts a legacy unprefixed message — the live build sends those', async () => {
    await assertSucceeds(
      setDoc(
        doc(stranger(), 'feedback', 'fb-new'),
        entry({ message: 'xx4FBshorZN3kJiaKZ73X0dVfZ/CvI5lneaeorKDK6LdlIDyhVdcdYo9Qs/Uko01' })
      )
    );
  });
});

describe('entries stay attributable and immutable', () => {
  test('cannot forge created_by as someone else', async () => {
    await assertFails(
      setDoc(
        doc(stranger(), 'feedback', 'fb-new'),
        entry({ created_by: MEMBER_UID })
      )
    );
  });

  test('cannot rewrite a submitted report — not even your own', async () => {
    await assertFails(
      updateDoc(doc(member(), 'feedback', 'fb-existing'), {
        message: 'pfb1:something-else',
      })
    );
  });

  test('cannot rewrite someone else’s report', async () => {
    await assertFails(
      updateDoc(doc(stranger(), 'feedback', 'fb-existing'), { rating: 'positive' })
    );
  });
});

describe('reads stay inside the household', () => {
  test('a stranger cannot read an entry', async () => {
    await assertFails(getDoc(doc(stranger(), 'feedback', 'fb-existing')));
  });

  test('a stranger cannot enumerate the collection', async () => {
    await assertFails(
      getDocs(
        query(collection(stranger(), 'feedback'), where('household_id', '==', HH))
      )
    );
  });

  // Burn and discardOwnEmptyHouseholds depend on exactly this query shape.
  // If it ever fails, burn-all-data fails with it.
  test('a member CAN sweep by household_id — burn depends on it', async () => {
    await assertSucceeds(
      getDocs(
        query(collection(member(), 'feedback'), where('household_id', '==', HH))
      )
    );
  });

  test('a member CAN delete their household’s entries — burn depends on it', async () => {
    await assertSucceeds(deleteDoc(doc(member(), 'feedback', 'fb-existing')));
  });

  test('a stranger cannot delete an entry', async () => {
    await assertFails(deleteDoc(doc(stranger(), 'feedback', 'fb-existing')));
  });
});
