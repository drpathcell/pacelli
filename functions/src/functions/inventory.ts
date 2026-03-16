/**
 * Inventory API endpoints for Pacelli Cloud Functions.
 *
 * Maps to DataRepository inventory methods in firebase_data_repository.dart.
 * Encrypted fields: name, description, notes (items); name (categories/locations);
 * fileName, description (attachments); note (logs).
 */
import * as admin from "firebase-admin";
import { AuthContext } from "../middleware/auth";
import { createFieldCrypto } from "../middleware/encryption";
import {
  InventoryItem,
  InventoryCategory,
  InventoryLocation,
  InventoryLog,
  InventoryAttachment,
  InventoryStats,
  CreateInventoryItemRequest,
  UpdateInventoryItemRequest,
  ListInventoryRequest,
  LogInventoryActionRequest,
  GetInventoryLogsRequest,
  CreateInventoryCategoryRequest,
  CreateInventoryLocationRequest,
  CreateInventoryAttachmentRequest,
} from "../types/models";

const db = () => admin.firestore();

// ── Helpers ──

function parseTimestamp(val: unknown): string | null {
  if (!val) return null;
  if (val instanceof admin.firestore.Timestamp) {
    return val.toDate().toISOString();
  }
  if (typeof val === "string") return val;
  return null;
}

// ═══════════════════════════════════════════════════════════════════
//  INVENTORY ITEMS
// ═══════════════════════════════════════════════════════════════════

export async function listInventoryItems(
  ctx: AuthContext,
  filters: ListInventoryRequest
): Promise<InventoryItem[]> {
  const { dec, decN } = createFieldCrypto(ctx.householdKey);

  let query: admin.firestore.Query = db()
    .collection("inventory_items")
    .where("household_id", "==", ctx.householdId);

  if (filters.categoryId) {
    query = query.where("category_id", "==", filters.categoryId);
  }
  if (filters.locationId) {
    query = query.where("location_id", "==", filters.locationId);
  }

  const snapshot = await query.get();

  const items = await Promise.all(
    snapshot.docs.map(async (doc) => {
      const d = doc.data();
      const item = await buildInventoryItem(ctx, doc.id, d, dec, decN);

      // Client-side filtering for computed properties
      if (filters.lowStockOnly) {
        const threshold = d.low_stock_threshold;
        if (!threshold || (d.quantity ?? 0) >= threshold) return null;
      }
      if (filters.expiringOnly) {
        const expiry = parseTimestamp(d.expiry_date);
        if (!expiry) return null;
        const daysUntilExpiry = Math.ceil(
          (new Date(expiry).getTime() - Date.now()) / (1000 * 60 * 60 * 24)
        );
        if (daysUntilExpiry > 7 || daysUntilExpiry < 0) return null;
      }

      return item;
    })
  );

  return items.filter((i): i is InventoryItem => i !== null);
}

export async function getInventoryItem(
  ctx: AuthContext,
  itemId: string
): Promise<InventoryItem | null> {
  const { dec, decN } = createFieldCrypto(ctx.householdKey);

  const doc = await db().collection("inventory_items").doc(itemId).get();
  if (!doc.exists) return null;

  const d = doc.data()!;
  if (d.household_id !== ctx.householdId) return null;

  return buildInventoryItem(ctx, doc.id, d, dec, decN);
}

