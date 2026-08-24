/**
 * Rules tests for the authority boundary on `household_members` and
 * `households` — added 2026-08-24.
 *
 * Until now `household_members` allowed `update, delete` to ANY member of the
 * household. That was tolerable while every member was a person who had been
 * invited by another person. It stopped being tolerable in 1.7.0, when
 * "Connect an AI" made an assistant a member like any other: a paired
 * assistant could evict the household's own people, and the app would show
 * them as gone.
 *
 * Closing it needs three rules, not one, because the obvious anchor for
 * "admin" was forgeable twice over:
 *
 *   1. `household_members.role` is written by the CLIENT. Anyone holding a
 *      valid join code could have set `role: 'admin'` on their own row. So
 *      create now pins the role, and authority is anchored on
 *      `households.created_by` instead.
 *   2. `households` allowed `update` to any member, and `created_by` is a
 *      plain field — so a member could rewrite it and promote themselves.
 *      It is frozen now.
 *   3. Only then does "delete is self-or-owner" mean anything.
 *
 * Every test here is paired: the thing that must be refused, and the
 * neighbouring thing that must still work. A suite that only asserts denials
 * passes just as well against a rules file that denies everything.
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
  setDoc,
  updateDoc,
  deleteDoc,
  writeBatch,
  setLogLevel,
} = require('firebase/firestore');

const HH = 'hh-authority';
const OWNER = 'uid-owner';
const MEMBER = 'uid-member';
const ASSISTANT = 'uid-assistant';
const CODE = 'JOINCODE';

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

async function seed(setupFn) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setupFn(ctx.firestore());
  });
}

/** Owner + one plain member + one assistant, all committed. */
async function seedHousehold() {
  await seed(async (db) => {
    await setDoc(doc(db, 'households', HH), {
      created_by: OWNER,
      name: 'encrypted-name',
    });
    await setDoc(doc(db, 'household_members', `${OWNER}_${HH}`), {
      user_id: OWNER,
      household_id: HH,
      role: 'admin',
    });
    await setDoc(doc(db, 'household_members', `${MEMBER}_${HH}`), {
      user_id: MEMBER,
      household_id: HH,
      role: 'member',
    });
    await setDoc(doc(db, 'household_members', `${ASSISTANT}_${HH}`), {
      user_id: ASSISTANT,
      household_id: HH,
      role: 'assistant',
    });
  });
}

// ───────────────────────────────────────────────────────────────────────────
describe('household_members delete — self or owner, nobody else', () => {
  test('the assistant CANNOT evict a person (the 1.7.0 hole)', async () => {
    await seedHousehold();
    const ctx = testEnv.authenticatedContext(ASSISTANT);
    await assertFails(
      deleteDoc(doc(ctx.firestore(), 'household_members', `${MEMBER}_${HH}`))
    );
  });

  test('a plain member CANNOT evict another member', async () => {
    await seedHousehold();
    const ctx = testEnv.authenticatedContext(MEMBER);
    await assertFails(
      deleteDoc(doc(ctx.firestore(), 'household_members', `${OWNER}_${HH}`))
    );
  });

  test('the owner CAN remove a member', async () => {
    await seedHousehold();
    const ctx = testEnv.authenticatedContext(OWNER);
    await assertSucceeds(
      deleteDoc(doc(ctx.firestore(), 'household_members', `${MEMBER}_${HH}`))
    );
  });

  test('a plain member CAN still leave (delete their own row)', async () => {
    await seedHousehold();
    const ctx = testEnv.authenticatedContext(MEMBER);
    await assertSucceeds(
      deleteDoc(doc(ctx.firestore(), 'household_members', `${MEMBER}_${HH}`))
    );
  });

  test('the assistant CAN still delete its own row', async () => {
    await seedHousehold();
    const ctx = testEnv.authenticatedContext(ASSISTANT);
    await assertSucceeds(
      deleteDoc(doc(ctx.firestore(), 'household_members', `${ASSISTANT}_${HH}`))
    );
  });

  // Burn's orphan sweep deletes legacy member docs that never had a
  // household_id. isHouseholdOwner() cannot be asked about a household that is
  // not named, so the self branch has to stand on its own, first and
  // unconditional. This is the test that catches a rewrite that reorders them.
  test('burn orphan sweep: own member doc with NO household_id still deletes', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'household_members', 'orphan_legacy'), {
        user_id: MEMBER,
      });
    });
    const ctx = testEnv.authenticatedContext(MEMBER);
    await assertSucceeds(
      deleteDoc(doc(ctx.firestore(), 'household_members', 'orphan_legacy'))
    );
  });

  test('a stranger CANNOT delete an orphan doc belonging to someone else', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'household_members', 'orphan_legacy'), {
        user_id: MEMBER,
      });
    });
    const ctx = testEnv.authenticatedContext('uid-stranger');
    await assertFails(
      deleteDoc(doc(ctx.firestore(), 'household_members', 'orphan_legacy'))
    );
  });
});

