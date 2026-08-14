/**
 * Connecting an AI assistant to a household.
 *
 * The assistant is a **separate household member**, not a borrowed login. That
 * choice drives everything here:
 *
 *   - its edits are attributed to it, not to the person who connected it
 *   - it appears in Members like anyone else, so it is visible, not ambient
 *   - revoking is removing a member — the human's own credentials are never
 *     handed out and never need rotating
 *
 * The pairing flow, and why it is shaped this way:
 *
 *   1. A signed-in member calls `aiLinkCreate`. The function provisions a
 *      Firebase user for the assistant, wraps the household key for it, adds
 *      the member doc, and returns a short-lived one-shot CODE.
 *   2. The user pastes that code into their MCP server config.
 *   3. The MCP server calls `aiLinkRedeem` — UNAUTHENTICATED, because it has no
 *      credential yet; the code is the credential. It gets a custom token back
 *      and exchanges it for an ID + refresh token using only the public web API
 *      key. From then on it refreshes indefinitely.
 *
 * No service account ever leaves this project. That is the whole point: the
 * privileged step happens here, so any Pacelli user can connect an assistant
 * without holding an admin credential.
 *
 * The code is a bearer secret. It is therefore short-lived, single-use, and
 * high-entropy — see CODE_TTL_MS and makeCode.
 */
import * as admin from "firebase-admin";
import * as crypto from "crypto";

import { AuthContext } from "../middleware/auth";
import { encryptKeyForUser } from "../crypto/encryption-service";

const db = () => admin.firestore();

/** Ten minutes: long enough to paste into a config, short enough that a code
 *  found later in a screenshot or a shell history is already dead. */
const CODE_TTL_MS = 10 * 60 * 1000;

const ASSISTANT_ROLE = "assistant";

/** Crockford-ish base32, no vowels and no look-alikes (0/O, 1/I/L).
 *  Read aloud or retyped without ambiguity; ~41 bits over 8 chars. */
const ALPHABET = "23456789ABCDEFGHJKMNPQRSTVWXYZ";

function makeCode(): string {
  const bytes = crypto.randomBytes(8);
  return Array.from(bytes)
    .map((b) => ALPHABET[b % ALPHABET.length])
    .join("");
}

function isoNow(): string {
  return new Date().toISOString();
}

export interface CreatedLink {
  code: string;
  expiresAt: string;
  assistantUid: string;
  label: string;
}

/**
 * Provision an assistant member and return a one-shot pairing code.
 *
 * Idempotency is deliberately NOT attempted: connecting a second assistant is a
 * legitimate thing to want (a laptop and a phone, or two different tools), and
 * silently returning an existing link would make the second one impossible.
 * Each call mints a distinct member, and each is revocable on its own.
 */
export async function createLink(
  ctx: AuthContext,
  params: { label?: string }
): Promise<CreatedLink> {
  const label = (params.label ?? "AI assistant").slice(0, 40);

  // A real Firebase user, so it can hold a session and be revoked like any
  // other. Disabled accounts cannot mint tokens, which is the kill switch.
  const assistant = await admin.auth().createUser({
    displayName: label,
  });

  const code = makeCode();
  const expiresAt = new Date(Date.now() + CODE_TTL_MS).toISOString();

  // The assistant must be able to DECRYPT, so the household key is re-wrapped
  // for its uid — exactly as the invite handshake does for a new person. Without
  // this it would authenticate fine and then read ciphertext forever.
  await db().collection("household_keys").add({
    household_id: ctx.householdId,
    user_id: assistant.uid,
    encrypted_key: encryptKeyForUser(ctx.householdKey, assistant.uid),
    created_at: isoNow(),
  });

  // `joined_via` points at the code that authorised it, matching how every
  // other membership records its provenance.
  await db()
    .collection("household_members")
    .doc(`${assistant.uid}_${ctx.householdId}`)
    .set({
      household_id: ctx.householdId,
      user_id: assistant.uid,
      role: ASSISTANT_ROLE,
      joined_at: isoNow(),
      joined_via: `ai_link:${code}`,
      display_name: label,
    });

  await db().collection("ai_link_codes").doc(code).set({
    code,
    assistant_uid: assistant.uid,
    household_id: ctx.householdId,
    created_by: ctx.uid,
    created_at: isoNow(),
    expires_at: expiresAt,
    redeemed: false,
    label,
  });

  return { code, expiresAt, assistantUid: assistant.uid, label };
}

