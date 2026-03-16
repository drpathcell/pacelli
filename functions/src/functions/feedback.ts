/**
 * Feedback & diagnostics business logic.
 *
 * Handles:
 * - Listing feedback entries
 * - Listing diagnostic events
 * - Generating weekly digests by counting Firestore documents
 * - Fetching existing digests
 */
import { createFieldCrypto } from "../middleware/encryption";
import * as admin from "firebase-admin";

const getDb = () => admin.firestore();

// ═══════════════════════════════════════════════════════════════════
//  FEEDBACK
// ═══════════════════════════════════════════════════════════════════

export async function listFeedback(
  ctx: { uid: string; householdId: string; householdKey: string },
  params: { limit?: number; type?: string }
): Promise<unknown[]> {
  const { dec, decN } = createFieldCrypto(ctx.householdKey);
  let query: admin.firestore.Query = getDb()
    .collection("feedback")
    .where("household_id", "==", ctx.householdId);

  if (params.type) {
    query = query.where("type", "==", params.type);
  }

  const snap = await query
    .orderBy("created_at", "desc")
    .limit(params.limit ?? 50)
    .get();

  return snap.docs.map((d) => {
    const data = d.data();
    return {
      id: d.id,
      type: data.type,
      rating: data.rating,
      message: dec(data.message),
      context: decN(data.context),
      createdBy: data.created_by,
      createdAt: data.created_at,
    };
  });
}

// ═══════════════════════════════════════════════════════════════════
//  DIAGNOSTICS
// ═══════════════════════════════════════════════════════════════════

export async function listDiagnostics(
  ctx: { uid: string; householdId: string; householdKey: string },
  params: { limit?: number; kind?: string }
): Promise<unknown[]> {
  const { dec, decN } = createFieldCrypto(ctx.householdKey);
  let query: admin.firestore.Query = getDb()
    .collection("diagnostics")
    .where("household_id", "==", ctx.householdId);

  if (params.kind) {
    query = query.where("kind", "==", params.kind);
  }

  const snap = await query
    .orderBy("created_at", "desc")
    .limit(params.limit ?? 100)
    .get();

  return snap.docs.map((d) => {
    const data = d.data();
    return {
      id: d.id,
      kind: data.kind,
      summary: dec(data.summary),
      detail: decN(data.detail),
      source: data.source,
      userId: data.user_id,
      createdAt: data.created_at,
    };
  });
}

// ═══════════════════════════════════════════════════════════════════
//  DIAGNOSTIC STATS (for AI-to-AI reporting)
// ═══════════════════════════════════════════════════════════════════

export async function getDiagnosticStats(
  ctx: { uid: string; householdId: string; householdKey: string }
): Promise<Record<string, unknown>> {
  const now = new Date();
  const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  const weekAgoIso = weekAgo.toISOString();

  // Count errors in last 7 days
  const errorSnap = await getDb()
    .collection("diagnostics")
    .where("household_id", "==", ctx.householdId)
    .where("kind", "==", "error")
    .where("created_at", ">=", weekAgoIso)
    .get();

  // Count warnings in last 7 days
  const warningSnap = await getDb()
    .collection("diagnostics")
    .where("household_id", "==", ctx.householdId)
    .where("kind", "==", "warning")
    .where("created_at", ">=", weekAgoIso)
    .get();

  // Count all feedback in last 7 days
  const feedbackSnap = await getDb()
    .collection("feedback")
    .where("household_id", "==", ctx.householdId)
    .where("created_at", ">=", weekAgoIso)
    .get();

  let positiveFeedback = 0;
  let negativeFeedback = 0;
  feedbackSnap.docs.forEach((d) => {
    const rating = d.data().rating;
    if (rating === "positive") positiveFeedback++;
    if (rating === "negative") negativeFeedback++;
  });

  return {
    period: "last_7_days",
    errors: errorSnap.size,
    warnings: warningSnap.size,
    totalFeedback: feedbackSnap.size,
    positiveFeedback,
    negativeFeedback,
    feedbackSentiment:
      feedbackSnap.size > 0
        ? Math.round((positiveFeedback / feedbackSnap.size) * 100)
        : null,
  };
}

// ═══════════════════════════════════════════════════════════════════
//  WEEKLY DIGEST GENERATION
// ═══════════════════════════════════════════════════════════════════

export async function generateWeeklyDigest(
  ctx: { uid: string; householdId: string; householdKey: string }
): Promise<Record<string, unknown>> {
  const now = new Date();
  const weekStart = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  const weekStartIso = weekStart.toISOString();
  const nowIso = now.toISOString();

  // Count documents created in the last 7 days across collections.
  const counts = await Promise.all([
    _countCreatedSince("tasks", ctx.householdId, weekStartIso),
    _countCompletedSince("tasks", ctx.householdId, weekStartIso),
    _countCreatedSince("plans", ctx.householdId, weekStartIso),
    _countCreatedSince("inventory_items", ctx.householdId, weekStartIso),
    _countCreatedSince("manual_entries", ctx.householdId, weekStartIso),
    _countCreatedSince("feedback", ctx.householdId, weekStartIso),
    _countCreatedSince("diagnostics", ctx.householdId, weekStartIso),
  ]);

  const [
    tasksCreated,
    tasksCompleted,
    plansCreated,
    inventoryItemsAdded,
    manualEntriesCreated,
    feedbackSubmitted,
    errorsLogged,
  ] = counts;

  const digestId = `${ctx.householdId}_${weekStart.toISOString().split("T")[0]}`;

  const digest = {
    id: digestId,
    household_id: ctx.householdId,
    week_starting: weekStartIso,
    week_ending: nowIso,
    tasks_created: tasksCreated,
    tasks_completed: tasksCompleted,
    checklist_items_checked: 0, // would need a checked_at field to count
    plans_created: plansCreated,
    inventory_items_added: inventoryItemsAdded,
    manual_entries_created: manualEntriesCreated,
    ai_chat_messages: 0, // would need chat log collection to count
    feedback_submitted: feedbackSubmitted,
    errors_logged: errorsLogged,
    summary: null,
    created_at: nowIso,
  };

  // Upsert the digest document.
  await getDb().collection("weekly_digests").doc(digestId).set(digest, { merge: true });

  return digest;
}

export async function listDigests(
  ctx: { uid: string; householdId: string; householdKey: string },
  params: { limit?: number }
): Promise<unknown[]> {
  const { decN } = createFieldCrypto(ctx.householdKey);
  const snap = await getDb()
    .collection("weekly_digests")
    .where("household_id", "==", ctx.householdId)
    .orderBy("week_starting", "desc")
    .limit(params.limit ?? 12)
    .get();

  return snap.docs.map((d) => {
    const data = d.data();
    return {
      ...data,
      summary: decN(data.summary),
    };
  });
}

// ── Helpers ──

async function _countCreatedSince(
  collection: string,
  householdId: string,
  sinceIso: string
): Promise<number> {
  const snap = await getDb()
    .collection(collection)
    .where("household_id", "==", householdId)
    .where("created_at", ">=", sinceIso)
    .get();
  return snap.size;
}

async function _countCompletedSince(
  collection: string,
  householdId: string,
  sinceIso: string
): Promise<number> {
  // Tasks use status=completed + completed_at timestamp.
  const snap = await getDb()
    .collection(collection)
    .where("household_id", "==", householdId)
    .where("status", "==", "completed")
    .where("completed_at", ">=", sinceIso)
    .get();
  return snap.size;
}
