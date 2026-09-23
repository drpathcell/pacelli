/**
 * Rules tests for deleting the `households` document — added 2026-09-23.
 *
 * The 2026-08-24 change froze `created_by` on update and anchored ownership
 * on it. It left `delete` open to any member, and `create` open to anyone
 * naming themselves. Together those were a promotion path in two writes:
 * delete `households/{id}`, then create it again with `created_by` set to
 * yourself. Every member row survives, so `isMember` still passes, and the
 * caller now satisfies `isHouseholdOwner()` — free to rewrite the burn
 * policy, evict everyone and call `burnHousehold` as owner. A paired AI
 * assistant is a member like any other, so it could do this too.
 *
 * The fix: a member may delete the household document only if they ARE the
 * owner, or the owner's own member row is gone. The second branch is what
 * keeps account deletion working for a non-owner who is the last one out —
 * live BurnService deletes the household doc in exactly that case, and
 * Guideline 5.1.1(v) is why. Every refusal here is paired with the
 * neighbouring thing that must still succeed.
 */

const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, setDoc, deleteDoc, setLogLevel } = require('firebase/firestore');

const HH = 'hh-refound';
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

async function seed(setupFn) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setupFn(ctx.firestore());
  });
}

async function member(db, uid, role) {
  await setDoc(doc(db, 'household_members', `${uid}_${HH}`), {
    user_id: uid,
    household_id: HH,
    role,
  });
}

/** Owner + plain member + assistant, owner still present. */
async function seedFull() {
  await seed(async (db) => {
    await setDoc(doc(db, 'households', HH), { created_by: OWNER, name: 'enc' });
    await member(db, OWNER, 'admin');
    await member(db, MEMBER, 'member');
    await member(db, ASSISTANT, 'assistant');
  });
}

/** The owner has already deleted their account; one plain member remains. */
async function seedOwnerGone() {
  await seed(async (db) => {
    await setDoc(doc(db, 'households', HH), { created_by: OWNER, name: 'enc' });
    await member(db, MEMBER, 'member');
  });
}

describe('households delete — owner, or the owner is already gone', () => {
  test('the assistant CANNOT delete the household document', async () => {
    await seedFull();
    const ctx = testEnv.authenticatedContext(ASSISTANT);
    await assertFails(deleteDoc(doc(ctx.firestore(), 'households', HH)));
  });

  test('a plain member CANNOT delete the household document while the owner is present', async () => {
    await seedFull();
    const ctx = testEnv.authenticatedContext(MEMBER);
    await assertFails(deleteDoc(doc(ctx.firestore(), 'households', HH)));
  });

  test('the owner CAN delete the household document', async () => {
    await seedFull();
    const ctx = testEnv.authenticatedContext(OWNER);
    await assertSucceeds(deleteDoc(doc(ctx.firestore(), 'households', HH)));
  });

  test('the last member out CAN delete it once the owner has left (5.1.1(v) path)', async () => {
    await seedOwnerGone();
    const ctx = testEnv.authenticatedContext(MEMBER);
    await assertSucceeds(deleteDoc(doc(ctx.firestore(), 'households', HH)));
  });

  test('a non-member CANNOT delete it even when the owner has left', async () => {
    await seedOwnerGone();
    const ctx = testEnv.authenticatedContext('uid-stranger');
    await assertFails(deleteDoc(doc(ctx.firestore(), 'households', HH)));
  });
});

describe('the takeover, end to end', () => {
  test('a member CANNOT delete-and-refound the household to become owner', async () => {
    await seedFull();
    const ctx = testEnv.authenticatedContext(MEMBER);
    const db = ctx.firestore();
    await assertFails(deleteDoc(doc(db, 'households', HH)));
    // Even if the delete had gone through, nothing else in this test should
    // be reachable — assert the document is still the owner's.
    await testEnv.withSecurityRulesDisabled(async (adm) => {
      const { getDoc } = require('firebase/firestore');
      const snap = await getDoc(doc(adm.firestore(), 'households', HH));
      expect(snap.exists()).toBe(true);
      expect(snap.data().created_by).toBe(OWNER);
    });
  });
});
