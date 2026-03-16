/**
 * Server-side key manager for Pacelli Cloud Functions.
 *
 * Unlike the Flutter KeyManager (which caches keys in memory + secure storage),
 * this is stateless: each request loads, decrypts, and returns the household key
 * from Firestore. Cloud Functions are stateless, so no caching between requests.
 */
import * as admin from "firebase-admin";
import {
  decryptKeyWithMigration,
  deriveUserKey,
  encrypt,
} from "./encryption-service";

/**
 * Loads the household key for a given user and household.
 *
 * 1. Queries `household_keys` for the user's encrypted key doc
 * 2. Derives the user key from UID via HKDF
 * 3. Decrypts the household key (with v1→v2 migration support)
 * 4. If v1 was used, re-wraps with v2 for next time
 *
 * Returns the plaintext household key (64-char hex string), or null.
 */
export async function loadHouseholdKey(
  uid: string,
  householdId: string
): Promise<string | null> {
  const db = admin.firestore();

  const snapshot = await db
    .collection("household_keys")
    .where("household_id", "==", householdId)
    .where("user_id", "==", uid)
    .limit(1)
    .get();

  if (snapshot.empty) {
    console.warn(`[KeyManager] No key found for household=${householdId}, uid=${uid}`);
    return null;
  }

  const doc = snapshot.docs[0];
  const encryptedKey = doc.data().encrypted_key as string;

  // Decrypt with migration support
  const { decryptedKey, wasV1 } = decryptKeyWithMigration(encryptedKey, uid);

  // If v1 was used, silently migrate to v2 wrapping
  if (wasV1) {
    console.info("[KeyManager] Migrating key wrapping from v1 to v2 HKDF");
    const v2UserKey = deriveUserKey(uid);
    const newWrapped = encrypt(decryptedKey, v2UserKey);
    await doc.ref.update({ encrypted_key: newWrapped });
  }

  return decryptedKey;
}

/**
 * Resolves the household ID for a given user.
 *
 * Checks `household_members` collection for a document where the user
 * is a member. Returns the first household ID found, or null.
 */
export async function resolveHouseholdId(uid: string): Promise<string | null> {
  const db = admin.firestore();

  // household_members uses deterministic doc IDs: {userId}_{householdId}
  const snapshot = await db
    .collection("household_members")
    .where("user_id", "==", uid)
    .limit(1)
    .get();

  if (snapshot.empty) return null;

  return snapshot.docs[0].data().household_id as string;
}