// ───────────────────────────────────────────────────────────────────────────
describe('household_members update — self only, identity and role frozen', () => {
  test('a member CANNOT rewrite another member row', async () => {
    await seedHousehold();
    const ctx = testEnv.authenticatedContext(MEMBER);
    await assertFails(
      updateDoc(doc(ctx.firestore(), 'household_members', `${OWNER}_${HH}`), {
        role: 'member',
      })
    );
  });

  test('a member CANNOT promote THEMSELVES to admin', async () => {
    await seedHousehold();
    const ctx = testEnv.authenticatedContext(MEMBER);
    await assertFails(
      updateDoc(doc(ctx.firestore(), 'household_members', `${MEMBER}_${HH}`), {
        role: 'admin',
      })
    );
  });

  test('a member CAN touch their own row without changing identity or role', async () => {
    await seedHousehold();
    const ctx = testEnv.authenticatedContext(MEMBER);
    await assertSucceeds(
      updateDoc(doc(ctx.firestore(), 'household_members', `${MEMBER}_${HH}`), {
        last_seen_at: 'whenever',
      })
    );
  });

  test('a member CANNOT move their own row into another household', async () => {
    await seedHousehold();
    const ctx = testEnv.authenticatedContext(MEMBER);
    await assertFails(
      updateDoc(doc(ctx.firestore(), 'household_members', `${MEMBER}_${HH}`), {
        household_id: 'hh-somewhere-else',
      })
    );
  });
});

// ───────────────────────────────────────────────────────────────────────────
describe('household_members create — the claimed role must be one you may claim', () => {
  test('joining with a code CANNOT claim admin', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'households', HH), { created_by: OWNER });
      await setDoc(doc(db, 'household_join_codes', CODE), {
        household_id: HH,
        expires_at: new Date(Date.now() + 7 * 864e5),
      });
    });
    const ctx = testEnv.authenticatedContext('uid-joiner');
    await assertFails(
      setDoc(doc(ctx.firestore(), 'household_members', `uid-joiner_${HH}`), {
        user_id: 'uid-joiner',
        household_id: HH,
        role: 'admin',
        joined_via: CODE,
      })
    );
  });

  test('joining with the same code as a member SUCCEEDS', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'households', HH), { created_by: OWNER });
      await setDoc(doc(db, 'household_join_codes', CODE), {
        household_id: HH,
        expires_at: new Date(Date.now() + 7 * 864e5),
      });
    });
    const ctx = testEnv.authenticatedContext('uid-joiner');
    await assertSucceeds(
      setDoc(doc(ctx.firestore(), 'household_members', `uid-joiner_${HH}`), {
        user_id: 'uid-joiner',
        household_id: HH,
        role: 'member',
        joined_via: CODE,
      })
    );
  });

  // The founding write is the one place 'admin' is truthful, and createHousehold
  // commits both docs in ONE batch — rules never see a batch's own uncommitted
  // writes, so the household genuinely does not exist yet at evaluation time.
  test('founding a household in one batch CAN claim admin', async () => {
    const ctx = testEnv.authenticatedContext('uid-founder');
    const db = ctx.firestore();
    const batch = writeBatch(db);
    batch.set(doc(db, 'households', 'hh-new'), { created_by: 'uid-founder' });
    batch.set(doc(db, 'household_members', `uid-founder_hh-new`), {
      user_id: 'uid-founder',
      household_id: 'hh-new',
      role: 'admin',
    });
    await assertSucceeds(batch.commit());
  });
});

// ───────────────────────────────────────────────────────────────────────────
describe('households.created_by is frozen after creation', () => {
  test('a member CANNOT rewrite created_by to promote themselves', async () => {
    await seedHousehold();
    const ctx = testEnv.authenticatedContext(MEMBER);
    await assertFails(
      updateDoc(doc(ctx.firestore(), 'households', HH), { created_by: MEMBER })
    );
  });

  test('the assistant CANNOT rewrite created_by either', async () => {
    await seedHousehold();
    const ctx = testEnv.authenticatedContext(ASSISTANT);
    await assertFails(
      updateDoc(doc(ctx.firestore(), 'households', HH), {
        created_by: ASSISTANT,
      })
    );
  });

  test('renaming the household still works (the app updates `name` only)', async () => {
    await seedHousehold();
    const ctx = testEnv.authenticatedContext(MEMBER);
    await assertSucceeds(
      updateDoc(doc(ctx.firestore(), 'households', HH), {
        name: 'new-encrypted-name',
      })
    );
  });

  test('even the owner cannot hand created_by to someone else', async () => {
    await seedHousehold();
    const ctx = testEnv.authenticatedContext(OWNER);
    await assertFails(
      updateDoc(doc(ctx.firestore(), 'households', HH), { created_by: MEMBER })
    );
  });
});
