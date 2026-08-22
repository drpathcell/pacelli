/**
 * Photos — the only part of Pacelli whose payload is too big for Firestore.
 *
 * A document is capped at 1 MiB, so the encrypted image lives in Cloud Storage
 * and the document keeps only what is small: metadata, an encrypted thumbnail
 * of a few kilobytes, and the encrypted text Vision read on the device.
 *
 * **No client ever touches the bucket directly.** `storage.rules` denies every
 * path to everyone. Instead these handlers authenticate the caller the same way
 * every other endpoint does, check the photo belongs to their household, and
 * mint a signed URL good for one object for a few minutes.
 *
 * That is not the design this started with. The first attempt mirrored
 * `isMember` inside the Storage rules with `firestore.exists`; it compiled and
 * deployed and then refused a real member's own upload, with both documented
 * IAM grants in place. Moving the decision here made it stricter rather than
 * looser: one definition of "member", no standing bucket credential anywhere,
 * and URLs that expire.
 */
import * as admin from "firebase-admin";
import { onDocumentDeleted } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";

import { AuthContext } from "../middleware/auth";
import { createFieldCrypto } from "../middleware/encryption";
import { decryptBytes } from "../crypto/encryption-service";

const REGION = "us-central1";

/** Not `<project>.firebasestorage.app`: that domain is Google-owned and the
 *  GCS API will not mint it. A plainly named bucket behaves identically once
 *  linked to the project. */
export const PHOTO_BUCKET = "pacelli-35621-photos";

/** Long enough for a photo to upload on a bad connection, short enough that a
 *  URL found later in a log is already dead. */
const URL_TTL_MS = 15 * 60 * 1000;

/** How long a photo may sit half-uploaded before the app stops implying the
 *  full size is on its way.
 *
 *  Fourteen days, because the only device that can finish the upload is the one
 *  that took the photo, and a phone that has not opened Pacelli in a fortnight
 *  is not mid-upload — it is lost, broken, or replaced. Thirty days would leave
 *  "arriving…" on screen for a month; seven would give up on someone's holiday. */
const STRANDED_AFTER_MS = 14 * 24 * 60 * 60 * 1000;

const db = () => admin.firestore();
const bucket = () => admin.storage().bucket(PHOTO_BUCKET);

export function objectPath(householdId: string, photoId: string): string {
  return `households/${householdId}/photos/${photoId}.enc`;
}

function isoNow(): string {
  return new Date().toISOString();
}

/** The photo document, if it belongs to the caller's household. */
async function ownedPhoto(ctx: AuthContext, photoId: string) {
  if (!photoId || typeof photoId !== "string") {
    throw new Error("photoId is required");
  }
  const snap = await db().collection("photos").doc(photoId).get();
  if (!snap.exists || snap.data()!.household_id !== ctx.householdId) {
    throw new Error("Photo not found");
  }
  return snap;
}

// ═══════════════════════════════════════════════════════════════════
//  SIGNED URLS
// ═══════════════════════════════════════════════════════════════════

/**
 * A URL the device may PUT the encrypted image to.
 *
 * The document must already exist. That is not a quirk of this endpoint — it
 * is the ordering the whole feature rests on: the app writes the document
 * first, with the thumbnail in it, so the other household member sees the
 * photo while the upload is still running.
 */
export async function uploadUrl(
  ctx: AuthContext,
  params: { photoId: string }
): Promise<{ url: string; expiresAt: string; contentType: string }> {
  await ownedPhoto(ctx, params.photoId);
  const contentType = "application/octet-stream";
  const expires = Date.now() + URL_TTL_MS;

  const [url] = await bucket()
    .file(objectPath(ctx.householdId, params.photoId))
    .getSignedUrl({ version: "v4", action: "write", expires, contentType });

  return { url, expiresAt: new Date(expires).toISOString(), contentType };
}

/** A URL the device may GET the encrypted image from. Still ciphertext — the
 *  household key is not involved on this path at all. */
export async function downloadUrl(
  ctx: AuthContext,
  params: { photoId: string }
): Promise<{ url: string; expiresAt: string }> {
  await ownedPhoto(ctx, params.photoId);
  const expires = Date.now() + URL_TTL_MS;

  const [url] = await bucket()
    .file(objectPath(ctx.householdId, params.photoId))
    .getSignedUrl({ version: "v4", action: "read", expires });

  return { url, expiresAt: new Date(expires).toISOString() };
}

// ═══════════════════════════════════════════════════════════════════
//  READING — what an AI assistant sees
// ═══════════════════════════════════════════════════════════════════

interface PhotoSummary {
  id: string;
  subjectType: string;
  subjectId: string;
  categoryId: string | null;
  uploadState: string;
  caption: string | null;
  recognisedText: string | null;
  labels: string | null;
  width: number | null;
  height: number | null;
  byteSize: number | null;
  createdBy: string;
  createdAt: string;
}

