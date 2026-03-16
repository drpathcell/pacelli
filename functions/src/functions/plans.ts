/**
 * Plan API endpoints for Pacelli Cloud Functions.
 *
 * Maps to DataRepository plan methods in firebase_data_repository.dart.
 * Encrypted fields: title/label/description (plan + entries),
 * title/quantity (plan checklist items), templateName.
 */
import * as admin from "firebase-admin";
import { AuthContext } from "../middleware/auth";
import { createFieldCrypto } from "../middleware/encryption";
import {
  Plan,
  PlanEntry,
  PlanChecklistItem,
  CreatePlanRequest,
  AddPlanEntryRequest,
  UpdatePlanEntryRequest,
  AddPlanChecklistItemRequest,
  SaveAsTemplateRequest,
  CreateFromTemplateRequest,
  FinalisePlanRequest,
} from "../types/models";

const db = () => admin.firestore();

function parseTimestamp(val: unknown): string | null {
  if (!val) return null;
  if (val instanceof admin.firestore.Timestamp) {
    return val.toDate().toISOString();
  }
  if (typeof val === "string") return val;
  return null;
}

function dateOnly(iso: string): string {
  return iso.substring(0, 10); // YYYY-MM-DD
}

// ═══════════════════════════════════════════════════════════════════
//  PLANS
// ═══════════════════════════════════════════════════════════════════

export async function listPlans(ctx: AuthContext): Promise<Plan[]> {
  const { dec, decN } = createFieldCrypto(ctx.householdKey);

  const snapshot = await db()
    .collection("plans")
    .where("household_id", "==", ctx.householdId)
    .where("is_template", "==", false)
    .get();

  return Promise.all(
    snapshot.docs.map((doc) => buildPlan(ctx, doc.id, doc.data(), dec, decN))
  );
}

export async function getPlan(
  ctx: AuthContext,
  planId: string
): Promise<Plan | null> {
  const { dec, decN } = createFieldCrypto(ctx.householdKey);

  const doc = await db().collection("plans").doc(planId).get();
  if (!doc.exists) return null;

  const d = doc.data()!;
  if (d.household_id !== ctx.householdId) return null;

  return buildPlan(ctx, doc.id, d, dec, decN);
}

async function buildPlan(
  ctx: AuthContext,
  id: string,
  d: admin.firestore.DocumentData,
  dec: (s: string) => string,
  decN: (s: string | null | undefined) => string | null
): Promise<Plan> {
  // Load entries and checklist items in parallel
  const [entrySnap, checklistSnap] = await Promise.all([
    db()
      .collection("plan_entries")
      .where("plan_id", "==", id)
      .where("household_id", "==", ctx.householdId)
      .orderBy("entry_date")
      .orderBy("sort_order")
      .get(),
    db()
      .collection("plan_checklist_items")
      .where("plan_id", "==", id)
      .where("household_id", "==", ctx.householdId)
      .get(),
  ]);

  const entries: PlanEntry[] = entrySnap.docs.map((e) => {
    const ed = e.data();
    return {
      id: e.id,
      planId: ed.plan_id,
      householdId: ed.household_id,
      entryDate: ed.entry_date,
      title: dec(ed.title ?? ""),
      label: decN(ed.label),
      description: decN(ed.description),
      sortOrder: ed.sort_order ?? 0,
      createdBy: ed.created_by ?? null,
      createdAt: parseTimestamp(ed.created_at),
    };
  });

  const checklistItems: PlanChecklistItem[] = checklistSnap.docs.map((c) => {
    const cd = c.data();
    return {
      id: c.id,
      planId: cd.plan_id,
      householdId: cd.household_id,
      entryId: cd.entry_id ?? null,
      title: dec(cd.title ?? ""),
      quantity: decN(cd.quantity),
      isChecked: cd.is_checked ?? false,
      createdBy: cd.created_by ?? null,
      createdAt: parseTimestamp(cd.created_at),
      checkedAt: parseTimestamp(cd.checked_at),
      checkedBy: cd.checked_by ?? null,
    };
  });

  return {
    id,
    householdId: d.household_id,
    title: dec(d.title ?? ""),
    type: d.type ?? "weekly",
    status: d.status ?? "draft",
    startDate: d.start_date,
    endDate: d.end_date,
    isTemplate: d.is_template ?? false,
    templateName: decN(d.template_name),
    createdBy: d.created_by,
    createdAt: parseTimestamp(d.created_at) ?? new Date().toISOString(),
    updatedAt: parseTimestamp(d.updated_at),
    entries,
    checklistItems,
  };
}

