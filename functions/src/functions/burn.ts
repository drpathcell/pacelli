/**
 * Burning household data.
 *
 * Until 1.10.0 "burn all data" was one button that did two unrelated things:
 * deleted the caller's account, and wiped everything the household shared.
 * They are now separate, because only one of them can be gated.
 *
 *   - **Delete my account** stays on the client and is available to everyone,
 *     always. App Store Guideline 5.1.1(v) requires in-app account deletion,
 *     and a household owner cannot be allowed to take that away.
 *   - **Burn household data** — this file — is the owner's call.
 *
 * ## Why this is a function and not a security rule
 *
 * The 2026-08-24 design note said the permission would be "enforced in rules
 * not UI". It cannot be. A burn is not an operation Firestore can see; it is a
 * few hundred deletes, and every content collection allows `delete` to any
 * member because deleting one task is ordinary use. A rule cannot tell the two
 * apart without breaking the ordinary case.
 *
 * So the check moved here, where the caller's identity is verified and the
 * household document is read by something the caller cannot forge. That is
 * strictly stronger than the rule would have been, and it fixes a second
 * problem on the way: the wipe stops being a 400-document batch driven from a
 * phone that can lose signal halfway and leave a household half-erased.
 *
 * ## What it does NOT delete
 *
 * Memberships, profiles, wrapped keys and the household document itself. This
 * empties a household; it does not dissolve one. Everyone who was in it is
 * still in it afterwards, looking at an empty app. Dissolving happens through
 * account deletion, when the last member leaves.
 */
import * as admin from "firebase-admin";

import { AuthContext } from "../middleware/auth";

const db = () => admin.firestore();

/**
 * Household-scoped collections a burn empties.
 *
 * MUST stay in step with `HouseholdService.householdContentCollections` in the
 * app — that list also decides whether a household counts as empty enough to
 * discard, so a collection missing from either side is either data that
 * survives a burn or a household discarded while still holding data.
 *
 * `photos` carries its Cloud Storage object with it: deleting the document
 * fires `onPhotoDeleted`, which takes the object. Nothing here needs to know
 * the bucket exists.
 */
export const HOUSEHOLD_CONTENT_COLLECTIONS = [
  "tasks", "checklists", "scratch_plans",
  "task_categories", "task_attachments", "plan_attachments",
  "inventory_items", "inventory_categories",
  "inventory_locations", "inventory_logs", "inventory_attachments",
  "manual_entries", "manual_categories", "feedback", "diagnostics",
  "weekly_digests",
  "subtasks", "checklist_items", "plan_entries", "plan_checklist_items",
  "photos",
];

/** Content, plus the two collections that are not content but are household
 *  secrets: a live invite or join code outliving a burn is a way back in. */
export const BURN_SCOPED_COLLECTIONS = [
  ...HOUSEHOLD_CONTENT_COLLECTIONS,
  "household_invites",
  "household_join_codes",
];

/** Firestore's batch ceiling is 500; 400 leaves room and matches the client. */
const BATCH_SIZE = 400;

export type BurnPermission = "owner" | "selected" | "everyone" | "nobody";

const VALID_PERMISSIONS: BurnPermission[] = ["owner", "selected", "everyone", "nobody"];

/**
 * The permission as stored, defaulted.
 *
 * Absent means `owner`, which is the decision taken on 2026-08-24: households
 * created before this feature existed become owner-only rather than keeping
 * today's behaviour, because today's behaviour — anyone may wipe everything —
 * is the thing being fixed. An unrecognised value also means `owner`: a field
 * this important fails closed, and the only writer able to put a bad value
 * there is the owner themselves.
 */
export function readBurnPermission(
  household: Record<string, unknown> | undefined
): { permission: BurnPermission; allowed: string[] } {
  const raw = household?.burn_permission;
  const permission = VALID_PERMISSIONS.includes(raw as BurnPermission)
    ? (raw as BurnPermission)
    : "owner";
  const allowedRaw = household?.burn_allowed_uids;
  const allowed = Array.isArray(allowedRaw)
    ? allowedRaw.filter((u): u is string => typeof u === "string")
    : [];
  return { permission, allowed };
}

/**
 * May this uid burn this household's shared data?
 *
 * Deliberately literal. `nobody` means nobody — the owner included. That is
 * not a lock and is not sold as one: the owner can change the setting and then
 * burn. It is a way to make the destructive path cost a deliberate visit to
 * Settings, which is what "or no one" was asking for.
 *
 * Pure on purpose. Everything that decides who may destroy a household's data
 * is in this function, so it can be tested as a table rather than through an
 * emulator, and so a reader can check it without holding the wipe in their
 * head at the same time.
 */
