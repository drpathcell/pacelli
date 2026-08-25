/**
 * Sweeping abandoned guest households.
 *
 * ## The leak
 *
 * Every E2E harness starts by ERASING the simulator. That wipes the device,
 * not Firebase. Each run then signs in as a guest, which auto-provisions a
 * household, a key and some content — and until 2026-08-25 only
 * `check_burn_e2e.sh` ever deleted the account again, because deleting it is
 * what that harness tests. Seven other harnesses did not. 106 abandoned guest
 * accounts had accumulated since May, one per run.
 *
 * The fix is in two halves and this is the second one. The first is
 * `scripts/teardown_guest.sh`, which deletes the account at the end of every
 * run through the app's own shipped deletion path. This exists for what that
 * misses: a run that crashed, a simulator that hung, a harness written later
 * by someone who forgets.
 *
 * ## Guest mode is a REAL feature, so this has to be careful
 *
 * Anonymous accounts are not test residue by definition. Guest mode exists
 * because App Review demanded it (the 1.0 rejection, Guideline 5.1.1(v)), and
 * a real person can use this app as a guest forever without ever making an
 * account. Deleting one of those destroys somebody's data with no way back.
 *
 * So the signal is NOT "anonymous". It is **`lastRefreshTime`** — the last
 * time this account exchanged a refresh token, which is the last time the app
 * was actually opened on somebody's phone.
 *
 * `lastSignInTime` looks like the obvious field and is a trap: an anonymous
 * session persists in the keychain and never signs in a second time, so a
 * guest who uses the app daily for a year still reports the same
 * `lastSignInTime` as the moment they first tapped "Continue as guest". A
 * sweep built on it would delete active users. (It is also all that
 * `firebase auth:export` gives you, which is how the trap presents itself.)
 *
 * Five conditions, all required, checked per account:
 *
 *   1. no email, no federated provider, uid is not an `ai_` assistant
 *   2. not already disabled (a disabled account is somebody's decision)
 *   3. `lastRefreshTime` (falling back to `lastSignInTime`) older than the
 *      cutoff — the app has not been opened for that long
 *   4. every household it belongs to was CREATED BY it
 *   5. no other HUMAN member in those households — assistants do not count,
 *      because a paired assistant is not a second person to lose data
 *
 * Anything it is unsure about, it leaves alone. An orphan household costs a
 * few kilobytes; a deleted one costs somebody their tasks.
 */
import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";

import { BURN_SCOPED_COLLECTIONS } from "./burn";

const db = () => admin.firestore();
const REGION = "us-central1";

/** Fourteen days without the app being opened. Long enough that a real guest
 *  who goes on holiday keeps everything; short enough that residue does not
 *  live for a quarter. Prevention is the primary fix — this is the backstop,
 *  so it can afford to be slow and cautious. */
export const DEFAULT_MIN_IDLE_MS = 14 * 24 * 60 * 60 * 1000;

/** Households per run. Bounded so a bug cannot empty the project in one go,
 *  and so the run stays inside its timeout. */
const MAX_PER_RUN = 100;

const ASSISTANT_ROLE = "assistant";

export interface SweepResult {
  examined: number;
  eligible: number;
  deletedAccounts: string[];
  deletedAssistants: string[];
  deletedHouseholds: string[];
  deletedDocuments: number;
  skipped: { uid: string; reason: string }[];
  dryRun: boolean;
}

/** The last moment this account demonstrably had the app open. */
export function lastActive(user: admin.auth.UserRecord): number {
  const refresh = user.metadata.lastRefreshTime;
  const signIn = user.metadata.lastSignInTime;
  const created = user.metadata.creationTime;
  const stamp = refresh || signIn || created;
  return stamp ? new Date(stamp).getTime() : 0;
}

export function isPlainGuest(user: admin.auth.UserRecord): boolean {
  return (
    !user.email &&
    !user.phoneNumber &&
    (user.providerData?.length ?? 0) === 0 &&
    !user.uid.startsWith("ai_") &&
    !user.disabled
  );
}

