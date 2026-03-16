/**
 * Search API endpoint for Pacelli Cloud Functions.
 *
 * Client-side decryption + substring matching across all entity types.
 * This mirrors the FirebaseDataRepository.searchHousehold() logic.
 */
import * as admin from "firebase-admin";
import { AuthContext } from "../middleware/auth";
import { createFieldCrypto } from "../middleware/encryption";
import { SearchResult, SearchRequest } from "../types/models";

const db = () => admin.firestore();

function parseTimestamp(val: unknown): string | null {
  if (!val) return null;
  if (val instanceof admin.firestore.Timestamp) {
    return val.toDate().toISOString();
  }
  if (typeof val === "string") return val;
  return null;
}

export async function searchHousehold(
  ctx: AuthContext,
  req: SearchRequest
): Promise<SearchResult[]> {
  const { dec, decN } = createFieldCrypto(ctx.householdKey);
  const query = req.query.toLowerCase();
  const types = req.entityTypes ?? [
    "task",
    "checklist",
    "plan",
    "attachment",
    "inventory",
  ];
  const results: SearchResult[] = [];

  // Search in parallel across entity types
  const searches: Promise<void>[] = [];

  if (types.includes("task")) {
    searches.push(
      (async () => {
        const snap = await db()
          .collection("tasks")
          .where("household_id", "==", ctx.householdId)
          .get();

        for (const doc of snap.docs) {
          const d = doc.data();
          const title = dec(d.title ?? "");
          const desc = decN(d.description);

          if (
            title.toLowerCase().includes(query) ||
            (desc && desc.toLowerCase().includes(query))
          ) {
            results.push({
              id: doc.id,
              entityType: "task",
              householdId: ctx.householdId,
              title,
              subtitle: desc
                ? desc.length > 80
                  ? desc.substring(0, 80) + "..."
                  : desc
                : null,
              parentId: null,
              metadata: {
                status: d.status,
                priority: d.priority,
              },
              relevanceDate: parseTimestamp(d.created_at),
            });
          }
        }
      })()
    );
  }

  if (types.includes("checklist")) {
    searches.push(
      (async () => {
        const snap = await db()
          .collection("checklists")
          .where("household_id", "==", ctx.householdId)
          .get();

        for (const doc of snap.docs) {
          const d = doc.data();
          const title = dec(d.title ?? "");

          if (title.toLowerCase().includes(query)) {
            results.push({
              id: doc.id,
              entityType: "checklist",
              householdId: ctx.householdId,
              title,
              subtitle: null,
              parentId: null,
              metadata: {},
              relevanceDate: parseTimestamp(d.created_at),
            });
          }
        }

        // Also search checklist items
        const itemSnap = await db()
          .collection("checklist_items")
          .where("household_id", "==", ctx.householdId)
          .get();

        for (const doc of itemSnap.docs) {
          const d = doc.data();
          const title = dec(d.title ?? "");

          if (title.toLowerCase().includes(query)) {
            results.push({
              id: doc.id,
              entityType: "checklist",
              householdId: ctx.householdId,
              title,
              subtitle: "Checklist item",
              parentId: d.checklist_id,
              metadata: { isChecked: d.is_checked },
              relevanceDate: parseTimestamp(d.created_at),
            });
          }
        }
      })()
    );
  }

  if (types.includes("plan")) {
    searches.push(
      (async () => {
        const snap = await db()
          .collection("plans")
          .where("household_id", "==", ctx.householdId)
          .where("is_template", "==", false)
          .get();

        for (const doc of snap.docs) {
          const d = doc.data();
          const title = dec(d.title ?? "");

          if (title.toLowerCase().includes(query)) {
            results.push({
              id: doc.id,
              entityType: "plan",
              householdId: ctx.householdId,
              title,
              subtitle: `${d.type} plan — ${d.status}`,
              parentId: null,
              metadata: { status: d.status, type: d.type },
              relevanceDate: parseTimestamp(d.created_at),
            });
          }
        }

        // Also search entries
        const entrySnap = await db()
          .collection("plan_entries")
          .where("household_id", "==", ctx.householdId)
          .get();

        for (const doc of entrySnap.docs) {
          const d = doc.data();
          const title = dec(d.title ?? "");
          const desc = decN(d.description);

          if (
            title.toLowerCase().includes(query) ||
            (desc && desc.toLowerCase().includes(query))
          ) {
            results.push({
              id: doc.id,
              entityType: "plan",
              householdId: ctx.householdId,
              title,
              subtitle: "Plan entry",
              parentId: d.plan_id,
              metadata: { entryDate: d.entry_date },
              relevanceDate: parseTimestamp(d.created_at),
            });
          }
        }
      })()
    );
  }

  if (types.includes("inventory")) {
    searches.push(
      (async () => {
        const snap = await db()
          .collection("inventory_items")
          .where("household_id", "==", ctx.householdId)
          .get();

        for (const doc of snap.docs) {
          const d = doc.data();
          const name = dec(d.name ?? "");
          const desc = decN(d.description);
          const notes = decN(d.notes);

          if (
            name.toLowerCase().includes(query) ||
            (desc && desc.toLowerCase().includes(query)) ||
            (notes && notes.toLowerCase().includes(query))
          ) {
            results.push({
              id: doc.id,
              entityType: "inventory",
              householdId: ctx.householdId,
              title: name,
              subtitle: desc
                ? desc.length > 80
                  ? desc.substring(0, 80) + "..."
                  : desc
                : null,
              parentId: null,
              metadata: {
                quantity: d.quantity,
                unit: d.unit,
              },
              relevanceDate: parseTimestamp(d.created_at),
            });
          }
        }
      })()
    );
  }

  if (types.includes("attachment")) {
    searches.push(
      (async () => {
        // Task attachments
        const taskAttSnap = await db()
          .collection("task_attachments")
          .where("household_id", "==", ctx.householdId)
          .get();

        for (const doc of taskAttSnap.docs) {
          const d = doc.data();
          const fileName = dec(d.file_name ?? "");
          const desc = decN(d.description);

          if (
            fileName.toLowerCase().includes(query) ||
            (desc && desc.toLowerCase().includes(query))
          ) {
            results.push({
              id: doc.id,
              entityType: "attachment",
              householdId: ctx.householdId,
              title: fileName,
              subtitle: "Task attachment",
              parentId: d.task_id,
              metadata: { mimeType: d.mime_type },
              relevanceDate: parseTimestamp(d.uploaded_at),
            });
          }
        }

        // Plan attachments
        const planAttSnap = await db()
          .collection("plan_attachments")
          .where("household_id", "==", ctx.householdId)
          .get();

        for (const doc of planAttSnap.docs) {
          const d = doc.data();
          const fileName = dec(d.file_name ?? "");
          const desc = decN(d.description);

          if (
            fileName.toLowerCase().includes(query) ||
            (desc && desc.toLowerCase().includes(query))
          ) {
            results.push({
              id: doc.id,
              entityType: "attachment",
              householdId: ctx.householdId,
              title: fileName,
              subtitle: "Plan attachment",
              parentId: d.plan_id,
              metadata: { mimeType: d.mime_type },
              relevanceDate: parseTimestamp(d.uploaded_at),
            });
          }
        }

        // Inventory attachments
        const invAttSnap = await db()
          .collection("inventory_attachments")
          .where("household_id", "==", ctx.householdId)
          .get();

        for (const doc of invAttSnap.docs) {
          const d = doc.data();
          const fileName = dec(d.file_name ?? "");
          const desc = decN(d.description);

          if (
            fileName.toLowerCase().includes(query) ||
            (desc && desc.toLowerCase().includes(query))
          ) {
            results.push({
              id: doc.id,
              entityType: "attachment",
              householdId: ctx.householdId,
              title: fileName,
              subtitle: "Inventory attachment",
              parentId: d.item_id,
              metadata: { mimeType: d.mime_type },
              relevanceDate: parseTimestamp(d.uploaded_at),
            });
          }
        }
      })()
    );
  }

  await Promise.all(searches);

  // Sort by relevance date (newest first)
  results.sort((a, b) => {
    if (!a.relevanceDate && !b.relevanceDate) return 0;
    if (!a.relevanceDate) return 1;
    if (!b.relevanceDate) return -1;
    return b.relevanceDate.localeCompare(a.relevanceDate);
  });

  return results;
}
