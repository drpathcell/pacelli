/**
 * Rules tests for the burn policy on `households` — added 2026-08-25 for
 * 1.10.0.
 *
 * ## What this file does and does not prove
 *
 * It proves that only the household owner can change WHO MAY BURN. It does
 * NOT prove that a restricted member cannot burn, because rules cannot express
 * that: a burn is a few hundred ordinary deletes and every content collection
 * must allow a member to delete a task. That check lives in the
 * `burnHousehold` Cloud Function and is tested in
 * `functions/tests/burn-permission.test.ts`.
 *
 * Saying so here matters. A suite named "burn policy" that only tested this
 * file would leave a reader believing the burn itself was rules-enforced,
 * which was the assumption in the 2026-08-24 design note and it was wrong.
 *
 * NEGATIVE-CONTROL: RUN on 2026-08-25. Removing
 * `(burnPolicyUnchanged() || request.auth.uid == resource.data.created_by)`
 * from the `households` update rule reddens the four denial tests below and
 * leaves the permission tests green — which is the shape a false green would
 * have had before this rule existed.
 *
 * Every test is paired: the thing that must be refused, and the neighbouring
 * thing that must still work. A suite that only asserts denials passes just as
 * well against a rules file that denies everything.
 */

const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, setLogLevel } = require('firebase/firestore');

const HH = 'hh-burn';
const OWNER = 'uid-owner';
const MEMBER = 'uid-member';
const ASSISTANT = 'uid-assistant';

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

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

async function seedHousehold(householdExtra = {}) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'households', HH), {
      created_by: OWNER,
      name: 'encrypted-name',
      ...householdExtra,
    });
    for (const [uid, role] of [
      [OWNER, 'admin'],
      [MEMBER, 'member'],
      [ASSISTANT, 'assistant'],
    ]) {
      await setDoc(doc(db, 'household_members', `${uid}_${HH}`), {
        user_id: uid,
        household_id: HH,
        role,
      });
    }
  });
}

// ───────────────────────────────────────────────────────────────────────────
describe('who may change the burn policy', () => {
  test('the owner CAN set it', async () => {
    await seedHousehold();
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'households', HH), { burn_permission: 'everyone' })
    );
  });

  test('a plain member CANNOT set it', async () => {
    await seedHousehold();
    const db = testEnv.authenticatedContext(MEMBER).firestore();
    await assertFails(
      updateDoc(doc(db, 'households', HH), { burn_permission: 'everyone' })
    );
  });

  test('a paired assistant CANNOT set it', async () => {
    // The reason the feature exists: since 1.7.0 an assistant is a member like
    // any other, so "any member may widen the burn policy" includes it.
    await seedHousehold();
    const db = testEnv.authenticatedContext(ASSISTANT).firestore();
    await assertFails(
      updateDoc(doc(db, 'households', HH), { burn_permission: 'everyone' })
    );
  });

  test('a member CANNOT add themselves to the allow list', async () => {
    await seedHousehold({ burn_permission: 'selected', burn_allowed_uids: [] });
    const db = testEnv.authenticatedContext(MEMBER).firestore();
    await assertFails(
      updateDoc(doc(db, 'households', HH), { burn_allowed_uids: [MEMBER] })
    );
  });

  test('a member CANNOT quietly remove the policy field', async () => {
    // Deleting the field would default the household back to owner-only, which
    // is harmless — but the same trick against a stricter setting is not, and
    // the rule should not depend on which direction the change happens to go.
    await seedHousehold({ burn_permission: 'nobody' });
    const db = testEnv.authenticatedContext(MEMBER).firestore();
    await assertFails(
      setDoc(doc(db, 'households', HH), { created_by: OWNER, name: 'encrypted-name' })
    );
  });

  test('the owner CAN name selected members', async () => {
    await seedHousehold();
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'households', HH), {
        burn_permission: 'selected',
        burn_allowed_uids: [MEMBER],
      })
    );
  });
});

// ───────────────────────────────────────────────────────────────────────────
describe('the ordinary things must still work', () => {
  test('a plain member CAN still rename the household', async () => {
    // The pairing that matters. The rule reads the whole resulting document,
    // so a rename carries burn_permission through untouched and must not trip
    // the owner check.
    await seedHousehold({ burn_permission: 'nobody' });
    const db = testEnv.authenticatedContext(MEMBER).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'households', HH), { name: 'new-encrypted-name' })
    );
  });

  test('a plain member CAN rename a household that has no policy field at all', async () => {
    // Every household created before 1.10.0 is this one.
    await seedHousehold();
    const db = testEnv.authenticatedContext(MEMBER).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'households', HH), { name: 'new-encrypted-name' })
    );
  });

  test('created_by is still frozen', async () => {
    await seedHousehold();
    const db = testEnv.authenticatedContext(MEMBER).firestore();
    await assertFails(
      updateDoc(doc(db, 'households', HH), { created_by: MEMBER })
    );
  });

  test('the owner cannot promote someone else by rewriting created_by either', async () => {
    await seedHousehold();
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(
      updateDoc(doc(db, 'households', HH), { created_by: MEMBER })
    );
  });
});

// ───────────────────────────────────────────────────────────────────────────
describe('the value has to mean something', () => {
  test('the owner CANNOT write a permission outside the set', async () => {
    // It would be read as "owner" by the function, which fails closed — but
    // silently, and a setting that quietly means something other than what it
    // says is how a household ends up believing it is protected.
    await seedHousehold();
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(
      updateDoc(doc(db, 'households', HH), { burn_permission: 'anyone' })
    );
  });

  test('the owner CANNOT write a non-list allow list', async () => {
    await seedHousehold();
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(
      updateDoc(doc(db, 'households', HH), { burn_allowed_uids: MEMBER })
    );
  });

  test('all four permitted values are accepted', async () => {
    for (const value of ['owner', 'selected', 'everyone', 'nobody']) {
      await testEnv.clearFirestore();
      await seedHousehold();
      const db = testEnv.authenticatedContext(OWNER).firestore();
      await assertSucceeds(
        updateDoc(doc(db, 'households', HH), { burn_permission: value })
      );
    }
  });

  test('a household can still be created without a policy field', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertSucceeds(
      setDoc(doc(db, 'households', 'hh-new'), { created_by: OWNER, name: 'enc' })
    );
  });

  test('a household CANNOT be created with a bogus policy', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(
      setDoc(doc(db, 'households', 'hh-new2'), {
        created_by: OWNER,
        name: 'enc',
        burn_permission: 'whoever',
      })
    );
  });
});