async function buildInventoryItem(
  ctx: AuthContext,
  id: string,
  d: admin.firestore.DocumentData,
  dec: (s: string) => string,
  decN: (s: string | null | undefined) => string | null
): Promise<InventoryItem> {
  // Load category
  let category: InventoryCategory | null = null;
  if (d.category_id) {
    try {
      const catDoc = await db()
        .collection("inventory_categories")
        .doc(d.category_id)
        .get();
      if (catDoc.exists) {
        const cd = catDoc.data()!;
        category = {
          id: catDoc.id,
          householdId: cd.household_id,
          name: dec(cd.name ?? ""),
          icon: cd.icon ?? "inventory_2",
          color: cd.color ?? "#A5B4A5",
          isDefault: cd.is_default ?? false,
          sortOrder: cd.sort_order ?? 0,
          createdAt: parseTimestamp(cd.created_at),
        };
      }
    } catch {
      // Continue without category
    }
  }

  // Load location
  let location: InventoryLocation | null = null;
  if (d.location_id) {
    try {
      const locDoc = await db()
        .collection("inventory_locations")
        .doc(d.location_id)
        .get();
      if (locDoc.exists) {
        const ld = locDoc.data()!;
        location = {
          id: locDoc.id,
          householdId: ld.household_id,
          name: dec(ld.name ?? ""),
          icon: ld.icon ?? "place",
          isDefault: ld.is_default ?? false,
          sortOrder: ld.sort_order ?? 0,
          createdAt: parseTimestamp(ld.created_at),
        };
      }
    } catch {
      // Continue without location
    }
  }

  // Load attachments
  const attachSnap = await db()
    .collection("inventory_attachments")
    .where("item_id", "==", id)
    .where("household_id", "==", ctx.householdId)
    .get();

  const attachments: InventoryAttachment[] = attachSnap.docs.map((a) => {
    const ad = a.data();
    return {
      id: a.id,
      itemId: ad.item_id,
      householdId: ad.household_id,
      driveFileId: ad.drive_file_id,
      fileName: dec(ad.file_name ?? ""),
      mimeType: ad.mime_type,
      fileSizeBytes: ad.file_size_bytes ?? 0,
      thumbnailUrl: ad.thumbnail_url ?? null,
      webViewLink: ad.web_view_link,
      description: decN(ad.description),
      uploadedBy: ad.uploaded_by,
      uploadedAt: parseTimestamp(ad.uploaded_at) ?? new Date().toISOString(),
    };
  });

  return {
    id,
    householdId: d.household_id,
    name: dec(d.name ?? ""),
    description: decN(d.description),
    categoryId: d.category_id ?? null,
    locationId: d.location_id ?? null,
    quantity: d.quantity ?? 0,
    unit: d.unit ?? "pieces",
    lowStockThreshold: d.low_stock_threshold ?? null,
    barcode: d.barcode ?? null,
    barcodeType: d.barcode_type ?? "none",
    expiryDate: parseTimestamp(d.expiry_date),
    purchaseDate: parseTimestamp(d.purchase_date),
    notes: decN(d.notes),
    createdBy: d.created_by,
    createdAt: parseTimestamp(d.created_at) ?? new Date().toISOString(),
    updatedAt: parseTimestamp(d.updated_at),
    category,
    location,
    attachments,
  };
}

export async function createInventoryItem(
  ctx: AuthContext,
  req: CreateInventoryItemRequest
): Promise<InventoryItem> {
  const { enc, encN } = createFieldCrypto(ctx.householdKey);
  const now = new Date().toISOString();

  const ref = db().collection("inventory_items").doc();
  const data: Record<string, unknown> = {
    household_id: ctx.householdId,
    name: enc(req.name),
    description: encN(req.description ?? null),
    category_id: req.categoryId ?? null,
    location_id: req.locationId ?? null,
    quantity: req.quantity ?? 0,
    unit: req.unit ?? "pieces",
    low_stock_threshold: req.lowStockThreshold ?? null,
    barcode: req.barcode ?? null,
    barcode_type: req.barcodeType ?? "none",
    expiry_date: req.expiryDate ?? null,
    purchase_date: req.purchaseDate ?? null,
    notes: encN(req.notes ?? null),
    created_by: ctx.uid,
    created_at: now,
    updated_at: now,
  };

  await ref.set(data);
  return (await getInventoryItem(ctx, ref.id))!;
}