function toSummary(id: string, d: FirebaseFirestore.DocumentData,
                   crypto: ReturnType<typeof createFieldCrypto>): PhotoSummary {
  return {
    id,
    subjectType: d.subject_type ?? "",
    subjectId: d.subject_id ?? "",
    categoryId: d.category_id ?? null,
    uploadState: d.upload_state ?? "ready",
    caption: crypto.decN(d.caption ?? null),
    recognisedText: crypto.decN(d.recognised_text ?? null),
    labels: crypto.decN(d.labels ?? null),
    width: d.width ?? null,
    height: d.height ?? null,
    byteSize: d.byte_size ?? null,
    createdBy: d.created_by ?? "",
    createdAt: d.created_at ?? "",
  };
}

/** Every photo in the household, newest first. */
export async function listPhotos(
  ctx: AuthContext,
  params: { subjectId?: string; limit?: number }
): Promise<PhotoSummary[]> {
  const crypto = createFieldCrypto(ctx.householdKey);
  let q = db().collection("photos")
    .where("household_id", "==", ctx.householdId) as FirebaseFirestore.Query;

  if (params.subjectId) q = q.where("subject_id", "==", params.subjectId);

  const snap = await q.get();
  const rows = snap.docs.map((d) => toSummary(d.id, d.data(), crypto));
  // Sorted here rather than in the query: adding an orderBy to an optional
  // second filter needs a composite index per combination, and this collection
  // is small enough per household that it is not worth four of them.
  rows.sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1));
  const limit = Math.min(Math.max(params.limit ?? 200, 1), 500);
  return rows.slice(0, limit);
}

/**
 * One photo, optionally including the picture itself.
 *
 * `includeImage` decrypts server-side and returns base64. That is a real
 * consideration and worth being explicit about: for the moment the image is
 * plaintext in this function's memory. It is the same posture every other
 * endpoint already takes — `createFieldCrypto` decrypts task titles, checklist
 * items and manual entries on exactly this path — so this extends an existing
 * trust boundary rather than crossing a new one. It is also what makes an AI
 * assistant able to actually look at the picture, which is the point.
 *
 * Nothing is logged, and the plaintext is never written anywhere.
 */
export async function getPhoto(
  ctx: AuthContext,
  params: { photoId: string; includeImage?: boolean }
): Promise<PhotoSummary & { imageBase64?: string; contentType?: string }> {
  const snap = await ownedPhoto(ctx, params.photoId);
  const crypto = createFieldCrypto(ctx.householdKey);
  const summary = toSummary(snap.id, snap.data()!, crypto);

  if (!params.includeImage) return summary;

  if (summary.uploadState !== "ready") {
    throw new Error(
      "That photo has not finished uploading from the device that took it"
    );
  }

  const [sealed] = await bucket()
    .file(objectPath(ctx.householdId, params.photoId))
    .download();

  const opened = decryptBytes(sealed, ctx.householdKey);
  return {
    ...summary,
    imageBase64: opened.toString("base64"),
    contentType: "image/jpeg",
  };
}

// ═══════════════════════════════════════════════════════════════════
//  DELETION — a consequence, never a checklist
// ═══════════════════════════════════════════════════════════════════

/**
 * Deleting the document deletes the object.
 *
 * This is the whole reason burn-all-data stays correct without knowing that
 * Cloud Storage exists. Burn walks its collection list and deletes documents;
 * the blobs go with them. So does a single photo deleted from the app, and so
 * does a household discarded as empty. One path, and nothing to remember.
 */
export const onPhotoDeleted = onDocumentDeleted(
  { document: "photos/{photoId}", region: REGION },
  async (event) => {
    const d = event.data?.data();
    if (!d?.household_id) return;
    const path = objectPath(d.household_id, event.params.photoId);
    try {
      await bucket().file(path).delete({ ignoreNotFound: true });
    } catch (e) {
      // A blob that outlives its document is invisible until someone looks,
      // so this is the one place in the feature that must complain loudly.
      logger.error("[onPhotoDeleted] could not delete object", { path, error: String(e) });
      throw e;
    }
  }
);

/**
 * Photos whose upload never finished stop pretending it is coming.
 *
 * The thumbnail lives in the document, so a stranded photo is still a picture
 * you can see and search — it is only the full size that is missing. Flipping
 * the state changes what the app says about it ("full size lost" rather than
 * "arriving"), and nothing else. It is reversible: if that phone ever comes
 * back and finishes, the upload patches the document to `ready` again.
 */
export const sweepStrandedPhotos = onSchedule(
  { schedule: "every 24 hours", region: REGION },
  async () => {
    const cutoff = new Date(Date.now() - STRANDED_AFTER_MS).toISOString();
    const snap = await db().collection("photos")
      .where("upload_state", "==", "pending")
      .where("created_at", "<", cutoff)
      .limit(500)
      .get();

    if (snap.empty) return;
    const batch = db().batch();
    snap.docs.forEach((doc) =>
      batch.update(doc.ref, { upload_state: "stranded", stranded_at: isoNow() })
    );
    await batch.commit();
    logger.info(`[sweepStrandedPhotos] marked ${snap.size} photo(s) stranded`);
  }
);
