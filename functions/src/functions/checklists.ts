/**
 * Checklist API endpoints for Pacelli Cloud Functions.
 *
 * Maps to DataRepository checklist methods in firebase_data_repository.dart.
 * Encrypted fields: title (checklist + items), quantity (items).
 */
import * as admin from "firebase-admin";
import { AuthContext } from "../middleware/auth";
import { createFieldCrypto } from "../middleware/encryption";
import {
  Checklist,
  ChecklistItem,
  CreateChecklistRequest,
  AddChecklistItemRequest,
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

// ── List Checklists ──

export async function listChecklists(
  ctx: AuthContext
): Promise<Checklist[]> {
  const { dec, decN } = createFieldCrypto(ctx.householdKey);

  const snapshot = await db()
    .collection("checklists")
    .where("household_id", "==", ctx.householdId)
    .get();

  const checklists = await Promise.all(
    snapshot.docs.map(async (doc) => {
      const d = doc.data();

      // Load items
      const itemSnap = await db()
        .collection("checklist_items")
        .where("checklist_id", "==", doc.id)
        .where("household_id", "==", ctx.householdId)
        .get();

      const items: ChecklistItem[] = itemSnap.docs.map((i) => {
        const id = i.data();
        return {
          id: i.id,
          checklistId: id.checklist_id,
          householdId: id.household_id,
          title: dec(id.title ?? ""),
          quantity: decN(id.quantity),
          isChecked: id.is_checked ?? false,
          createdBy: id.created_by ?? null,
          createdAt: parseTimestamp(id.created_at),
          checkedAt: parseTimestamp(id.checked_at),
          checkedBy: id.checked_by ?? null,
        };
      });

      return {
        id: doc.id,
        householdId: d.household_id,
        title: dec(d.title ?? ""),
        createdBy: d.created_by,
        createdAt: parseTimestamp(d.created_at) ?? new Date().toISOString(),
        updatedAt: parseTimestamp(d.updated_at),
        items,
      };
    })
  );

  return checklists;
}

// ── Get Single Checklist ──

export async function getChecklist(
  ctx: AuthContext,
  checklistId: string
): Promise<Checklist | null> {
  const { dec, decN } = createFieldCrypto(ctx.householdKey);

  const doc = await db().collection("checklists").doc(checklistId).get();
  if (!doc.exists) return null;

  const d = doc.data()!;
  if (d.household_id !== ctx.householdId) return null;

  const itemSnap = await db()
    .collection("checklist_items")
    .where("checklist_id", "==", checklistId)
    .where("household_id", "==", ctx.householdId)
    .get();

  const items: ChecklistItem[] = itemSnap.docs.map((i) => {
    const id = i.data();
    return {
      id: i.id,
      checklistId: id.checklist_id,
      householdId: id.household_id,
      title: dec(id.title ?? ""),
      quantity: decN(id.quantity),
      isChecked: id.is_checked ?? false,
      createdBy: id.created_by ?? null,
      createdAt: parseTimestamp(id.created_at),
      checkedAt: parseTimestamp(id.checked_at),
      checkedBy: id.checked_by ?? null,
    };
  });

  return {
    id: doc.id,
    householdId: d.household_id,
    title: dec(d.title ?? ""),
    createdBy: d.created_by,
    createdAt: parseTimestamp(d.created_at) ?? new Date().toISOString(),
    updatedAt: parseTimestamp(d.updated_at),
    items,
  };
}

// ── Create Checklist ──

export async function createChecklist(
  ctx: AuthContext,
  req: CreateChecklistRequest
): Promise<Checklist> {
  const { enc } = createFieldCrypto(ctx.householdKey);
  const now = new Date().toISOString();

  const ref = db().collection("checklists").doc();
  await ref.set({
    household_id: ctx.householdId,
    title: enc(req.title),
    created_by: ctx.uid,
    created_at: now,
    updated_at: now,
  });

  return {
    id: ref.id,
    householdId: ctx.householdId,
    title: req.title,
    createdBy: ctx.uid,
    createdAt: now,
    updatedAt: now,
    items: [],
  };
}

// ── Update Checklist ──

export async function updateChecklist(
  ctx: AuthContext,
  checklistId: string,
  title: string
): Promise<Checklist | null> {
  const { enc } = createFieldCrypto(ctx.householdKey);

  const ref = db().collection("checklists").doc(checklistId);
  const doc = await ref.get();
  if (!doc.exists || doc.data()!.household_id !== ctx.householdId) return null;

  await ref.update({
    title: enc(title),
    updated_at: new Date().toISOString(),
  });

  return getChecklist(ctx, checklistId);
}

// ── Delete Checklist ──

export async function deleteChecklist(
  ctx: AuthContext,
  checklistId: string
): Promise<boolean> {
  const ref = db().collection("checklists").doc(checklistId);
  const doc = await ref.get();
  if (!doc.exists || doc.data()!.household_id !== ctx.householdId) return false;

  // Delete items first
  const itemSnap = await db()
    .collection("checklist_items")
    .where("checklist_id", "==", checklistId)
    .where("household_id", "==", ctx.householdId)
    .get();

  const batch = db().batch();
  itemSnap.docs.forEach((i) => batch.delete(i.ref));
  batch.delete(ref);
  await batch.commit();

  return true;
}

// ── Add Checklist Item ──

export async function addChecklistItem(
  ctx: AuthContext,
  req: AddChecklistItemRequest
): Promise<ChecklistItem> {
  const { enc, encN } = createFieldCrypto(ctx.householdKey);

  // Verify checklist belongs to household
  const clDoc = await db().collection("checklists").doc(req.checklistId).get();
  if (!clDoc.exists || clDoc.data()!.household_id !== ctx.householdId) {
    throw new Error("Checklist not found or access denied");
  }

  const ref = db().collection("checklist_items").doc();
  const now = new Date().toISOString();

  await ref.set({
    checklist_id: req.checklistId,
    household_id: ctx.householdId,
    title: enc(req.title),
    quantity: encN(req.quantity ?? null),
    is_checked: false,
    created_by: ctx.uid,
    created_at: now,
    checked_at: null,
    checked_by: null,
  });

  // Update checklist timestamp
  await clDoc.ref.update({ updated_at: now });

  return {
    id: ref.id,
    checklistId: req.checklistId,
    householdId: ctx.householdId,
    title: req.title,
    quantity: req.quantity ?? null,
    isChecked: false,
    createdBy: ctx.uid,
    createdAt: now,
    checkedAt: null,
    checkedBy: null,
  };
}

// ── Toggle Checklist Item ──

export async function toggleChecklistItem(
  ctx: AuthContext,
  itemId: string,
  isChecked: boolean
): Promise<boolean> {
  const ref = db().collection("checklist_items").doc(itemId);
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

// ── Delete Checklist Item ──

export async function deleteChecklistItem(
  ctx: AuthContext,
  itemId: string
): Promise<boolean> {
  const ref = db().collection("checklist_items").doc(itemId);
  const doc = await ref.get();
  if (!doc.exists || doc.data()!.household_id !== ctx.householdId) return false;

  await ref.delete();
  return true;
}

// ── Push Checklist Item as Task ──

export async function pushChecklistItemAsTask(
  ctx: AuthContext,
  itemId: string,
  itemTitle: string
): Promise<boolean> {
  const { enc } = createFieldCrypto(ctx.householdKey);

  // Verify item belongs to household
  const itemRef = db().collection("checklist_items").doc(itemId);
  const itemDoc = await itemRef.get();
  if (!itemDoc.exists || itemDoc.data()!.household_id !== ctx.householdId) {
    return false;
  }

  const now = new Date().toISOString();

  // Create task from item
  const taskRef = db().collection("tasks").doc();
  const batch = db().batch();

  batch.set(taskRef, {
    household_id: ctx.householdId,
    title: enc(itemTitle),
    description: null,
    category_id: null,
    priority: "medium",
    status: "pending",
    due_date: null,
    start_date: null,
    assigned_to: null,
    is_shared: false,
    recurrence: "none",
    created_by: ctx.uid,
    created_at: now,
    completed_at: null,
    completed_by: null,
  });

  // Delete the checklist item
  batch.delete(itemRef);

  await batch.commit();
  return true;
}

// ── Push Plan Checklist Item as Task ──

export async function pushPlanChecklistItemAsTask(
  ctx: AuthContext,
  itemId: string,
  itemTitle: string
): Promise<boolean> {
  const { enc } = createFieldCrypto(ctx.householdKey);

  const itemRef = db().collection("plan_checklist_items").doc(itemId);
  const itemDoc = await itemRef.get();
  if (!itemDoc.exists || itemDoc.data()!.household_id !== ctx.householdId) {
    return false;
  }

  const now = new Date().toISOString();

  const taskRef = db().collection("tasks").doc();
  const batch = db().batch();

  batch.set(taskRef, {
    household_id: ctx.householdId,
    title: enc(itemTitle),
    description: null,
    category_id: null,
    priority: "medium",
    status: "pending",
    due_date: null,
    start_date: null,
    assigned_to: null,
    is_shared: false,
    recurrence: "none",
    created_by: ctx.uid,
    created_at: now,
    completed_at: null,
    completed_by: null,
  });

  batch.delete(itemRef);
  await batch.commit();
  return true;
}