export async function updateInventoryItem(
  ctx: AuthContext,
  req: UpdateInventoryItemRequest
): Promise<InventoryItem | null> {
  const { enc, encN } = createFieldCrypto(ctx.householdKey);

  const docRef = db().collection("inventory_items").doc(req.itemId);
  const doc = await docRef.get();
  if (!doc.exists || doc.data()!.household_id !== ctx.householdId) return null;

  const updates: Record<string, unknown> = {
    updated_at: new Date().toISOString(),
  };
  if (req.name !== undefined) updates.name = enc(req.name);
  if (req.description !== undefined) updates.description = encN(req.description ?? null);
  if (req.categoryId !== undefined) updates.category_id = req.categoryId;
  if (req.locationId !== undefined) updates.location_id = req.locationId;
  if (req.quantity !== undefined) updates.quantity = req.quantity;
  if (req.unit !== undefined) updates.unit = req.unit;
  if (req.lowStockThreshold !== undefined) updates.low_stock_threshold = req.lowStockThreshold;
  if (req.barcode !== undefined) updates.barcode = req.barcode;
  if (req.barcodeType !== undefined) updates.barcode_type = req.barcodeType;
  if (req.expiryDate !== undefined) updates.expiry_date = req.expiryDate;
  if (req.purchaseDate !== undefined) updates.purchase_date = req.purchaseDate;
  if (req.notes !== undefined) updates.notes = encN(req.notes ?? null);

  await docRef.update(updates);
  return getInventoryItem(ctx, req.itemId);
}

export async function deleteInventoryItem(
  ctx: AuthContext,
  itemId: string
): Promise<boolean> {
  const docRef = db().collection("inventory_items").doc(itemId);
  const doc = await docRef.get();
  if (!doc.exists || doc.data()!.household_id !== ctx.householdId) return false;

  // Delete related records
  const batch = db().batch();

  const [attachSnap, logSnap] = await Promise.all([
    db()
      .collection("inventory_attachments")
      .where("item_id", "==", itemId)
      .where("household_id", "==", ctx.householdId)
      .get(),
    db()
      .collection("inventory_logs")
      .where("item_id", "==", itemId)
      .where("household_id", "==", ctx.householdId)
      .get(),
  ]);

  attachSnap.docs.forEach((d) => batch.delete(d.ref));
  logSnap.docs.forEach((d) => batch.delete(d.ref));
  batch.delete(docRef);
  await batch.commit();

  return true;
}

// ═══════════════════════════════════════════════════════════════════
//  INVENTORY CATEGORIES
// ═══════════════════════════════════════════════════════════════════

export async function getInventoryCategories(
  ctx: AuthContext
): Promise<InventoryCategory[]> {
  const { dec } = createFieldCrypto(ctx.householdKey);

  const snapshot = await db()
    .collection("inventory_categories")
    .where("household_id", "==", ctx.householdId)
    .orderBy("sort_order")
    .get();

  return snapshot.docs.map((doc) => {
    const d = doc.data();
    return {
      id: doc.id,
      householdId: d.household_id,
      name: dec(d.name ?? ""),
      icon: d.icon ?? "inventory_2",
      color: d.color ?? "#A5B4A5",
      isDefault: d.is_default ?? false,
      sortOrder: d.sort_order ?? 0,
      createdAt: parseTimestamp(d.created_at),
    };
  });
}

export async function createInventoryCategory(
  ctx: AuthContext,
  req: CreateInventoryCategoryRequest
): Promise<InventoryCategory> {
  const { enc } = createFieldCrypto(ctx.householdKey);

  const ref = db().collection("inventory_categories").doc();
  const now = new Date().toISOString();

  await ref.set({
    household_id: ctx.householdId,
    name: enc(req.name),
    icon: req.icon ?? "inventory_2",
    color: req.color ?? "#A5B4A5",
    is_default: false,
    sort_order: 0,
    created_at: now,
  });

  return {
    id: ref.id,
    householdId: ctx.householdId,
    name: req.name,
    icon: req.icon ?? "inventory_2",
    color: req.color ?? "#A5B4A5",
    isDefault: false,
    sortOrder: 0,
    createdAt: now,
  };
}

