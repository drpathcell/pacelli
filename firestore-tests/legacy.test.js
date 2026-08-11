/**
 * Locks out the pre-1.2.0 client now that proof-of-authorisation is enforced.
 *
 * History: on 2026-08-10 the join-authorisation rules were deployed requiring
 * `joined_via` on household_members create, while the live App Store build was
 * still 1.1.0 / build 35 — which predates that field. Real users could not
 * accept a household invitation. A grace clause carried them until 1.2.0/38
 * shipped on 2026-08-11; this file guarded it. With the clause gone, the same
 * scenario must now be DENIED, which is what proves proof is back on.
 *
 * Keep this test. It is the regression guard for "did someone quietly relax
 * member creation again?" — a legacy-shaped write must never succeed.
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

test('a pre-1.2.0 client CANNOT accept an invite (no joined_via)', async () => {
  const db = env.authenticatedContext('chloe', { email: 'chloe@example.com' }).firestore();
  const b = writeBatch(db);
  b.set(doc(db, 'household_members', 'chloe_hh'), {
    user_id: 'chloe', household_id: 'hh', role: 'member', joined_at: '2026-08-10T10:00:00.000Z',
  });
  b.update(doc(db, 'household_invites', 'uuid-legacy'), { status: 'accepted' });
  await assertFails(b.commit());
});

test('self-only is enforced regardless of proof', async () => {
  // Minting a membership for someone else must stay denied — that was the
  // original vulnerability, and it is independent of the proof requirement.
  const db = env.authenticatedContext('chloe', { email: 'chloe@example.com' }).firestore();
  await assertFails(
    setDoc(doc(db, 'household_members', 'victim_hh'), {
      user_id: 'victim', household_id: 'hh', role: 'admin',
    })
  );
});
