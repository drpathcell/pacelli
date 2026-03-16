/**
 * Attachment API endpoints (Task + Plan) for Pacelli Cloud Functions.
 *
 * Encrypted fields: fileName, description.
 */
import * as admin from "firebase-admin";
import { AuthContext } from "../middleware/auth";
import { createFieldCrypto } from "../middleware/encryption";
import {
  TaskAttachment,
  PlanAttachment,
  CreateAttachmentRequest,
  CreatePlanAttachmentRequest,
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

// ═══════════════════════════════════════════════════════════════════
//  TASK ATTACHMENTS
// ═══════════════════════════════════════════════════════════════════

export async function createTaskAttachment(
  ctx: AuthContext,
  req: CreateAttachmentRequest
): Promise<TaskAttachment> {
  const { enc, encN } = createFieldCrypto(ctx.householdKey);

  // Verify task belongs to household
  const taskDoc = await db().collection("tasks").doc(req.taskId).get();
  if (!taskDoc.exists || taskDoc.data()!.household_id !== ctx.householdId) {
    throw new Error("Task not found or access denied");
  }

  const ref = db().collection("task_attachments").doc();
  const now = new Date().toISOString();

  await ref.set({
    task_id: req.taskId,
    household_id: ctx.householdId,
    drive_file_id: req.driveFileId,
    file_name: enc(req.fileName),
    mime_type: req.mimeType,
    file_size_bytes: req.fileSizeBytes,
    thumbnail_url: req.thumbnailUrl ?? null,
    web_view_link: req.webViewLink,
    description: encN(req.description ?? null),
    uploaded_by: ctx.uid,
    uploaded_at: now,
  });

  return {
    id: ref.id,
    taskId: req.taskId,
    householdId: ctx.householdId,
    driveFileId: req.driveFileId,
    fileName: req.fileName,
    mimeType: req.mimeType,
    fileSizeBytes: req.fileSizeBytes,
    thumbnailUrl: req.thumbnailUrl ?? null,
    webViewLink: req.webViewLink,
    uploadedBy: ctx.uid,
    uploadedAt: now,
    description: req.description ?? null,
  };
}

export async function getTaskAttachments(
  ctx: AuthContext,
  taskId: string
): Promise<TaskAttachment[]> {
  const { dec, decN } = createFieldCrypto(ctx.householdKey);

  const snapshot = await db()
    .collection("task_attachments")
    .where("task_id", "==", taskId)
    .where("household_id", "==", ctx.householdId)
    .get();

  return snapshot.docs.map((doc) => {
    const d = doc.data();
    return {
      id: doc.id,
      taskId: d.task_id,
      householdId: d.household_id,
      driveFileId: d.drive_file_id,
      fileName: dec(d.file_name ?? ""),
      mimeType: d.mime_type,
      fileSizeBytes: d.file_size_bytes ?? 0,
      thumbnailUrl: d.thumbnail_url ?? null,
      webViewLink: d.web_view_link,
      uploadedBy: d.uploaded_by,
      uploadedAt: parseTimestamp(d.uploaded_at) ?? new Date().toISOString(),
      description: decN(d.description),
    };
  });
}

export async function deleteTaskAttachment(
  ctx: AuthContext,
  attachmentId: string
): Promise<boolean> {
  const ref = db().collection("task_attachments").doc(attachmentId);
  const doc = await ref.get();
  if (!doc.exists || doc.data()!.household_id !== ctx.householdId) return false;

  await ref.delete();
  return true;
}

// ═══════════════════════════════════════════════════════════════════
//  PLAN ATTACHMENTS
// ═══════════════════════════════════════════════════════════════════

export async function createPlanAttachment(
  ctx: AuthContext,
  req: CreatePlanAttachmentRequest
): Promise<PlanAttachment> {
  const { enc, encN } = createFieldCrypto(ctx.householdKey);

  // Verify plan belongs to household
  const planDoc = await db().collection("plans").doc(req.planId).get();
  if (!planDoc.exists || planDoc.data()!.household_id !== ctx.householdId) {
    throw new Error("Plan not found or access denied");
  }

  const ref = db().collection("plan_attachments").doc();
  const now = new Date().toISOString();

  await ref.set({
    plan_id: req.planId,
    entry_id: req.entryId,
    household_id: ctx.householdId,
    drive_file_id: req.driveFileId,
    file_name: enc(req.fileName),
    mime_type: req.mimeType,
    file_size_bytes: req.fileSizeBytes,
    thumbnail_url: req.thumbnailUrl ?? null,
    web_view_link: req.webViewLink,
    description: encN(req.description ?? null),
    uploaded_by: ctx.uid,
    uploaded_at: now,
  });

  return {
    id: ref.id,
    planId: req.planId,
    entryId: req.entryId,
    householdId: ctx.householdId,
    driveFileId: req.driveFileId,
    fileName: req.fileName,
    mimeType: req.mimeType,
    fileSizeBytes: req.fileSizeBytes,
    thumbnailUrl: req.thumbnailUrl ?? null,
    webViewLink: req.webViewLink,
    uploadedBy: ctx.uid,
    uploadedAt: now,
    description: req.description ?? null,
  };
}

export async function getPlanEntryAttachments(
  ctx: AuthContext,
  entryId: string
): Promise<PlanAttachment[]> {
  const { dec, decN } = createFieldCrypto(ctx.householdKey);

  const snapshot = await db()
    .collection("plan_attachments")
    .where("entry_id", "==", entryId)
    .where("household_id", "==", ctx.householdId)
    .get();

  return snapshot.docs.map((doc) => buildPlanAttachment(doc, dec, decN));
}

export async function getPlanAttachments(
  ctx: AuthContext,
  planId: string
): Promise<PlanAttachment[]> {
  const { dec, decN } = createFieldCrypto(ctx.householdKey);

  const snapshot = await db()
    .collection("plan_attachments")
    .where("plan_id", "==", planId)
    .where("household_id", "==", ctx.householdId)
    .get();

  return snapshot.docs.map((doc) => buildPlanAttachment(doc, dec, decN));
}

export async function deletePlanAttachment(
  ctx: AuthContext,
  attachmentId: string
): Promise<boolean> {
  const ref = db().collection("plan_attachments").doc(attachmentId);
  const doc = await ref.get();
  if (!doc.exists || doc.data()!.household_id !== ctx.householdId) return false;

  await ref.delete();
  return true;
}

function buildPlanAttachment(
  doc: admin.firestore.QueryDocumentSnapshot,
  dec: (s: string) => string,
  decN: (s: string | null | undefined) => string | null
): PlanAttachment {
  const d = doc.data();
  return {
    id: doc.id,
    planId: d.plan_id,
    entryId: d.entry_id,
    householdId: d.household_id,
    driveFileId: d.drive_file_id,
    fileName: dec(d.file_name ?? ""),
    mimeType: d.mime_type,
    fileSizeBytes: d.file_size_bytes ?? 0,
    thumbnailUrl: d.thumbnail_url ?? null,
    webViewLink: d.web_view_link,
    uploadedBy: d.uploaded_by,
    uploadedAt: parseTimestamp(d.uploaded_at) ?? new Date().toISOString(),
    description: decN(d.description),
  };
}
