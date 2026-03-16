/**
 * Pacelli API — Firebase Cloud Functions entry point.
 *
 * All functions use HTTP triggers with Bearer token auth.
 * The auth middleware verifies the Firebase ID token, resolves
 * the household, and loads the encryption key per-request.
 */
import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { authenticateRequest, AuthError } from "./middleware/auth";
import { checkRateLimit, classifyOperation, RateLimitError } from "./middleware/rate-limiter";
import * as tasks from "./functions/tasks";
import * as checklists from "./functions/checklists";
import * as plans from "./functions/plans";
import * as categories from "./functions/categories";
import * as attachments from "./functions/attachments";
import * as inventory from "./functions/inventory";
import * as search from "./functions/search";
import * as feedback from "./functions/feedback";

// Initialise Firebase Admin SDK
admin.initializeApp();

/**
 * Helper: wraps an API handler with auth + rate limiting + error handling.
 *
 * @param handler — the core business logic
 * @param operationHint — optional override for rate-limit classification
 */
function apiHandler(
  handler: (ctx: Awaited<ReturnType<typeof authenticateRequest>>, body: Record<string, unknown>) => Promise<unknown>,
  operationHint?: "read" | "write"
) {
  return onRequest({ cors: true, region: "us-central1" }, async (req, res) => {
    try {
      const ctx = await authenticateRequest(req.headers.authorization);

      // Rate limiting — classify from function name or use hint
      const opType = operationHint ?? classifyOperation(req.path.replace(/^\//, ""));
      await checkRateLimit(ctx.uid, opType);

      const body = (req.body as Record<string, unknown>) ?? {};
      const result = await handler(ctx, body);
      res.json({ success: true, data: result });
    } catch (e) {
      if (e instanceof AuthError) {
        res.status(e.statusCode).json({ success: false, error: e.message });
      } else if (e instanceof RateLimitError) {
        res.set("Retry-After", String(e.retryAfterSec));
        res.status(429).json({ success: false, error: e.message });
      } else {
        console.error("[API Error]", e);
        res.status(500).json({
          success: false,
          error: e instanceof Error ? e.message : "Internal server error",
        });
      }
    }
  });
}

// ═══════════════════════════════════════════════════════════════════
//  TASK ENDPOINTS
// ═══════════════════════════════════════════════════════════════════

export const tasksList = apiHandler(async (ctx, body) => {
  return tasks.listTasks(ctx, {
    status: body.status as string | undefined,
    categoryId: body.categoryId as string | undefined,
    priority: body.priority as string | undefined,
    assignedTo: body.assignedTo as string | undefined,
    isShared: body.isShared as boolean | undefined,
  });
});

export const tasksGet = apiHandler(async (ctx, body) => {
  const taskId = body.taskId as string;
  if (!taskId) throw new Error("taskId is required");
  return tasks.getTask(ctx, taskId);
});

export const tasksCreate = apiHandler(async (ctx, body) => {
  const title = body.title as string;
  if (!title) throw new Error("title is required");
  return tasks.createTask(ctx, {
    title,
    description: body.description as string | undefined,
    categoryId: body.categoryId as string | undefined,
    priority: body.priority as string | undefined,
    dueDate: body.dueDate as string | undefined,
    startDate: body.startDate as string | undefined,
    assignedTo: body.assignedTo as string | undefined,
    isShared: body.isShared as boolean | undefined,
    recurrence: body.recurrence as string | undefined,
    subtaskTitles: body.subtaskTitles as string[] | undefined,
  });
});

export const tasksUpdate = apiHandler(async (ctx, body) => {
  const taskId = body.taskId as string;
  if (!taskId) throw new Error("taskId is required");
  return tasks.updateTask(ctx, {
    taskId,
    title: body.title as string | undefined,
    description: body.description as string | undefined,
    categoryId: body.categoryId as string | undefined,
    priority: body.priority as string | undefined,
    status: body.status as string | undefined,
    dueDate: body.dueDate as string | undefined,
    startDate: body.startDate as string | undefined,
    assignedTo: body.assignedTo as string | undefined,
    isShared: body.isShared as boolean | undefined,
    recurrence: body.recurrence as string | undefined,
  });
});

export const tasksComplete = apiHandler(async (ctx, body) => {
  const taskId = body.taskId as string;
  if (!taskId) throw new Error("taskId is required");
  return tasks.completeTask(ctx, taskId);
});

export const tasksReopen = apiHandler(async (ctx, body) => {
  const taskId = body.taskId as string;
  if (!taskId) throw new Error("taskId is required");
  return tasks.reopenTask(ctx, taskId);
});

export const tasksDelete = apiHandler(async (ctx, body) => {
  const taskId = body.taskId as string;
  if (!taskId) throw new Error("taskId is required");
  return tasks.deleteTask(ctx, taskId);
});

export const tasksStats = apiHandler(async (ctx) => {
  return tasks.getTaskStats(ctx);
});

// ── Subtask endpoints ──

export const subtasksAdd = apiHandler(async (ctx, body) => {
  const taskId = body.taskId as string;
  const title = body.title as string;
  if (!taskId || !title) throw new Error("taskId and title are required");
  return tasks.addSubtask(ctx, taskId, title, (body.sortOrder as number) ?? 0);
});

export const subtasksToggle = apiHandler(async (ctx, body) => {
  const subtaskId = body.subtaskId as string;
  const isCompleted = body.isCompleted as boolean;
  if (!subtaskId || isCompleted === undefined) {
    throw new Error("subtaskId and isCompleted are required");
  }
  return tasks.toggleSubtask(ctx, subtaskId, isCompleted);
});

export const subtasksDelete = apiHandler(async (ctx, body) => {
  const subtaskId = body.subtaskId as string;
  if (!subtaskId) throw new Error("subtaskId is required");
  return tasks.deleteSubtask(ctx, subtaskId);
});

// ═══════════════════════════════════════════════════════════════════
//  CATEGORY ENDPOINTS
// ═══════════════════════════════════════════════════════════════════

export const categoriesList = apiHandler(async (ctx) => {
  return categories.getCategories(ctx);
});

export const categoriesCreate = apiHandler(async (ctx, body) => {
  const name = body.name as string;
  if (!name) throw new Error("name is required");
  return categories.createCategory(ctx, {
    name,
    icon: body.icon as string | undefined,
    color: body.color as string | undefined,
  });
});

export const categoriesDelete = apiHandler(async (ctx, body) => {
  const categoryId = body.categoryId as string;
  if (!categoryId) throw new Error("categoryId is required");
  return categories.deleteCategory(ctx, categoryId);
});

// ═══════════════════════════════════════════════════════════════════
//  CHECKLIST ENDPOINTS
// ═══════════════════════════════════════════════════════════════════

export const checklistsList = apiHandler(async (ctx) => {
  return checklists.listChecklists(ctx);
});

export const checklistsGet = apiHandler(async (ctx, body) => {
  const checklistId = body.checklistId as string;
  if (!checklistId) throw new Error("checklistId is required");
  return checklists.getChecklist(ctx, checklistId);
});

export const checklistsCreate = apiHandler(async (ctx, body) => {
  const title = body.title as string;
  if (!title) throw new Error("title is required");
  return checklists.createChecklist(ctx, { title });
});

export const checklistsUpdate = apiHandler(async (ctx, body) => {
  const checklistId = body.checklistId as string;
  const title = body.title as string;
  if (!checklistId || !title) throw new Error("checklistId and title are required");
  return checklists.updateChecklist(ctx, checklistId, title);
});

export const checklistsDelete = apiHandler(async (ctx, body) => {
  const checklistId = body.checklistId as string;
  if (!checklistId) throw new Error("checklistId is required");
  return checklists.deleteChecklist(ctx, checklistId);
});

export const checklistItemsAdd = apiHandler(async (ctx, body) => {
  const checklistId = body.checklistId as string;
  const title = body.title as string;
  if (!checklistId || !title) throw new Error("checklistId and title are required");
  return checklists.addChecklistItem(ctx, {
    checklistId,
    title,
    quantity: body.quantity as string | undefined,
  });
});

export const checklistItemsToggle = apiHandler(async (ctx, body) => {
  const itemId = body.itemId as string;
  const isChecked = body.isChecked as boolean;
  if (!itemId || isChecked === undefined) {
    throw new Error("itemId and isChecked are required");
  }
  return checklists.toggleChecklistItem(ctx, itemId, isChecked);
});

export const checklistItemsDelete = apiHandler(async (ctx, body) => {
  const itemId = body.itemId as string;
  if (!itemId) throw new Error("itemId is required");
  return checklists.deleteChecklistItem(ctx, itemId);
});

export const checklistItemsPushAsTask = apiHandler(async (ctx, body) => {
  const itemId = body.itemId as string;
  const itemTitle = body.itemTitle as string;
  if (!itemId || !itemTitle) throw new Error("itemId and itemTitle are required");
  return checklists.pushChecklistItemAsTask(ctx, itemId, itemTitle);
});

// ═══════════════════════════════════════════════════════════════════
//  PLAN ENDPOINTS
// ═══════════════════════════════════════════════════════════════════

export const plansList = apiHandler(async (ctx) => {
  return plans.listPlans(ctx);
});

export const plansGet = apiHandler(async (ctx, body) => {
  const planId = body.planId as string;
  if (!planId) throw new Error("planId is required");
  return plans.getPlan(ctx, planId);
});

export const plansCreate = apiHandler(async (ctx, body) => {
  const title = body.title as string;
  const startDate = body.startDate as string;
  const endDate = body.endDate as string;
  if (!title || !startDate || !endDate) {
    throw new Error("title, startDate, and endDate are required");
  }
  return plans.createPlan(ctx, {
    title,
    type: body.type as string | undefined,
    startDate,
    endDate,
    isTemplate: body.isTemplate as boolean | undefined,
    templateName: body.templateName as string | undefined,
  });
});

export const plansDelete = apiHandler(async (ctx, body) => {
  const planId = body.planId as string;
  if (!planId) throw new Error("planId is required");
  return plans.deletePlan(ctx, planId);
});

export const plansUpdateStatus = apiHandler(async (ctx, body) => {
  const planId = body.planId as string;
  const status = body.status as string;
  if (!planId || !status) throw new Error("planId and status are required");
  return plans.updatePlanStatus(ctx, planId, status);
});

export const plansFinalise = apiHandler(async (ctx, body) => {
  const planId = body.planId as string;
  const entryActions = body.entryActions as Record<string, string>;
  if (!planId || !entryActions) {
    throw new Error("planId and entryActions are required");
  }
  return plans.finalisePlan(ctx, { planId, entryActions });
});

// ── Plan Entries ──

export const planEntriesAdd = apiHandler(async (ctx, body) => {
  const planId = body.planId as string;
  const entryDate = body.entryDate as string;
  const title = body.title as string;
  if (!planId || !entryDate || !title) {
    throw new Error("planId, entryDate, and title are required");
  }
  return plans.addPlanEntry(ctx, {
    planId,
    entryDate,
    title,
    label: body.label as string | undefined,
    description: body.description as string | undefined,
    sortOrder: body.sortOrder as number | undefined,
  });
});

export const planEntriesUpdate = apiHandler(async (ctx, body) => {
  const entryId = body.entryId as string;
  if (!entryId) throw new Error("entryId is required");
  return plans.updatePlanEntry(ctx, {
    entryId,
    title: body.title as string | undefined,
    label: body.label as string | undefined,
    description: body.description as string | undefined,
  });
});

export const planEntriesDelete = apiHandler(async (ctx, body) => {
  const entryId = body.entryId as string;
  if (!entryId) throw new Error("entryId is required");
  return plans.deletePlanEntry(ctx, entryId);
});

// ── Plan Checklist Items ──

export const planChecklistItemsAdd = apiHandler(async (ctx, body) => {
  const planId = body.planId as string;
  const title = body.title as string;
  if (!planId || !title) throw new Error("planId and title are required");
  return plans.addPlanChecklistItem(ctx, {
    planId,
    entryId: body.entryId as string | undefined,
    title,
    quantity: body.quantity as string | undefined,
  });
});

export const planChecklistItemsToggle = apiHandler(async (ctx, body) => {
  const itemId = body.itemId as string;
  const isChecked = body.isChecked as boolean;
  if (!itemId || isChecked === undefined) {
    throw new Error("itemId and isChecked are required");
  }
  return plans.togglePlanChecklistItem(ctx, itemId, isChecked);
});

export const planChecklistItemsDelete = apiHandler(async (ctx, body) => {
  const itemId = body.itemId as string;
  if (!itemId) throw new Error("itemId is required");
  return plans.deletePlanChecklistItem(ctx, itemId);
});

export const planChecklistItemsPushAsTask = apiHandler(async (ctx, body) => {
  const itemId = body.itemId as string;
  const itemTitle = body.itemTitle as string;
  if (!itemId || !itemTitle) throw new Error("itemId and itemTitle are required");
  return checklists.pushPlanChecklistItemAsTask(ctx, itemId, itemTitle);
});

// ── Templates ──

export const planTemplatesList = apiHandler(async (ctx) => {
  return plans.getTemplates(ctx);
});

export const planTemplatesSave = apiHandler(async (ctx, body) => {
  const planId = body.planId as string;
  const templateName = body.templateName as string;
  if (!planId || !templateName) {
    throw new Error("planId and templateName are required");
  }
  return plans.savePlanAsTemplate(ctx, { planId, templateName });
});

export const planTemplatesCreate = apiHandler(async (ctx, body) => {
  const templateId = body.templateId as string;
  const title = body.title as string;
  const startDate = body.startDate as string;
  const endDate = body.endDate as string;
  if (!templateId || !title || !startDate || !endDate) {
    throw new Error("templateId, title, startDate, and endDate are required");
  }
  return plans.createFromTemplate(ctx, {
    templateId,
    title,
    startDate,
    endDate,
  });
});

// ═══════════════════════════════════════════════════════════════════
//  ATTACHMENT ENDPOINTS (Task + Plan)
// ═══════════════════════════════════════════════════════════════════

export const taskAttachmentsCreate = apiHandler(async (ctx, body) => {
  const taskId = body.taskId as string;
  const driveFileId = body.driveFileId as string;
  const fileName = body.fileName as string;
  if (!taskId || !driveFileId || !fileName) {
    throw new Error("taskId, driveFileId, and fileName are required");
  }
  return attachments.createTaskAttachment(ctx, {
    taskId,
    driveFileId,
    fileName,
    mimeType: body.mimeType as string,
    fileSizeBytes: body.fileSizeBytes as number,
    thumbnailUrl: body.thumbnailUrl as string | undefined,
    webViewLink: body.webViewLink as string,
    description: body.description as string | undefined,
  });
});

export const taskAttachmentsList = apiHandler(async (ctx, body) => {
  const taskId = body.taskId as string;
  if (!taskId) throw new Error("taskId is required");
  return attachments.getTaskAttachments(ctx, taskId);
});

export const taskAttachmentsDelete = apiHandler(async (ctx, body) => {
  const attachmentId = body.attachmentId as string;
  if (!attachmentId) throw new Error("attachmentId is required");
  return attachments.deleteTaskAttachment(ctx, attachmentId);
});

export const planAttachmentsCreate = apiHandler(async (ctx, body) => {
  const planId = body.planId as string;
  const entryId = body.entryId as string;
  const driveFileId = body.driveFileId as string;
  const fileName = body.fileName as string;
  if (!planId || !entryId || !driveFileId || !fileName) {
    throw new Error("planId, entryId, driveFileId, and fileName are required");
  }
  return attachments.createPlanAttachment(ctx, {
    planId,
    entryId,
    driveFileId,
    fileName,
    mimeType: body.mimeType as string,
    fileSizeBytes: body.fileSizeBytes as number,
    thumbnailUrl: body.thumbnailUrl as string | undefined,
    webViewLink: body.webViewLink as string,
    description: body.description as string | undefined,
  });
});

export const planAttachmentsListByEntry = apiHandler(async (ctx, body) => {
  const entryId = body.entryId as string;
  if (!entryId) throw new Error("entryId is required");
  return attachments.getPlanEntryAttachments(ctx, entryId);
});

export const planAttachmentsListByPlan = apiHandler(async (ctx, body) => {
  const planId = body.planId as string;
  if (!planId) throw new Error("planId is required");
  return attachments.getPlanAttachments(ctx, planId);
});

export const planAttachmentsDelete = apiHandler(async (ctx, body) => {
  const attachmentId = body.attachmentId as string;
  if (!attachmentId) throw new Error("attachmentId is required");
  return attachments.deletePlanAttachment(ctx, attachmentId);
});

// ═══════════════════════════════════════════════════════════════════
//  INVENTORY ENDPOINTS
// ═══════════════════════════════════════════════════════════════════

export const inventoryList = apiHandler(async (ctx, body) => {
  return inventory.listInventoryItems(ctx, {
    categoryId: body.categoryId as string | undefined,
    locationId: body.locationId as string | undefined,
    lowStockOnly: body.lowStockOnly as boolean | undefined,
    expiringOnly: body.expiringOnly as boolean | undefined,
  });
});

export const inventoryGet = apiHandler(async (ctx, body) => {
  const itemId = body.itemId as string;
  if (!itemId) throw new Error("itemId is required");
  return inventory.getInventoryItem(ctx, itemId);
});

export const inventoryCreate = apiHandler(async (ctx, body) => {
  const name = body.name as string;
  if (!name) throw new Error("name is required");
  return inventory.createInventoryItem(ctx, {
    name,
    description: body.description as string | undefined,
    categoryId: body.categoryId as string | undefined,
    locationId: body.locationId as string | undefined,
    quantity: body.quantity as number | undefined,
    unit: body.unit as string | undefined,
    lowStockThreshold: body.lowStockThreshold as number | undefined,
    barcode: body.barcode as string | undefined,
    barcodeType: body.barcodeType as string | undefined,
    expiryDate: body.expiryDate as string | undefined,
    purchaseDate: body.purchaseDate as string | undefined,
    notes: body.notes as string | undefined,
  });
});

export const inventoryUpdate = apiHandler(async (ctx, body) => {
  const itemId = body.itemId as string;
  if (!itemId) throw new Error("itemId is required");
  return inventory.updateInventoryItem(ctx, {
    itemId,
    name: body.name as string | undefined,
    description: body.description as string | undefined,
    categoryId: body.categoryId as string | undefined,
    locationId: body.locationId as string | undefined,
    quantity: body.quantity as number | undefined,
    unit: body.unit as string | undefined,
    lowStockThreshold: body.lowStockThreshold as number | undefined,
    barcode: body.barcode as string | undefined,
    barcodeType: body.barcodeType as string | undefined,
    expiryDate: body.expiryDate as string | undefined,
    purchaseDate: body.purchaseDate as string | undefined,
    notes: body.notes as string | undefined,
  });
});

export const inventoryDelete = apiHandler(async (ctx, body) => {
  const itemId = body.itemId as string;
  if (!itemId) throw new Error("itemId is required");
  return inventory.deleteInventoryItem(ctx, itemId);
});

export const inventoryStats = apiHandler(async (ctx) => {
  return inventory.getInventoryStats(ctx);
});

// ── Inventory Categories ──

export const inventoryCategoriesList = apiHandler(async (ctx) => {
  return inventory.getInventoryCategories(ctx);
});

export const inventoryCategoriesCreate = apiHandler(async (ctx, body) => {
  const name = body.name as string;
  if (!name) throw new Error("name is required");
  return inventory.createInventoryCategory(ctx, {
    name,
    icon: body.icon as string | undefined,
    color: body.color as string | undefined,
  });
});

export const inventoryCategoriesDelete = apiHandler(async (ctx, body) => {
  const categoryId = body.categoryId as string;
  if (!categoryId) throw new Error("categoryId is required");
  return inventory.deleteInventoryCategory(ctx, categoryId);
});

// ── Inventory Locations ──

export const inventoryLocationsList = apiHandler(async (ctx) => {
  return inventory.getInventoryLocations(ctx);
});

export const inventoryLocationsCreate = apiHandler(async (ctx, body) => {
  const name = body.name as string;
  if (!name) throw new Error("name is required");
  return inventory.createInventoryLocation(ctx, {
    name,
    icon: body.icon as string | undefined,
  });
});

export const inventoryLocationsDelete = apiHandler(async (ctx, body) => {
  const locationId = body.locationId as string;
  if (!locationId) throw new Error("locationId is required");
  return inventory.deleteInventoryLocation(ctx, locationId);
});

// ── Inventory Logs ──

export const inventoryLogsCreate = apiHandler(async (ctx, body) => {
  const itemId = body.itemId as string;
  const action = body.action as string;
  if (!itemId || !action) throw new Error("itemId and action are required");
  return inventory.logInventoryAction(ctx, {
    itemId,
    action,
    quantityChange: body.quantityChange as number,
    quantityAfter: body.quantityAfter as number,
    note: body.note as string | undefined,
  });
});

export const inventoryLogsList = apiHandler(async (ctx, body) => {
  const itemId = body.itemId as string;
  if (!itemId) throw new Error("itemId is required");
  return inventory.getInventoryLogs(ctx, {
    itemId,
    limit: body.limit as number | undefined,
  });
});

// ── Inventory Attachments ──

export const inventoryAttachmentsCreate = apiHandler(async (ctx, body) => {
  const itemId = body.itemId as string;
  const driveFileId = body.driveFileId as string;
  const fileName = body.fileName as string;
  if (!itemId || !driveFileId || !fileName) {
    throw new Error("itemId, driveFileId, and fileName are required");
  }
  return inventory.createInventoryAttachment(ctx, {
    itemId,
    driveFileId,
    fileName,
    mimeType: body.mimeType as string,
    fileSizeBytes: body.fileSizeBytes as number,
    thumbnailUrl: body.thumbnailUrl as string | undefined,
    webViewLink: body.webViewLink as string,
    description: body.description as string | undefined,
  });
});

export const inventoryAttachmentsList = apiHandler(async (ctx, body) => {
  const itemId = body.itemId as string;
  if (!itemId) throw new Error("itemId is required");
  return inventory.getInventoryAttachments(ctx, itemId);
});

export const inventoryAttachmentsDelete = apiHandler(async (ctx, body) => {
  const attachmentId = body.attachmentId as string;
  if (!attachmentId) throw new Error("attachmentId is required");
  return inventory.deleteInventoryAttachment(ctx, attachmentId);
});

// ═══════════════════════════════════════════════════════════════════
//  SEARCH
// ═══════════════════════════════════════════════════════════════════

export const searchAll = apiHandler(async (ctx, body) => {
  const query = body.query as string;
  if (!query) throw new Error("query is required");
  return search.searchHousehold(ctx, {
    query,
    entityTypes: body.entityTypes as string[] | undefined,
  });
});

// ═══════════════════════════════════════════════════════════════════
//  FEEDBACK & DIAGNOSTICS
// ═══════════════════════════════════════════════════════════════════

export const feedbackList = apiHandler(async (ctx, body) => {
  return feedback.listFeedback(ctx, {
    limit: body.limit as number | undefined,
    type: body.type as string | undefined,
  });
}, "read");

export const diagnosticsList = apiHandler(async (ctx, body) => {
  return feedback.listDiagnostics(ctx, {
    limit: body.limit as number | undefined,
    kind: body.kind as string | undefined,
  });
}, "read");

export const diagnosticStatsGet = apiHandler(async (ctx) => {
  return feedback.getDiagnosticStats(ctx);
}, "read");

export const weeklyDigestGenerate = apiHandler(async (ctx) => {
  return feedback.generateWeeklyDigest(ctx);
});

export const weeklyDigestList = apiHandler(async (ctx, body) => {
  return feedback.listDigests(ctx, {
    limit: body.limit as number | undefined,
  });
}, "read");

// ═══════════════════════════════════════════════════════════════════
//  AI CHAT (In-App Assistant)
// ═══════════════════════════════════════════════════════════════════

/**
 * In-app AI chat endpoint.
 *
 * Receives a conversation history (user/assistant message pairs) and
 * routes the latest user message to the appropriate Pacelli function
 * or returns a natural-language response.
 *
 * For now this is a simple routing layer that:
 * 1. Detects intent from the user's latest message
 * 2. Calls the relevant Pacelli function(s)
 * 3. Returns a formatted natural-language reply
 *
 * A full LLM integration can be added later by proxying to an AI
 * provider (OpenAI, Anthropic, Gemini) with function calling.
 */
export const aiChat = apiHandler(async (ctx, body) => {
  const messages = body.messages as Array<{ role: string; content: string }>;
  if (!messages || messages.length === 0) {
    throw new Error("messages array is required and must not be empty");
  }

  const lastMessage = messages[messages.length - 1];
  if (lastMessage.role !== "user") {
    throw new Error("Last message must be from the user");
  }

  const userQuery = lastMessage.content.toLowerCase();

  // ── Intent routing (simple keyword matching for MVP) ──
  // This will be replaced by LLM function-calling in a future iteration.

  // Task queries
  if (userQuery.includes("task") && (userQuery.includes("due") || userQuery.includes("week") || userQuery.includes("today") || userQuery.includes("overdue"))) {
    const result = await tasks.listTasks(ctx, { status: "pending" });
    const taskList = result as unknown as Array<Record<string, unknown>>;
    if (taskList.length === 0) {
      return { reply: "You have no pending tasks. Everything is up to date!" };
    }
    const summary = taskList.slice(0, 10).map((t, i) =>
      `${i + 1}. ${t.title}${t.dueDate ? ` (due ${t.dueDate})` : ""}${t.priority ? ` [${t.priority}]` : ""}`
    ).join("\n");
    return {
      reply: `Here are your pending tasks:\n\n${summary}${taskList.length > 10 ? `\n\n...and ${taskList.length - 10} more.` : ""}`,
    };
  }

  // Shopping / checklist queries
  if (userQuery.includes("shopping") || userQuery.includes("checklist") || userQuery.includes("list")) {
    const result = await checklists.listChecklists(ctx);
    const lists = result as unknown as Array<Record<string, unknown>>;
    if (lists.length === 0) {
      return { reply: "You don't have any checklists yet. Would you like me to create one?" };
    }
    const summary = lists.map((l, i) => `${i + 1}. ${l.title}`).join("\n");
    return {
      reply: `Here are your checklists:\n\n${summary}\n\nWhich one would you like to see?`,
    };
  }

  // Inventory / expiry queries
  if (userQuery.includes("expir") || userQuery.includes("inventory") || userQuery.includes("stock")) {
    const result = await inventory.listInventoryItems(ctx, {
      expiringOnly: userQuery.includes("expir"),
      lowStockOnly: userQuery.includes("stock") || userQuery.includes("low"),
    });
    const items = result as unknown as Array<Record<string, unknown>>;
    if (items.length === 0) {
      return { reply: "No items found matching that query. Your inventory looks good!" };
    }
    const summary = items.slice(0, 10).map((item, i) =>
      `${i + 1}. ${item.name}${item.quantity !== undefined ? ` (qty: ${item.quantity})` : ""}${item.expiryDate ? ` — expires ${item.expiryDate}` : ""}`
    ).join("\n");
    return {
      reply: `Here are the matching inventory items:\n\n${summary}${items.length > 10 ? `\n\n...and ${items.length - 10} more.` : ""}`,
    };
  }

  // Plan queries
  if (userQuery.includes("plan") || userQuery.includes("schedule") || userQuery.includes("trip")) {
    const result = await plans.listPlans(ctx);
    const planList = result as unknown as Array<Record<string, unknown>>;
    if (planList.length === 0) {
      return { reply: "You don't have any plans yet. Would you like to create one?" };
    }
    const summary = planList.map((p, i) => `${i + 1}. ${p.title} (${p.status})`).join("\n");
    return { reply: `Your plans:\n\n${summary}` };
  }

  // Stats / overview
  if (userQuery.includes("overview") || userQuery.includes("summary") || userQuery.includes("stats") || userQuery.includes("how am i doing")) {
    const taskStats = await tasks.getTaskStats(ctx);
    const invStats = await inventory.getInventoryStats(ctx);
    return {
      reply: `Here's your household overview:\n\n📋 Tasks: ${JSON.stringify(taskStats)}\n📦 Inventory: ${JSON.stringify(invStats)}`,
    };
  }

  // Fallback — friendly response
  return {
    reply: "I'm your household assistant. I can help you with:\n\n• Checking tasks & deadlines\n• Viewing shopping lists & checklists\n• Inventory & expiry tracking\n• Plans & schedules\n• Household overview\n\nWhat would you like to know?",
  };
}, "read");