export async function sweepAbandonedGuests(opts: {
  minIdleMs?: number;
  dryRun?: boolean;
  now?: number;
  limit?: number;
}): Promise<SweepResult> {
  const minIdleMs = opts.minIdleMs ?? DEFAULT_MIN_IDLE_MS;
  const dryRun = opts.dryRun ?? false;
  const now = opts.now ?? Date.now();
  const limit = Math.min(opts.limit ?? MAX_PER_RUN, MAX_PER_RUN);

  const result: SweepResult = {
    examined: 0, eligible: 0, deletedAccounts: [], deletedAssistants: [], deletedHouseholds: [],
    deletedDocuments: 0, skipped: [], dryRun,
  };

  // Everybody, once. The project has hundreds of accounts, not millions.
  const users: admin.auth.UserRecord[] = [];
  let pageToken: string | undefined;
  do {
    const page = await admin.auth().listUsers(1000, pageToken);
    users.push(...page.users);
    pageToken = page.pageToken;
  } while (pageToken);

  // Who is a person. Used to refuse any household a real account is in, even
  // when the guest created it — sharing a household with someone who has an
  // email means the content is not the guest's alone to lose.
  const humanUids = new Set(
    users.filter((u) => !isPlainGuest(u) && !u.uid.startsWith("ai_")).map((u) => u.uid)
  );

  const candidates = users.filter(isPlainGuest);
  result.examined = candidates.length;

  for (const user of candidates) {
    if (result.deletedAccounts.length >= limit) break;

    const idle = now - lastActive(user);
    if (idle < minIdleMs) {
      continue; // still in use, or too recent to judge — say nothing, this is the common case
    }

    const memberSnap = await db()
      .collection("household_members")
      .where("user_id", "==", user.uid)
      .get();
    const householdIds = [
      ...new Set(
        memberSnap.docs
          .map((d) => d.data().household_id as string | undefined)
          .filter((h): h is string => !!h)
      ),
    ];

    // Check every household BEFORE deleting anything, so a guest who shares
    // one household and owns another is skipped whole rather than half-swept.
    let refusal: string | null = null;
    for (const hid of householdIds) {
      const hh = await db().collection("households").doc(hid).get();
      if (!hh.exists) continue; // already gone; its member row is just litter
      if (hh.data()?.created_by !== user.uid) {
        refusal = `is a member of household ${hid} it did not create`;
        break;
      }
      const others = await db()
        .collection("household_members")
        .where("household_id", "==", hid)
        .get();
      const otherHumans = others.docs
        .map((d) => d.data())
        .filter(
          (m) =>
            m.user_id !== user.uid &&
            m.role !== ASSISTANT_ROLE &&
            humanUids.has(m.user_id)
        );
      if (otherHumans.length > 0) {
        refusal = `household ${hid} has ${otherHumans.length} other human member(s)`;
        break;
      }
    }
    if (refusal) {
      result.skipped.push({ uid: user.uid, reason: refusal });
      continue;
    }

    result.eligible += 1;
    if (dryRun) {
      result.deletedAccounts.push(user.uid);
      result.deletedHouseholds.push(...householdIds);
      continue;
    }

    // One bad account must not abort the sweep. The first real run died on
    // `auth/user-not-found` deleting a uid that listUsers had just returned —
    // and because the throw escaped, the HTTP caller got a 500 for a run that
    // had already deleted 31 accounts successfully. A sweep that does most of
    // its work and then reports failure is worse than one that reports
    // exactly which account it could not finish.
    try {
      await purgeGuest(user, householdIds, result);
    } catch (e) {
      result.skipped.push({
        uid: user.uid,
        reason: `failed mid-delete: ${e instanceof Error ? e.message : String(e)}`,
      });
    }
  }

  // Assistant accounts whose member row is gone. An assistant IS its member
  // row -- without one it cannot read anything, so it is residue by
  // definition, whether it was revoked (revokeLink disables but never deletes)
  // or its household was swept before this collected uids in the right order.
  {
    const live = new Set(
      (await db().collection("household_members")
        .where("role", "==", ASSISTANT_ROLE).get())
        .docs.map((d) => d.data().user_id as string)
    );
    for (const u of users) {
      if (!u.uid.startsWith("ai_") || live.has(u.uid)) continue;
      if (!dryRun) await admin.auth().deleteUser(u.uid).catch(() => undefined);
      result.deletedAssistants.push(u.uid);
    }
  }

  return result;
}

