/**
 * Rules tests for `device_tokens` — the push target registry.
 *
 * A row here says "send this household's activity to this device". That makes
 * it the one place where push could leak what the encryption protects: if a
 * stranger can register their own device against someone else's household_id,
 * they get pushed that household's notifications without ever touching a
 * ciphertext.
 *
 * So the properties locked here are:
 *   1. create/update require isMember(household_id) — you can only receive a
 *      household's pushes if you are actually in it.
 *   2. Nobody can read or enumerate another user's tokens.
 *   3. update checks BOTH the existing row and the incoming one, so knowing a
 *      token is not enough to take over its pushes.
 *   4. delete works for your own rows — sign-out and burn depend on it, and a
 *      token that cannot be deleted keeps pushing forever.
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
const OTHER_HH = 'hh-2';
const MEMBER_UID = 'uid-member';
const STRANGER_UID = 'uid-stranger';
const TOKEN = 'fcm-token-member-device';
const OTHER_TOKEN = 'fcm-token-stranger-device';

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
    // The stranger is a real user — just not in HH.
    await setDoc(doc(db, 'household_members', `${STRANGER_UID}_${OTHER_HH}`), {
      user_id: STRANGER_UID,
      household_id: OTHER_HH,
      role: 'admin',
      joined_at: '2026-08-01T10:00:00.000Z',
    });
    await setDoc(doc(db, 'device_tokens', TOKEN), {
      token: TOKEN,
      user_id: MEMBER_UID,
      household_id: HH,
      platform: 'ios',
      app_version: '1.3.1',
      updated_at: '2026-08-11T10:00:00.000Z',
    });
  });
});

const member = () => testEnv.authenticatedContext(MEMBER_UID).firestore();
const stranger = () => testEnv.authenticatedContext(STRANGER_UID).firestore();
const anon = () => testEnv.unauthenticatedContext().firestore();

const row = (overrides = {}) => ({
  token: OTHER_TOKEN,
  user_id: STRANGER_UID,
  household_id: OTHER_HH,
  platform: 'ios',
  app_version: '1.3.1',
  updated_at: '2026-08-11T12:00:00.000Z',
  ...overrides,
});

describe('registering a device', () => {
  test('a member can register for their own household', async () => {
    await assertSucceeds(
      setDoc(
        doc(member(), 'device_tokens', 'new-token'),
        row({ token: 'new-token', user_id: MEMBER_UID, household_id: HH })
      )
    );
  });

  test('a stranger can register for a household they ARE in', async () => {
    await assertSucceeds(
      setDoc(doc(stranger(), 'device_tokens', OTHER_TOKEN), row())
    );
  });

  // The one that matters: this is how push would leak a household's activity
  // to someone outside it, without ever breaking the encryption.
  test('a stranger CANNOT register against a household they are not in', async () => {
    await assertFails(
      setDoc(
        doc(stranger(), 'device_tokens', OTHER_TOKEN),
        row({ household_id: HH })
      )
    );
  });

  test('cannot register a token in someone else’s name', async () => {
    await assertFails(
      setDoc(
        doc(stranger(), 'device_tokens', OTHER_TOKEN),
        row({ user_id: MEMBER_UID, household_id: HH })
      )
    );
  });

  test('signed out cannot register', async () => {
    await assertFails(
      setDoc(doc(anon(), 'device_tokens', 'anon-token'), row({ user_id: null }))
    );
  });

  test('rejects an unknown field', async () => {
    await assertFails(
      setDoc(
        doc(member(), 'device_tokens', 'new-token'),
        row({ token: 'new-token', user_id: MEMBER_UID, household_id: HH, spy: 'x' })
      )
    );
  });
});

describe('nobody sees another user’s tokens', () => {
  test('a stranger cannot read a token row', async () => {
    await assertFails(getDoc(doc(stranger(), 'device_tokens', TOKEN)));
  });

  test('a stranger cannot enumerate a household’s tokens', async () => {
    await assertFails(
      getDocs(
        query(
          collection(stranger(), 'device_tokens'),
          where('household_id', '==', HH)
        )
      )
    );
  });

  test('a user CAN list their own — burn sweeps every device this way', async () => {
    await assertSucceeds(
      getDocs(
        query(
          collection(member(), 'device_tokens'),
          where('user_id', '==', MEMBER_UID)
        )
      )
    );
  });
});

describe('a known token cannot be hijacked', () => {
  // Checking only the incoming data would let someone who learned another
  // device's token rewrite the row to themselves and take over its pushes.
  test('a stranger cannot take over an existing row', async () => {
    await assertFails(
      updateDoc(doc(stranger(), 'device_tokens', TOKEN), {
        user_id: STRANGER_UID,
        household_id: OTHER_HH,
      })
    );
  });

  test('a member can refresh their own row', async () => {
    await assertSucceeds(
      setDoc(
        doc(member(), 'device_tokens', TOKEN),
        row({ token: TOKEN, user_id: MEMBER_UID, household_id: HH })
      )
    );
  });

  test('a member cannot move their row to a household they are not in', async () => {
    await assertFails(
      setDoc(
        doc(member(), 'device_tokens', TOKEN),
        row({ token: TOKEN, user_id: MEMBER_UID, household_id: OTHER_HH })
      )
    );
  });
});

describe('revocation', () => {
  // Sign-out and burn both delete while still authenticated. If this ever
  // fails, a wiped account keeps buzzing.
  test('a user can delete their own token', async () => {
    await assertSucceeds(deleteDoc(doc(member(), 'device_tokens', TOKEN)));
  });

  test('a stranger cannot delete someone else’s token', async () => {
    await assertFails(deleteDoc(doc(stranger(), 'device_tokens', TOKEN)));
  });
});