/**
 * Exchange a pairing code for a custom token. **Unauthenticated by design** —
 * the caller has no credential yet; the code is the credential.
 *
 * Single-use and time-boxed, and the code doc is marked redeemed BEFORE the
 * token is minted so that two racing redemptions cannot both succeed.
 */
export async function redeemLink(
  code: string
): Promise<{ customToken: string; householdId: string; assistantUid: string }> {
  const trimmed = (code ?? "").trim().toUpperCase();
  if (!/^[0-9A-Z]{8}$/.test(trimmed)) {
    throw new Error("Invalid pairing code");
  }

  const ref = db().collection("ai_link_codes").doc(trimmed);

  // Claim the code in a transaction, because the whole value of single-use is
  // lost if two callers can both observe `redeemed: false`.
  const data = await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new Error("Invalid pairing code");
    const d = snap.data()!;
    if (d.redeemed) throw new Error("This pairing code has already been used");
    if (Date.parse(d.expires_at) < Date.now()) {
      throw new Error("This pairing code has expired");
    }
    tx.update(ref, { redeemed: true, redeemed_at: isoNow() });
    return d;
  });

  // Un-claim if minting fails, or the code is destroyed for nothing.
  //
  // The first version of this did not, and the very first real pairing attempt
  // burned its code: the claim committed, then createCustomToken threw
  // `iam.serviceAccounts.signBlob denied` (the runtime service account needs
  // Token Creator on itself), and the user was left holding a dead code with a
  // generic error. Claim-then-mint is right for the race; it just has to be
  // undone when the second half fails.
  let customToken: string;
  try {
    customToken = await admin.auth().createCustomToken(data.assistant_uid);
  } catch (e) {
    await ref.update({ redeemed: false, redeemed_at: admin.firestore.FieldValue.delete() });
    throw e;
  }
  return {
    customToken,
    householdId: data.household_id,
    assistantUid: data.assistant_uid,
  };
}

/** Every assistant currently attached to the caller's household. */
export async function listLinks(ctx: AuthContext): Promise<unknown[]> {
  const snap = await db()
    .collection("household_members")
    .where("household_id", "==", ctx.householdId)
    .where("role", "==", ASSISTANT_ROLE)
    .get();

  return snap.docs.map((d) => {
    const x = d.data();
    return {
      assistantUid: x.user_id,
      label: x.display_name ?? "AI assistant",
      joinedAt: x.joined_at,
    };
  });
}

/**
 * Cut an assistant off. Four things, in the order that matters.
 *
 * Token revocation and account disable come FIRST: an assistant holding a live
 * ID token would otherwise keep working for up to an hour on a membership that
 * no longer exists. Removing the row without killing the session is the mistake
 * that makes revocation feel like it did not work.
 */
export async function revokeLink(
  ctx: AuthContext,
  assistantUid: string
): Promise<{ revoked: boolean }> {
  const memberRef = db()
    .collection("household_members")
    .doc(`${assistantUid}_${ctx.householdId}`);
  const member = await memberRef.get();

  // Scoped to the caller's own household, like every other by-id handler.
  if (!member.exists || member.data()!.household_id !== ctx.householdId) {
    return { revoked: false };
  }
  if (member.data()!.role !== ASSISTANT_ROLE) {
    throw new Error("That member is not an AI assistant");
  }

  await admin.auth().revokeRefreshTokens(assistantUid);
  await admin.auth().updateUser(assistantUid, { disabled: true });

  const keys = await db()
    .collection("household_keys")
    .where("household_id", "==", ctx.householdId)
    .where("user_id", "==", assistantUid)
    .get();

  const batch = db().batch();
  keys.docs.forEach((k) => batch.delete(k.ref));
  batch.delete(memberRef);
  await batch.commit();

  return { revoked: true };
}