export async function deleteInventoryCategory(
  ctx: AuthContext,
  categoryId: string
): Promise<boolean> {
  const ref = db().collection("inventory_categories").doc(categoryId);
  const doc = await ref.get();
  if (!doc.exists || doc.data()!.household_id !== ctx.householdId) return false;
  if (doc.data()!.is_default) return false; // Can't delete defaults

  await ref.delete();
  return true;
}

// ═══════════════════════════════════════════════════════════════════
//  INVENTORY LOCATIONS
// ═══════════════════════════════════════════════════════════════════

export async function getInventoryLocations(
  ctx: AuthContext
): Promise<InventoryLocation[]> {
  const { dec } = createFieldCrypto(ctx.householdKey);

  const snapshot = await db()
    .collection("inventory_locations")
    .where("household_id", "==", ctx.householdId)
    .orderBy("sort_order")
    .get();

  return snapshot.docs.map((doc) => {
    const d = doc.data();
    return {
      id: doc.id,
      householdId: d.household_id,
      name: dec(d.name ?? ""),
      icon: d.icon ?? "place",
      isDefault: d.is_default ?? false,
      sortOrder: d.sort_order ?? 0,
      createdAt: parseTimestamp(d.created_at),
    };
  });
}

export async function createInventoryLocation(
  ctx: AuthContext,
  req: CreateInventoryLocationRequest
): Promise<InventoryLocation> {
  const { enc } = createFieldCrypto(ctx.householdKey);

  const ref = db().collection("inventory_locations").doc();
  const now = new Date().toISOString();

  await ref.set({
    household_id: ctx.householdId,
    name: enc(req.name),
    icon: req.icon ?? "place",
    is_default: false,
    sort_order: 0,
    created_at: now,
  });

  return {
    id: ref.id,
    householdId: ctx.householdId,
    name: req.name,
    icon: req.icon ?? "place",
    isDefault: false,
    sortOrder: 0,
    createdAt: now,
  };
}

export async function deleteInventoryLocation(
  ctx: AuthContext,
  locationId: string
): Promise<boolean> {
  const ref = db().collection("inventory_locations").doc(locationId);
  const doc = await ref.get();
  if (!doc.exists || doc.data()!.household_id !== ctx.householdId) return false;
  if (doc.data()!.is_default) return false;

  await ref.delete();
  return true;
}

// ═══════════════════════════════════════════════════════════════════
//  INVENTORY LOGS
// ═══════════════════════════════════════════════════════════════════

export async function logInventoryAction(
  ctx: AuthContext,
  req: LogInventoryActionRequest
): Promise<void> {
  const { encN } = createFieldCrypto(ctx.householdKey);

  // Verify item belongs to household
  const itemDoc = await db().collection("inventory_items").doc(req.itemId).get();
  if (!itemDoc.exists || itemDoc.data()!.household_id !== ctx.householdId) {
    throw new Error("Item not found or access denied");
  }

  const ref = db().collection("inventory_logs").doc();
  await ref.set({
    item_id: req.itemId,
    household_id: ctx.householdId,
    action: req.action,
    quantity_change: req.quantityChange,
    quantity_after: req.quantityAfter,
    note: encN(req.note ?? null),
    performed_by: ctx.uid,
    performed_at: new Date().toISOString(),
  });
}

export async function getInventoryLogs(
  ctx: AuthContext,
  req: GetInventoryLogsRequest
): Promise<InventoryLog[]> {
  const { decN } = createFieldCrypto(ctx.householdKey);

  const snapshot = await db()
    .collection("inventory_logs")
    .where("item_id", "==", req.itemId)
    .where("household_id", "==", ctx.householdId)
    .orderBy("performed_at", "desc")
    .limit(req.limit ?? 50)
    .get();

  return snapshot.docs.map((doc) => {
    const d = doc.data();
    return {
      id: doc.id,
      itemId: d.item_id,
      householdId: d.household_id,
      action: d.action,
      quantityChange: d.quantity_change,
      quantityAfter: d.quantity_after,
      note: decN(d.note),
      performedBy: d.performed_by,
      performedAt: parseTimestamp(d.performed_at) ?? new Date().toISOString(),
    };
  });
}