export function mayBurn(
  household: Record<string, unknown> | undefined,
  uid: string
): boolean {
  const { permission, allowed } = readBurnPermission(household);
  switch (permission) {
    case "everyone":
      return true;
    case "owner":
      return household?.created_by === uid;
    case "selected":
      return allowed.includes(uid);
    case "nobody":
      return false;
  }
}

export class BurnRefused extends Error {
  constructor(message: string, public readonly statusCode: number) {
    super(message);
    this.name = "BurnRefused";
  }
}

/**
 * Deletes every household-scoped document, then proves it.
 *
 * The verification pass is not decoration. A burn that reports success while
 * something survived is worse than one that fails, because the person believes
 * their data is gone and stops trying. Same rule the client wipe has followed
 * since it was written: fail loudly, never fake success.
 */
export async function burnHouseholdData(
  ctx: AuthContext
): Promise<{ deleted: Record<string, number>; total: number }> {
  const householdRef = db().collection("households").doc(ctx.householdId);
  const householdSnap = await householdRef.get();
  if (!householdSnap.exists) {
    throw new BurnRefused("That household no longer exists.", 404);
  }

  if (!mayBurn(householdSnap.data(), ctx.uid)) {
    // Deliberately says which permission is in force. The alternative is a
    // bare "no", which sends the user to ask the owner a question the app
    // already knows the answer to.
    const { permission } = readBurnPermission(householdSnap.data());
    throw new BurnRefused(
      permission === "nobody"
        ? "Burning this household's data is switched off. The household owner can change that in Settings."
        : "Only people the household owner has allowed can burn this household's data.",
      403
    );
  }

  const deleted: Record<string, number> = {};
  let total = 0;

  for (const collection of BURN_SCOPED_COLLECTIONS) {
    const count = await deleteWhereHousehold(collection, ctx.householdId);
    if (count > 0) {
      deleted[collection] = count;
      total += count;
    }
  }

  // Keyed by household id rather than carrying a household_id field, so it
  // cannot be found by the query above.
  const driveConfig = db().collection("household_drive_config").doc(ctx.householdId);
  if ((await driveConfig.get()).exists) {
    await driveConfig.delete();
    deleted["household_drive_config"] = 1;
    total += 1;
  }

  const survivors = await findSurvivors(ctx.householdId);
  if (survivors.length > 0) {
    throw new BurnRefused(
      `Deletion could not be verified — ${survivors.join(", ")} still hold data. Nothing has been hidden; please try again.`,
      500
    );
  }

  return { deleted, total };
}

/** Paged delete: query a bounded page, delete it, repeat until dry. Bounded
 *  so a household with tens of thousands of documents cannot exhaust memory
 *  the way a single unbounded query would. */
async function deleteWhereHousehold(collection: string, householdId: string): Promise<number> {
  let removed = 0;
  for (;;) {
    const snap = await db()
      .collection(collection)
      .where("household_id", "==", householdId)
      .limit(BATCH_SIZE)
      .get();
    if (snap.empty) return removed;

    const batch = db().batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    removed += snap.size;

    // A full page means there is probably more; a short one means we are done
    // and the next query would only cost a round trip to learn that.
    if (snap.size < BATCH_SIZE) return removed;
  }
}

/** Names the collections that still hold something. Reads through the admin
 *  SDK, which is always the server — there is no cache here to be stale, the
 *  way the client wipe's `source: .server` exists to defeat. */
async function findSurvivors(householdId: string): Promise<string[]> {
  const survivors: string[] = [];
  for (const collection of BURN_SCOPED_COLLECTIONS) {
    const snap = await db()
      .collection(collection)
      .where("household_id", "==", householdId)
      .limit(1)
      .get();
    if (!snap.empty) survivors.push(collection);
  }
  return survivors;
}

/**
 * What the app needs to draw the Settings screen: the setting, and whether
 * the caller is the owner who may change it.
 *
 * The app could read the household document itself — it has read access — but
 * then the client's idea of "may I burn?" and the server's would be two
 * implementations of one rule, and they would drift. One answer, one place.
 */
export async function getBurnPolicy(ctx: AuthContext): Promise<{
  permission: BurnPermission;
  allowed_uids: string[];
  is_owner: boolean;
  may_burn: boolean;
}> {
  const snap = await db().collection("households").doc(ctx.householdId).get();
  const data = snap.data();
  const { permission, allowed } = readBurnPermission(data);
  return {
    permission,
    allowed_uids: allowed,
    is_owner: data?.created_by === ctx.uid,
    may_burn: mayBurn(data, ctx.uid),
  };
}