export async function createPlan(
  ctx: AuthContext,
  req: CreatePlanRequest
): Promise<Plan> {
  const { enc, encN } = createFieldCrypto(ctx.householdKey);
  const now = new Date().toISOString();

  const ref = db().collection("plans").doc();
  await ref.set({
    household_id: ctx.householdId,
    title: enc(req.title),
    type: req.type ?? "weekly",
    status: "draft",
    start_date: req.startDate,
    end_date: req.endDate,
    is_template: req.isTemplate ?? false,
    template_name: encN(req.templateName ?? null),
    created_by: ctx.uid,
    created_at: now,
    updated_at: now,
  });

  return (await getPlan(ctx, ref.id))!;
}

export async function deletePlan(
  ctx: AuthContext,
  planId: string
): Promise<boolean> {
  const ref = db().collection("plans").doc(planId);
  const doc = await ref.get();
  if (!doc.exists || doc.data()!.household_id !== ctx.householdId) return false;

  // Delete entries, checklist items, and attachments
  const [entrySnap, checklistSnap, attachSnap] = await Promise.all([
    db()
      .collection("plan_entries")
      .where("plan_id", "==", planId)
      .where("household_id", "==", ctx.householdId)
      .get(),
    db()
      .collection("plan_checklist_items")
      .where("plan_id", "==", planId)
      .where("household_id", "==", ctx.householdId)
      .get(),
    db()
      .collection("plan_attachments")
      .where("plan_id", "==", planId)
      .where("household_id", "==", ctx.householdId)
      .get(),
  ]);

  const batch = db().batch();
  entrySnap.docs.forEach((d) => batch.delete(d.ref));
  checklistSnap.docs.forEach((d) => batch.delete(d.ref));
  attachSnap.docs.forEach((d) => batch.delete(d.ref));
  batch.delete(ref);
  await batch.commit();

  return true;
}

export async function updatePlanStatus(
  ctx: AuthContext,
  planId: string,
  status: string
): Promise<boolean> {
  const ref = db().collection("plans").doc(planId);
  const doc = await ref.get();
  if (!doc.exists || doc.data()!.household_id !== ctx.householdId) return false;

  await ref.update({
    status,
    updated_at: new Date().toISOString(),
  });
  return true;
}

// ═══════════════════════════════════════════════════════════════════
//  PLAN ENTRIES
// ═══════════════════════════════════════════════════════════════════

export async function addPlanEntry(
  ctx: AuthContext,
  req: AddPlanEntryRequest
): Promise<PlanEntry> {
  const { enc, encN } = createFieldCrypto(ctx.householdKey);

  // Verify plan belongs to household
  const planDoc = await db().collection("plans").doc(req.planId).get();
  if (!planDoc.exists || planDoc.data()!.household_id !== ctx.householdId) {
    throw new Error("Plan not found or access denied");
  }

  const ref = db().collection("plan_entries").doc();
  const now = new Date().toISOString();

  await ref.set({
    plan_id: req.planId,
    household_id: ctx.householdId,
    entry_date: req.entryDate,
    title: enc(req.title),
    label: encN(req.label ?? null),
    description: encN(req.description ?? null),
    sort_order: req.sortOrder ?? 0,
    created_by: ctx.uid,
    created_at: now,
  });

  // Update plan timestamp
  await planDoc.ref.update({ updated_at: now });

  return {
    id: ref.id,
    planId: req.planId,
    householdId: ctx.householdId,
    entryDate: req.entryDate,
    title: req.title,
    label: req.label ?? null,
    description: req.description ?? null,
    sortOrder: req.sortOrder ?? 0,
    createdBy: ctx.uid,
    createdAt: now,
  };
}

export async function updatePlanEntry(
  ctx: AuthContext,
  req: UpdatePlanEntryRequest
): Promise<boolean> {
  const { enc, encN } = createFieldCrypto(ctx.householdKey);

  const ref = db().collection("plan_entries").doc(req.entryId);
  const doc = await ref.get();
  if (!doc.exists || doc.data()!.household_id !== ctx.householdId) return false;

  const updates: Record<string, unknown> = {};
  if (req.title !== undefined) updates.title = enc(req.title);
  if (req.label !== undefined) updates.label = encN(req.label ?? null);
  if (req.description !== undefined)
    updates.description = encN(req.description ?? null);

  if (Object.keys(updates).length > 0) {
    await ref.update(updates);
  }
  return true;
}

export async function deletePlanEntry(
  ctx: AuthContext,
  entryId: string
): Promise<boolean> {
  const ref = db().collection("plan_entries").doc(entryId);
  const doc = await ref.get();
  if (!doc.exists || doc.data()!.household_id !== ctx.householdId) return false;

  await ref.delete();
  return true;
}

// ═══════════════════════════════════════════════════════════════════
//  PLAN CHECKLIST ITEMS
// ═══════════════════════════════════════════════════════════════════

