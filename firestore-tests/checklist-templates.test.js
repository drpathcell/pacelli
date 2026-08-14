/**
 * Rules tests for `checklist_templates`.
 *
 * A template is a reusable set of checklist items ("quick Dunnes shop"). It
 * carries household content — item names and quantities — so it needs exactly
 * the household gate every other content collection has, and nothing looser.
 *
 * The interesting case is the LAST one: a create whose household_id points at
 * a household the caller is not in. `household_members` create was a bare
 * isAuth() until 1.2.0 and anyone could mint a membership anywhere; the lesson
 * from that is to prove the negative on every new collection rather than
 * assume the shared helper is doing its job.
 */

const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, deleteDoc, setLogLevel } = require('firebase/firestore');

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

const MEMBER = 'user-member';
const OUTSIDER = 'user-outsider';
const HID = 'house-1';

async function seedMembership() {
  await seed(async (db) => {
    await setDoc(doc(db, 'household_members', `${MEMBER}_${HID}`), {
      user_id: MEMBER,
      household_id: HID,
    });
  });
}

async function seedTemplate(id = 'tpl-1') {
  await seed(async (db) => {
    await setDoc(doc(db, 'checklist_templates', id), {
      id,
      household_id: HID,
      title: 'ciphertext',
      items: 'ciphertext',
      created_by: MEMBER,
      created_at: '2026-08-14T00:00:00.000',
    });
  });
}

describe('checklist_templates — household gate', () => {
  test('a member CAN read a template in their household', async () => {
    await seedMembership();
    await seedTemplate();
    const ctx = testEnv.authenticatedContext(MEMBER);
    await assertSucceeds(getDoc(doc(ctx.firestore(), 'checklist_templates', 'tpl-1')));
  });

  test('a member CAN create a template in their household', async () => {
    await seedMembership();
    const ctx = testEnv.authenticatedContext(MEMBER);
    await assertSucceeds(
      setDoc(doc(ctx.firestore(), 'checklist_templates', 'tpl-new'), {
        id: 'tpl-new',
        household_id: HID,
        title: 'ciphertext',
        items: 'ciphertext',
        created_by: MEMBER,
        created_at: '2026-08-14T00:00:00.000',
      })
    );
  });

  test('a member CAN delete a template in their household', async () => {
    await seedMembership();
    await seedTemplate();
    const ctx = testEnv.authenticatedContext(MEMBER);
    await assertSucceeds(deleteDoc(doc(ctx.firestore(), 'checklist_templates', 'tpl-1')));
  });

  test('an outsider CANNOT read a template', async () => {
    await seedMembership();
    await seedTemplate();
    const ctx = testEnv.authenticatedContext(OUTSIDER);
    await assertFails(getDoc(doc(ctx.firestore(), 'checklist_templates', 'tpl-1')));
  });

  test('an outsider CANNOT delete a template', async () => {
    await seedMembership();
    await seedTemplate();
    const ctx = testEnv.authenticatedContext(OUTSIDER);
    await assertFails(deleteDoc(doc(ctx.firestore(), 'checklist_templates', 'tpl-1')));
  });

  test('an UNAUTHENTICATED caller CANNOT read a template', async () => {
    await seedMembership();
    await seedTemplate();
    const ctx = testEnv.unauthenticatedContext();
    await assertFails(getDoc(doc(ctx.firestore(), 'checklist_templates', 'tpl-1')));
  });

  // The one that would matter if the shared helper ever regressed: an
  // authenticated stranger writing INTO someone else's household.
  test('an outsider CANNOT create a template in a household they are not in', async () => {
    await seedMembership();
    const ctx = testEnv.authenticatedContext(OUTSIDER);
    await assertFails(
      setDoc(doc(ctx.firestore(), 'checklist_templates', 'tpl-evil'), {
        id: 'tpl-evil',
        household_id: HID,
        title: 'ciphertext',
        items: 'ciphertext',
        created_by: OUTSIDER,
        created_at: '2026-08-14T00:00:00.000',
      })
    );
  });
});
