/**
 * Task API endpoints for Pacelli Cloud Functions.
 *
 * Maps to DataRepository task methods in firebase_data_repository.dart.
 * All fields are decrypted on read and encrypted on write.
 */
import * as admin from "firebase-admin";
import { AuthContext } from "../middleware/auth";
import { createFieldCrypto } from "../middleware/encryption";
import {
  Task,
  Subtask,
  TaskCategory,
  TaskStats,
  CreateTaskRequest,
  UpdateTaskRequest,
  ListTasksRequest,
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

// ── List Tasks ──

export async function listTasks(
  ctx: AuthContext,
  filters: ListTasksRequest
): Promise<Task[]> {
  const { dec, decN } = createFieldCrypto(ctx.householdKey);

  let query: admin.firestore.Query = db()
    .collection("tasks")
    .where("household_id", "==", ctx.householdId);

  if (filters.status) {
    query = query.where("status", "==", filters.status);
  }
  if (filters.categoryId) {
    query = query.where("category_id", "==", filters.categoryId);
  }
  if (filters.priority) {
    query = query.where("priority", "==", filters.priority);
  }
  if (filters.assignedTo) {
    query = query.where("assigned_to", "==", filters.assignedTo);
  }

  const snapshot = await query.get();

  // Batch-load subtasks for all tasks in parallel
  const tasks = await Promise.all(
    snapshot.docs.map(async (doc) => {
      const d = doc.data();

      // Load subtasks
      const subtaskSnap = await db()
        .collection("subtasks")
        .where("household_id", "==", ctx.householdId)
        .where("task_id", "==", doc.id)
        .orderBy("sort_order")
        .get();

      const subtasks: Subtask[] = subtaskSnap.docs.map((s) => {
        const sd = s.data();
        return {
          id: s.id,
          taskId: sd.task_id,
          householdId: sd.household_id,
          title: dec(sd.title ?? ""),
          isCompleted: sd.is_completed ?? false,
          sortOrder: sd.sort_order ?? 0,
        };
      });

      // Load category if present
      let category: TaskCategory | null = null;
      if (d.category_id) {
        try {
          const catDoc = await db()
            .collection("task_categories")
            .doc(d.category_id)
            .get();
          if (catDoc.exists) {
            const cd = catDoc.data()!;
            category = {
              id: catDoc.id,
              householdId: cd.household_id ?? null,
              name: dec(cd.name ?? ""),
              icon: cd.icon ?? "category",
              color: cd.color ?? "#7EA87E",
              isDefault: cd.is_default ?? false,
            };
          }
        } catch {
          // Category lookup failed — continue without it
        }
      }

      return {
        id: doc.id,
        householdId: d.household_id,
        title: dec(d.title ?? ""),
        description: decN(d.description),
        categoryId: d.category_id ?? null,
        priority: d.priority ?? "medium",
        status: d.status ?? "pending",
        dueDate: parseTimestamp(d.due_date),
        startDate: parseTimestamp(d.start_date),
        assignedTo: d.assigned_to ?? null,
        isShared: d.is_shared ?? false,
        recurrence: d.recurrence ?? "none",
        createdBy: d.created_by,
        createdAt: parseTimestamp(d.created_at) ?? new Date().toISOString(),
        completedAt: parseTimestamp(d.completed_at),
        completedBy: d.completed_by ?? null,
        category,
        subtasks,
      } as Task;
    })
  );

  return tasks;
}

// ── Get Single Task ──

export async function getTask(
  ctx: AuthContext,
  taskId: string
): Promise<Task | null> {
  const { dec, decN } = createFieldCrypto(ctx.householdKey);

  const doc = await db().collection("tasks").doc(taskId).get();
  if (!doc.exists) return null;

  const d = doc.data()!;

  // Verify household membership
  if (d.household_id !== ctx.householdId) return null;

  // Load subtasks
  const subtaskSnap = await db()
    .collection("subtasks")
    .where("household_id", "==", ctx.householdId)
    .where("task_id", "==", taskId)
    .orderBy("sort_order")
    .get();

  const subtasks: Subtask[] = subtaskSnap.docs.map((s) => {
    const sd = s.data();
    return {
      id: s.id,
      taskId: sd.task_id,
      householdId: sd.household_id,
      title: dec(sd.title ?? ""),
      isCompleted: sd.is_completed ?? false,
      sortOrder: sd.sort_order ?? 0,
    };
  });

  // Load category
  let category: TaskCategory | null = null;
  if (d.category_id) {
    try {
      const catDoc = await db()
        .collection("task_categories")
        .doc(d.category_id)
        .get();
      if (catDoc.exists) {
        const cd = catDoc.data()!;
        category = {
          id: catDoc.id,
          householdId: cd.household_id ?? null,
          name: dec(cd.name ?? ""),
          icon: cd.icon ?? "category",
          color: cd.color ?? "#7EA87E",
          isDefault: cd.is_default ?? false,
        };
      }
    } catch {
      // Continue without category
    }
  }

  return {
    id: doc.id,
    householdId: d.household_id,
    title: dec(d.title ?? ""),
    description: decN(d.description),
    categoryId: d.category_id ?? null,
    priority: d.priority ?? "medium",
    status: d.status ?? "pending",
    dueDate: parseTimestamp(d.due_date),
    startDate: parseTimestamp(d.start_date),
    assignedTo: d.assigned_to ?? null,
    isShared: d.is_shared ?? false,
    recurrence: d.recurrence ?? "none",
    createdBy: d.created_by,
    createdAt: parseTimestamp(d.created_at) ?? new Date().toISOString(),
    completedAt: parseTimestamp(d.completed_at),
    completedBy: d.completed_by ?? null,
    category,
    subtasks,
  };
}

// ── Create Task ──

export async function createTask(
  ctx: AuthContext,
  req: CreateTaskRequest
): Promise<Task> {
  const { enc, encN } = createFieldCrypto(ctx.householdKey);
  const now = new Date().toISOString();

  const taskRef = db().collection("tasks").doc();
  const taskData: Record<string, unknown> = {
    household_id: ctx.householdId,
    title: enc(req.title),
    description: encN(req.description ?? null),
    category_id: req.categoryId ?? null,
    priority: req.priority ?? "medium",
    status: "pending",
    due_date: req.dueDate ?? null,
    start_date: req.startDate ?? null,
    assigned_to: req.assignedTo ?? null,
    is_shared: req.isShared ?? false,
    recurrence: req.recurrence ?? "none",
    created_by: ctx.uid,
    created_at: now,
    completed_at: null,
    completed_by: null,
  };

  await taskRef.set(taskData);

  // Create subtasks if provided
  if (req.subtaskTitles?.length) {
    const batch = db().batch();
    for (let i = 0; i < req.subtaskTitles.length; i++) {
      const subRef = db().collection("subtasks").doc();
      batch.set(subRef, {
        task_id: taskRef.id,
        household_id: ctx.householdId,
        title: enc(req.subtaskTitles[i]),
        is_completed: false,
        sort_order: i,
      });
    }
    await batch.commit();
  }

  // Return the created task
  return (await getTask(ctx, taskRef.id))!;
}

// ── Update Task ──

export async function updateTask(
  ctx: AuthContext,
  req: UpdateTaskRequest
): Promise<Task | null> {
  const { enc, encN } = createFieldCrypto(ctx.householdKey);

  const docRef = db().collection("tasks").doc(req.taskId);
  const doc = await docRef.get();
  if (!doc.exists || doc.data()!.household_id !== ctx.householdId) return null;

  const updates: Record<string, unknown> = {};
  if (req.title !== undefined) updates.title = enc(req.title);
  if (req.description !== undefined) updates.description = encN(req.description);
  if (req.categoryId !== undefined) updates.category_id = req.categoryId;
  if (req.priority !== undefined) updates.priority = req.priority;
  if (req.status !== undefined) updates.status = req.status;
  if (req.dueDate !== undefined) updates.due_date = req.dueDate;
  if (req.startDate !== undefined) updates.start_date = req.startDate;
  if (req.assignedTo !== undefined) updates.assigned_to = req.assignedTo;
  if (req.isShared !== undefined) updates.is_shared = req.isShared;
  if (req.recurrence !== undefined) updates.recurrence = req.recurrence;

  if (Object.keys(updates).length > 0) {
    await docRef.update(updates);
  }

  return getTask(ctx, req.taskId);
}

// ── Complete Task ──

export async function completeTask(
  ctx: AuthContext,
  taskId: string
): Promise<boolean> {
  const docRef = db().collection("tasks").doc(taskId);
  const doc = await docRef.get();
  if (!doc.exists || doc.data()!.household_id !== ctx.householdId) return false;

  await docRef.update({
    status: "completed",
    completed_at: new Date().toISOString(),
    completed_by: ctx.uid,
  });
  return true;
}

// ── Reopen Task ──

export async function reopenTask(
  ctx: AuthContext,
  taskId: string
): Promise<boolean> {
  const docRef = db().collection("tasks").doc(taskId);
  const doc = await docRef.get();
  if (!doc.exists || doc.data()!.household_id !== ctx.householdId) return false;

  await docRef.update({
    status: "pending",
    completed_at: null,
    completed_by: null,
  });
  return true;
}

// ── Delete Task ──

export async function deleteTask(
  ctx: AuthContext,
  taskId: string
): Promise<boolean> {
  const docRef = db().collection("tasks").doc(taskId);
  const doc = await docRef.get();
  if (!doc.exists || doc.data()!.household_id !== ctx.householdId) return false;

  // Delete subtasks first
  const subtaskSnap = await db()
    .collection("subtasks")
    .where("task_id", "==", taskId)
    .where("household_id", "==", ctx.householdId)
    .get();

  const batch = db().batch();
  subtaskSnap.docs.forEach((s) => batch.delete(s.ref));
  batch.delete(docRef);
  await batch.commit();

  return true;
}

// ── Subtask Operations ──

export async function addSubtask(
  ctx: AuthContext,
  taskId: string,
  title: string,
  sortOrder = 0
): Promise<Subtask> {
  const { enc } = createFieldCrypto(ctx.householdKey);

  // Verify task belongs to household
  const taskDoc = await db().collection("tasks").doc(taskId).get();
  if (!taskDoc.exists || taskDoc.data()!.household_id !== ctx.householdId) {
    throw new Error("Task not found or access denied");
  }

  const ref = db().collection("subtasks").doc();
  await ref.set({
    task_id: taskId,
    household_id: ctx.householdId,
    title: enc(title),
    is_completed: false,
    sort_order: sortOrder,
  });

  return {
    id: ref.id,
    taskId,
    householdId: ctx.householdId,
    title,
    isCompleted: false,
    sortOrder,
  };
}

export async function toggleSubtask(
  ctx: AuthContext,
  subtaskId: string,
  isCompleted: boolean
): Promise<boolean> {
  const ref = db().collection("subtasks").doc(subtaskId);
  const doc = await ref.get();
  if (!doc.exists || doc.data()!.household_id !== ctx.householdId) return false;

  await ref.update({ is_completed: isCompleted });
  return true;
}

export async function deleteSubtask(
  ctx: AuthContext,
  subtaskId: string
): Promise<boolean> {
  const ref = db().collection("subtasks").doc(subtaskId);
  const doc = await ref.get();
  if (!doc.exists || doc.data()!.household_id !== ctx.householdId) return false;

  await ref.delete();
  return true;
}

// ── Task Stats ──

export async function getTaskStats(
  ctx: AuthContext
): Promise<TaskStats> {
  const tasksRef = db()
    .collection("tasks")
    .where("household_id", "==", ctx.householdId);

  // Use count() aggregation for efficiency
  const [completedSnap, pendingSnap] = await Promise.all([
    tasksRef.where("status", "==", "completed").count().get(),
    tasksRef.where("status", "in", ["pending", "in_progress"]).count().get(),
  ]);

  const completed = completedSnap.data().count;
  const pending = pendingSnap.data().count;

  // Overdue: pending/in_progress tasks where due_date < now
  const now = new Date().toISOString();
  const overdueSnap = await tasksRef
    .where("status", "in", ["pending", "in_progress"])
    .where("due_date", "<", now)
    .count()
    .get();

  const overdue = overdueSnap.data().count;
  const total = completed + pending;

  return {
    completed,
    pending,
    overdue,
    total,
    completionRate: total === 0 ? 0 : completed / total,
  };
}
