/**
 * Task Category API endpoints for Pacelli Cloud Functions.
 *
 * Encrypted fields: name.
 */
import * as admin from "firebase-admin";
import { AuthContext } from "../middleware/auth";
import { createFieldCrypto } from "../middleware/encryption";
import { TaskCategory, CreateCategoryRequest } from "../types/models";

const db = () => admin.firestore();

export async function getCategories(ctx: AuthContext): Promise<TaskCategory[]> {
  const { dec } = createFieldCrypto(ctx.householdKey);

  const snapshot = await db()
    .collection("task_categories")
    .where("household_id", "==", ctx.householdId)
    .get();

  return snapshot.docs.map((doc) => {
    const d = doc.data();
    return {
      id: doc.id,
      householdId: d.household_id ?? null,
      name: dec(d.name ?? ""),
      icon: d.icon ?? "category",
      color: d.color ?? "#7EA87E",
      isDefault: d.is_default ?? false,
    };
  });
}

export async function createCategory(
  ctx: AuthContext,
  req: CreateCategoryRequest
): Promise<TaskCategory> {
  const { enc } = createFieldCrypto(ctx.householdKey);

  const ref = db().collection("task_categories").doc();
  await ref.set({
    household_id: ctx.householdId,
    name: enc(req.name),
    icon: req.icon ?? "category",
    color: req.color ?? "#7EA87E",
    is_default: false,
  });

  return {
    id: ref.id,
    householdId: ctx.householdId,
    name: req.name,
    icon: req.icon ?? "category",
    color: req.color ?? "#7EA87E",
    isDefault: false,
  };
}

export async function deleteCategory(
  ctx: AuthContext,
  categoryId: string
): Promise<boolean> {
  const ref = db().collection("task_categories").doc(categoryId);
  const doc = await ref.get();
  if (!doc.exists || doc.data()!.household_id !== ctx.householdId) return false;
  if (doc.data()!.is_default) return false;

  await ref.delete();
  return true;
}