async function purgeGuest(
  user: admin.auth.UserRecord,
  householdIds: string[],
  result: SweepResult
): Promise<void> {
    // Collected BEFORE the purge: purgeHousehold deletes the
    // `household_members` rows that name them. Asking afterwards returned an
    // empty list every time and left all 20 assistant accounts standing while
    // the run reported success -- caught by counting the accounts afterwards
    // instead of believing the run's own output.
    const assistantUids: string[] = [];
    for (const hid of householdIds) {
      assistantUids.push(...(await assistantUidsFor(hid)));
    }

    for (const hid of householdIds) {
      result.deletedDocuments += await purgeHousehold(hid);
      result.deletedHouseholds.push(hid);
    }

    // Assistants paired to those households are Firebase users too, and
    // revokeLink only DISABLES them. Nobody can use a disabled account, but
    // leaving one per run is the same accumulation in a different collection.
    for (const uid of assistantUids) {
      await admin.auth().deleteUser(uid).catch(() => undefined);
      result.deletedAssistants.push(uid);
    }

    result.deletedDocuments += await deleteWhere("household_members", "user_id", user.uid);
    result.deletedDocuments += await deleteWhere("household_keys", "user_id", user.uid);
    await db().collection("profiles").doc(user.uid).delete().catch(() => undefined);

    // `auth/user-not-found` here is success, not failure: the account is gone,
    // which is the whole objective. It happens because listUsers pages are a
    // snapshot — a uid deleted by an earlier, interrupted run can still appear
    // in this one's listing. Anything else is a real error and propagates.
    try {
      await admin.auth().deleteUser(user.uid);
    } catch (e) {
      const code = (e as { code?: string })?.code;
      if (code !== "auth/user-not-found") throw e;
    }
    result.deletedAccounts.push(user.uid);
}

async function assistantUidsFor(householdId: string): Promise<string[]> {
  const snap = await db()
    .collection("household_members")
    .where("household_id", "==", householdId)
    .get();
  return snap.docs
    .map((d) => d.data())
    .filter((m) => m.role === ASSISTANT_ROLE && typeof m.user_id === "string")
    .map((m) => m.user_id as string);
}

/** Everything scoped to one household: content, invites, codes, keys, members,
 *  drive config and the household document. Deleting `photos` documents takes
 *  their Cloud Storage objects with them through `onPhotoDeleted`. */
async function purgeHousehold(householdId: string): Promise<number> {
  let removed = 0;
  for (const collection of [...BURN_SCOPED_COLLECTIONS, "household_keys", "household_members"]) {
    removed += await deleteWhere(collection, "household_id", householdId);
  }
  const drive = db().collection("household_drive_config").doc(householdId);
  if ((await drive.get()).exists) { await drive.delete(); removed += 1; }
  const hh = db().collection("households").doc(householdId);
  if ((await hh.get()).exists) { await hh.delete(); removed += 1; }
  return removed;
}

async function deleteWhere(collection: string, field: string, value: string): Promise<number> {
  let removed = 0;
  for (;;) {
    const snap = await db().collection(collection).where(field, "==", value).limit(400).get();
    if (snap.empty) return removed;
    const batch = db().batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    removed += snap.size;
    if (snap.size < 400) return removed;
  }
}

/**
 * Daily. No HTTP surface: a scheduled trigger cannot be called by anyone, so
 * there is no token to leak and no endpoint to guess. The same reason
 * `sweepStrandedPhotos` is shaped this way.
 */
export const sweepAbandonedGuests_scheduled = onSchedule(
  { schedule: "every 24 hours", region: REGION, timeoutSeconds: 540 },
  async () => {
    const r = await sweepAbandonedGuests({});
    logger.info(
      `[sweepAbandonedGuests] examined ${r.examined} guest account(s), ` +
      `deleted ${r.deletedAccounts.length} account(s), ` +
      `${r.deletedAssistants.length} assistant account(s), ` +
      `${r.deletedHouseholds.length} household(s), ` +
      `${r.deletedDocuments} document(s), skipped ${r.skipped.length}`,
      { skipped: r.skipped }
    );
  }
);