export async function addPlanChecklistItem(
  ctx: AuthContext,
  req: AddPlanChecklistItemRequest
): Promise<PlanChecklistItem> {
  const { enc, encN } = createFieldCrypto(ctx.householdKey);

  // Verify plan belongs to household
  const planDoc = await db().collection("plans").doc(req.planId).get();
  if (!planDoc.exists || planDoc.data()!.household_id !== ctx.householdId) {
    throw new Error("Plan not found or access denied");
  }

  const ref = db().collection("plan_checklist_items").doc();
  const now = new Date().toISOString();

  await ref.set({
    plan_id: req.planId,
    household_id: ctx.householdId,
    entry_id: req.entryId ?? null,
    title: enc(req.title),
    quantity: encN(req.quantity ?? null),
    is_checked: false,
    created_by: ctx.uid,
    created_at: now,
    checked_at: null,
    checked_by: null,
  });

  return {
    id: ref.id,
    planId: req.planId,
    householdId: ctx.householdId,
    entryId: req.entryId ?? null,
    title: req.title,
    quantity: req.quantity ?? null,
    isChecked: false,
    createdBy: ctx.uid,
    createdAt: now,
    checkedAt: null,
    checkedBy: null,
  };
}

export async function togglePlanChecklistItem(
  ctx: AuthContext,
  itemId: string,
  isChecked: boolean
): Promise<boolean> {
  const ref = db().collection("plan_checklist_items").doc(itemId);
  const doc = await ref.get();
  if (!doc.exists || doc.data()!.household_id !== ctx.householdId) return false;

  const updates: Record<string, unknown> = {
    is_checked: isChecked,
  };
  if (isChecked) {
    updates.checked_at = new Date().toISOString();
    updates.checked_by = ctx.uid;
  } else {
    updates.checked_at = null;
    updates.checked_by = null;
  }

  await ref.update(updates);
  return true;
}

export async function deletePlanChecklistItem(
  ctx: AuthContext,
  itemId: string
): Promise<boolean> {
  const ref = db().collection("plan_checklist_items").doc(itemId);
  const doc = await ref.get();
  if (!doc.exists || doc.data()!.household_id !== ctx.householdId) return false;

  await ref.delete();
  return true;
}

// ═══════════════════════════════════════════════════════════════════
//  TEMPLATES
// ═══════════════════════════════════════════════════════════════════

export async function getTemplates(ctx: AuthContext): Promise<Plan[]> {
  const { dec, decN } = createFieldCrypto(ctx.householdKey);

  const snapshot = await db()
    .collection("plans")
    .where("household_id", "==", ctx.householdId)
    .where("is_template", "==", true)
    .get();

  return Promise.all(
    snapshot.docs.map((doc) => buildPlan(ctx, doc.id, doc.data(), dec, decN))
  );
}

export async function savePlanAsTemplate(
  ctx: AuthContext,
  req: SaveAsTemplateRequest
): Promise<Plan | null> {
  const { enc } = createFieldCrypto(ctx.householdKey);

  // Load source plan
  const srcDoc = await db().collection("plans").doc(req.planId).get();
  if (!srcDoc.exists || srcDoc.data()!.household_id !== ctx.householdId) {
    return null;
  }

  const src = srcDoc.data()!;
  const now = new Date().toISOString();

  // Create template plan
  const templateRef = db().collection("plans").doc();
  await templateRef.set({
    household_id: ctx.householdId,
    title: src.title, // Already encrypted
    type: src.type,
    status: "draft",
    start_date: src.start_date,
    end_date: src.end_date,
    is_template: true,
    template_name: enc(req.templateName),
    created_by: ctx.uid,
    created_at: now,
    updated_at: now,
  });

  // Copy entries
  const entrySnap = await db()
    .collection("plan_entries")
    .where("plan_id", "==", req.planId)
    .where("household_id", "==", ctx.householdId)
    .get();

  if (entrySnap.docs.length > 0) {
    const batch = db().batch();
    for (const e of entrySnap.docs) {
      const newRef = db().collection("plan_entries").doc();
      batch.set(newRef, {
        ...e.data(),
        plan_id: templateRef.id,
        created_at: now,
      });
    }
    await batch.commit();
  }

  // Copy checklist items
  const checklistSnap = await db()
    .collection("plan_checklist_items")
    .where("plan_id", "==", req.planId)
    .where("household_id", "==", ctx.householdId)
    .get();

  if (checklistSnap.docs.length > 0) {
    const batch = db().batch();
    for (const c of checklistSnap.docs) {
      const newRef = db().collection("plan_checklist_items").doc();
      batch.set(newRef, {
        ...c.data(),
        plan_id: templateRef.id,
        is_checked: false,
        checked_at: null,
        checked_by: null,
        created_at: now,
      });
    }
    await batch.commit();
  }

  return getPlan(ctx, templateRef.id);
}

