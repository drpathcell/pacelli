/**
 * Product pictures for checklist items built from a retailer catalogue.
 *
 * When an assistant adds a Dunnes product to a checklist it may pass the
 * product's image URL. Rather than have every phone fetch that picture from
 * Dunnes' CDN (which tells Dunnes what is on the list, and costs a network
 * round trip per row), this module copies it ONCE into our own bucket and then
 * attaches it to the item exactly the way the app attaches a photo it took:
 * a `photos` document with an encrypted thumbnail, plus an encrypted full-size
 * object at `objectPath(household, photo)`. The app already renders that
 * document on the row; nothing in the app changes.
 *
 * Two copies live in the bucket:
 *   catalog/dunnes/{sku}/{index}/{cell|detail}.jpg  plaintext cache, shared by every
 *                                            household (public retailer imagery)
 *   households/{hid}/photos/{photoId}.enc    per-household, encrypted, deleted
 *                                            with the document like any photo
 *
 * Only `images.cdn.dunnesstoresgrocery.com` is ever fetched, and only over
 * https, so this cannot be turned into a fetch-anything proxy.
 */
import * as crypto from "crypto";
import * as admin from "firebase-admin";
import { logger } from "firebase-functions";

import { AuthContext } from "../middleware/auth";
import { createFieldCrypto } from "../middleware/encryption";
import { encryptBytes } from "../crypto/encryption-service";
import { PHOTO_BUCKET, objectPath } from "./photos";

export const ALLOWED_IMAGE_HOST = "images.cdn.dunnesstoresgrocery.com";
const CATALOG_PREFIX = "catalog/dunnes";
const FETCH_TIMEOUT_MS = 10_000;
const MAX_IMAGE_BYTES = 2 * 1024 * 1024;

const bucket = () => admin.storage().bucket(PHOTO_BUCKET);

/** `https://images.cdn.dunnesstoresgrocery.com/{variant}/{sku}_{n|default}.jpg` and nothing else. */
export function parseCatalogImageUrl(url: unknown): { sku: string; index: string } | null {
  if (typeof url !== "string") return null;
  let u: URL;
  try {
    u = new URL(url);
  } catch {
    return null;
  }
  if (u.protocol !== "https:" || u.host !== ALLOWED_IMAGE_HOST) return null;
  // sku: 9-digit Dunnes codes and 13-digit EANs (non-food lines). index: a
  // number up to 4 digits, or the literal "default" the EAN lines use.
  const m = /^\/(cell|detail|zoom)\/(\d{6,14})_(\d{1,4}|default)\.jpg$/.exec(u.pathname);
  return m ? { sku: m[2], index: m[3] } : null;
}

/** Width and height from JPEG SOF markers, or null. Enough for the document; no decoder needed. */
export function jpegDimensions(buf: Buffer): { width: number; height: number } | null {
  if (buf.length < 4 || buf[0] !== 0xff || buf[1] !== 0xd8) return null;
  let i = 2;
  while (i + 9 < buf.length) {
    if (buf[i] !== 0xff) {
      i++;
      continue;
    }
    const marker = buf[i + 1];
    if (marker === 0xd8 || (marker >= 0xd0 && marker <= 0xd7) || marker === 0x01 || marker === 0xff) {
      i += 2;
      continue;
    }
    const len = buf.readUInt16BE(i + 2);
    const isSOF = marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc;
    if (isSOF) {
      return { height: buf.readUInt16BE(i + 5), width: buf.readUInt16BE(i + 7) };
    }
    if (marker === 0xda) return null; // start of scan without a frame header
    i += 2 + len;
  }
  return null;
}

async function fetchFromCdn(variant: "cell" | "detail", sku: string, index: string): Promise<Buffer> {
  const url = `https://${ALLOWED_IMAGE_HOST}/${variant}/${sku}_${index}.jpg`;
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), FETCH_TIMEOUT_MS);
  try {
    const res = await fetch(url, { signal: ctl.signal, redirect: "error" });
    if (!res.ok) throw new Error(`CDN ${res.status} for ${variant}/${sku}`);
    const ct = res.headers.get("content-type") || "";
    if (!ct.startsWith("image/jpeg")) throw new Error(`CDN returned ${ct} for ${variant}/${sku}`);
    const buf = Buffer.from(await res.arrayBuffer());
    if (buf.length === 0 || buf.length > MAX_IMAGE_BYTES) throw new Error(`CDN image size ${buf.length} out of range`);
    if (!jpegDimensions(buf)) throw new Error("CDN bytes are not a JPEG with a frame header");
    return buf;
  } finally {
    clearTimeout(timer);
  }
}

/** The plaintext cache copy, fetching from the CDN only on a miss. */
export async function cachedCatalogImage(variant: "cell" | "detail", sku: string, index: string): Promise<Buffer> {
  // Keyed on the index too: `{sku}_1` and `{sku}_2` are different pictures
  // of the same product, and the first one asked for used to be served for both.
  const file = bucket().file(`${CATALOG_PREFIX}/${sku}/${index}/${variant}.jpg`);
  const [exists] = await file.exists();
  if (exists) {
    const [buf] = await file.download();
    if (buf.length > 0 && jpegDimensions(buf)) return buf;
  }
  const buf = await fetchFromCdn(variant, sku, index);
  await file.save(buf, { contentType: "image/jpeg", resumable: false, metadata: { cacheControl: "private, max-age=0" } });
  return buf;
}

export interface AttachCatalogPhotoRequest {
  itemId: string;
  imageUrl: string;
  /** Product name; becomes the encrypted caption so the photo is searchable. */
  name?: string;
}

/**
 * Creates the `photos` document + encrypted object for a checklist item.
 * Returns the photo id. Throws on any failure; the caller decides whether the
 * item add is still a success (it is: the row without a picture beats no row).
 */
export async function attachCatalogPhoto(ctx: AuthContext, req: AttachCatalogPhotoRequest): Promise<string> {
  const parsed = parseCatalogImageUrl(req.imageUrl);
  if (!parsed) throw new Error("imageUrl is not a Dunnes catalogue image");
  const [thumb, full] = await Promise.all([
    cachedCatalogImage("cell", parsed.sku, parsed.index),
    cachedCatalogImage("detail", parsed.sku, parsed.index),
  ]);
  const dims = jpegDimensions(full);
  const { encN } = createFieldCrypto(ctx.householdKey);

  const db = admin.firestore();
  const ref = db.collection("photos").doc();
  const now = new Date().toISOString();

  // Object first, document second: a document whose object is missing would
  // show "ready" for a picture that cannot be opened.
  await bucket()
    .file(objectPath(ctx.householdId, ref.id))
    .save(encryptBytes(full, ctx.householdKey), { contentType: "application/octet-stream", resumable: false });

  await ref.set({
    id: ref.id,
    household_id: ctx.householdId,
    subject_type: "checklist_item",
    subject_id: req.itemId,
    upload_state: "ready",
    thumb: encryptBytes(thumb, ctx.householdKey).toString("base64"),
    caption: encN(req.name ?? null),
    content_hash: crypto.createHash("sha256").update(full).digest("hex"),
    width: dims?.width ?? null,
    height: dims?.height ?? null,
    byte_size: full.length,
    created_by: ctx.uid,
    created_at: now,
    source: "catalog:dunnes",
  });
  // No sku in the log line: Cloud Logging is readable by anyone with project
  // access, and the sku is the product, which is the list.
  logger.info("[attachCatalogPhoto] attached", { itemId: req.itemId, photoId: ref.id });
  return ref.id;
}
