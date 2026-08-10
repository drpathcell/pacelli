/**
 * Guards the LIVE App Store client against the hardened rules.
 *
 * On 2026-08-10 the join-authorisation rules were deployed requiring
 * `joined_via` on household_members create. The live App Store build was
 * 1.1.0 / build 35, which predates that field — so real users could no longer
 * accept a household invitation. This test is what proves the grace clause in
 * firestore.rules (`joinAuthorised` -> `return true`) is doing its job.
 *
 * WHEN 1.2.0 IS LIVE: remove the grace clause, then flip the two expectations
 * below (assertSucceeds -> assertFails). A green run after that means legacy
 * clients are correctly locked out and proof is enforced again.
 */
const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment, assertSucceeds, assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, setDoc, writeBatch, setLogLevel } = require('firebase/firestore');

let env;
beforeAll(async () => {
  setLogLevel('error');
  env = await initializeTestEnvironment({
    projectId: 'demo-pacelli',
    firestore: { rules: fs.readFileSync(path.resolve(__dirname, '..', 'firestore.rules'), 'utf8') },
  });
});
afterAll(async () => await env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'households', 'hh'), {
      id: 'hh', name: 'enc', created_by: 'owner', created_at: '2026-08-01T10:00:00.000Z',
    });
    await setDoc(doc(db, 'household_members', 'owner_hh'), {
      user_id: 'owner', household_id: 'hh', role: 'admin',
    });
    await setDoc(doc(db, 'household_invites', 'uuid-legacy'), {
      id: 'uuid-legacy', household_id: 'hh', invited_email: 'chloe@example.com',
      invited_by: 'owner', status: 'pending', created_at: '2026-08-09T10:00:00.000Z',
    });
  });
});

test('live build 35 can accept an invite (no joined_via)', async () => {
  const db = env.authenticatedContext('chloe', { email: 'chloe@example.com' }).firestore();
  const b = writeBatch(db);
  b.set(doc(db, 'household_members', 'chloe_hh'), {
    user_id: 'chloe', household_id: 'hh', role: 'member', joined_at: '2026-08-10T10:00:00.000Z',
  });
  b.update(doc(db, 'household_invites', 'uuid-legacy'), { status: 'accepted' });
  await assertSucceeds(b.commit());
});

test('self-only is STILL enforced during the grace period', async () => {
  // The grace clause relaxes proof, not identity. Minting a membership for
  // someone else must stay denied — that was the original vulnerability.
  const db = env.authenticatedContext('chloe', { email: 'chloe@example.com' }).firestore();
  await assertFails(
    setDoc(doc(db, 'household_members', 'victim_hh'), {
      user_id: 'victim', household_id: 'hh', role: 'admin',
    })
  );
});