export async function createFromTemplate(
  ctx: AuthContext,
  req: CreateFromTemplateRequest
): Promise<Plan | null> {
  const { enc } = createFieldCrypto(ctx.householdKey);

  // Load template
  const templateDoc = await db().collection("plans").doc(req.templateId).get();
  if (!templateDoc.exists || templateDoc.data()!.household_id !== ctx.householdId) {
    return null;
  }
  if (!templateDoc.data()!.is_template) return null;

  const tmpl = templateDoc.data()!;
  const now = new Date().toISOString();

  // Calculate date offset for shifting entries
  const templateStart = new Date(tmpl.start_date);
  const newStart = new Date(req.startDate);
  const dayOffset = Math.round(
    (newStart.getTime() - templateStart.getTime()) / (1000 * 60 * 60 * 24)
  );

  // Create new plan
  const planRef = db().collection("plans").doc();
  await planRef.set({
    household_id: ctx.householdId,
    title: enc(req.title),
    type: tmpl.type,
    status: "draft",
    start_date: req.startDate,
    end_date: req.endDate,
    is_template: false,
    template_name: null,
    created_by: ctx.uid,
    created_at: now,
    updated_at: now,
  });

  // Copy entries with shifted dates
  const entrySnap = await db()
    .collection("plan_entries")
    .where("plan_id", "==", req.templateId)
    .where("household_id", "==", ctx.householdId)
    .get();

  const entryIdMap: Record<string, string> = {};

  if (entrySnap.docs.length > 0) {
    const batch = db().batch();
    for (const e of entrySnap.docs) {
      const ed = e.data();
      const oldDate = new Date(ed.entry_date);
      oldDate.setDate(oldDate.getDate() + dayOffset);
      const newDate = dateOnly(oldDate.toISOString());

      const newRef = db().collection("plan_entries").doc();
      entryIdMap[e.id] = newRef.id;

      batch.set(newRef, {
        plan_id: planRef.id,
        household_id: ctx.householdId,
        entry_date: newDate,
        title: ed.title, // Already encrypted
        label: ed.label,
        description: ed.description,
        sort_order: ed.sort_order ?? 0,
        created_by: ctx.uid,
        created_at: now,
      });
    }
    await batch.commit();
  }

  // Copy checklist items with remapped entry IDs
  const checklistSnap = await db()
    .collection("plan_checklist_items")
    .where("plan_id", "==", req.templateId)
    .where("household_id", "==", ctx.householdId)
    .get();

  if (checklistSnap.docs.length > 0) {
    const batch = db().batch();
    for (const c of checklistSnap.docs) {
      const cd = c.data();
      const newRef = db().collection("plan_checklist_items").doc();
      batch.set(newRef, {
        plan_id: planRef.id,
        household_id: ctx.householdId,
        entry_id: cd.entry_id ? (entryIdMap[cd.entry_id] ?? null) : null,
        title: cd.title, // Already encrypted
        quantity: cd.quantity,
        is_checked: false,
        checked_at: null,
        checked_by: null,
        created_by: ctx.uid,
        created_at: now,
      });
    }
    await batch.commit();
  }

  return getPlan(ctx, planRef.id);
}

// ═══════════════════════════════════════════════════════════════════
//  FINALISE PLAN
// ═══════════════════════════════════════════════════════════════════

export async function finalisePlan(
  ctx: AuthContext,
  req: FinalisePlanRequest
): Promise<boolean> {
  const { enc, dec } = createFieldCrypto(ctx.householdKey);

  const planRef = db().collection("plans").doc(req.planId);
  const planDoc = await planRef.get();
  if (!planDoc.exists || planDoc.data()!.household_id !== ctx.householdId) {
    return false;
  }

  // Load entries
  const entrySnap = await db()
    .collection("plan_entries")
    .where("plan_id", "==", req.planId)
    .where("household_id", "==", ctx.householdId)
    .get();

  const now = new Date().toISOString();
  const batch = db().batch();

  for (const e of entrySnap.docs) {
    const action = req.entryActions[e.id];
    if (!action || action === "skip") continue;

    const ed = e.data();
    const entryTitle = dec(ed.title ?? "");

    if (action === "task") {
      // Create task from entry
      const taskRef = db().collection("tasks").doc();
      batch.set(taskRef, {
        household_id: ctx.householdId,
        title: enc(entryTitle),
        description: ed.description, // Already encrypted
        category_id: null,
        priority: "medium",
        status: "pending",
        due_date: ed.entry_date,
        start_date: null,
        assigned_to: null,
        is_shared: false,
        recurrence: "none",
        created_by: ctx.uid,
        created_at: now,
        completed_at: null,
        completed_by: null,
      });
    }
    // 'note' action could create a different entity if needed
  }

  // Mark plan as finalised
  batch.update(planRef, {
    status: "finalised",
    updated_at: now,
  });

  await batch.commit();
  return true;
}