// ═══════════════════════════════════════════════════════════════════
//  INVENTORY ATTACHMENTS
// ═══════════════════════════════════════════════════════════════════

export async function createInventoryAttachment(
  ctx: AuthContext,
  req: CreateInventoryAttachmentRequest
): Promise<InventoryAttachment> {
  const { enc, encN } = createFieldCrypto(ctx.householdKey);

  // Verify item belongs to household
  const itemDoc = await db().collection("inventory_items").doc(req.itemId).get();
  if (!itemDoc.exists || itemDoc.data()!.household_id !== ctx.householdId) {
    throw new Error("Item not found or access denied");
  }

  const ref = db().collection("inventory_attachments").doc();
  const now = new Date().toISOString();

  await ref.set({
    item_id: req.itemId,
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
    itemId: req.itemId,
    householdId: ctx.householdId,
    driveFileId: req.driveFileId,
    fileName: req.fileName,
    mimeType: req.mimeType,
    fileSizeBytes: req.fileSizeBytes,
    thumbnailUrl: req.thumbnailUrl ?? null,
    webViewLink: req.webViewLink,
    description: req.description ?? null,
    uploadedBy: ctx.uid,
    uploadedAt: now,
  };
}

export async function getInventoryAttachments(
  ctx: AuthContext,
  itemId: string
): Promise<InventoryAttachment[]> {
  const { dec, decN } = createFieldCrypto(ctx.householdKey);

  const snapshot = await db()
    .collection("inventory_attachments")
    .where("item_id", "==", itemId)
    .where("household_id", "==", ctx.householdId)
    .get();

  return snapshot.docs.map((doc) => {
    const d = doc.data();
    return {
      id: doc.id,
      itemId: d.item_id,
      householdId: d.household_id,
      driveFileId: d.drive_file_id,
      fileName: dec(d.file_name ?? ""),
      mimeType: d.mime_type,
      fileSizeBytes: d.file_size_bytes ?? 0,
      thumbnailUrl: d.thumbnail_url ?? null,
      webViewLink: d.web_view_link,
      description: decN(d.description),
      uploadedBy: d.uploaded_by,
      uploadedAt: parseTimestamp(d.uploaded_at) ?? new Date().toISOString(),
    };
  });
}

export async function deleteInventoryAttachment(
  ctx: AuthContext,
  attachmentId: string
): Promise<boolean> {
  const ref = db().collection("inventory_attachments").doc(attachmentId);
  const doc = await ref.get();
  if (!doc.exists || doc.data()!.household_id !== ctx.householdId) return false;

  await ref.delete();
  return true;
}

// ═══════════════════════════════════════════════════════════════════
//  INVENTORY STATS
// ═══════════════════════════════════════════════════════════════════

export async function getInventoryStats(
  ctx: AuthContext
): Promise<InventoryStats> {
  const snapshot = await db()
    .collection("inventory_items")
    .where("household_id", "==", ctx.householdId)
    .get();

  let totalItems = 0;
  let lowStock = 0;
  let expiringSoon = 0;
  let expired = 0;
  const now = new Date();
  const sevenDaysFromNow = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

  for (const doc of snapshot.docs) {
    totalItems++;
    const d = doc.data();

    // Low stock check
    const threshold = d.low_stock_threshold;
    if (threshold && (d.quantity ?? 0) < threshold) {
      lowStock++;
    }

    // Expiry check
    const expiry = parseTimestamp(d.expiry_date);
    if (expiry) {
      const expiryDate = new Date(expiry);
      if (expiryDate < now) {
        expired++;
      } else if (expiryDate <= sevenDaysFromNow) {
        expiringSoon++;
      }
    }
  }

  return { totalItems, lowStock, expiringSoon, expired };
}
