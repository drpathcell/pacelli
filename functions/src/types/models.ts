/**
 * TypeScript interfaces matching Pacelli's Dart model classes.
 * These represent the DECRYPTED (plaintext) shapes returned by the API.
 */

// ═══════════════════════════════════════════════════════════════════
//  TASKS
// ═══════════════════════════════════════════════════════════════════

export interface Task {
  id: string;
  householdId: string;
  title: string;
  description: string | null;
  categoryId: string | null;
  priority: "low" | "medium" | "high" | "urgent";
  status: "pending" | "in_progress" | "completed";
  dueDate: string | null; // ISO 8601
  startDate: string | null;
  assignedTo: string | null;
  isShared: boolean;
  recurrence: "none" | "daily" | "weekly" | "monthly";
  createdBy: string;
  createdAt: string;
  completedAt: string | null;
  completedBy: string | null;
  category: TaskCategory | null;
  subtasks: Subtask[];
}

export interface Subtask {
  id: string;
  taskId: string;
  householdId: string;
  title: string;
  isCompleted: boolean;
  sortOrder: number;
}

export interface TaskCategory {
  id: string;
  householdId: string | null;
  name: string;
  icon: string;
  color: string;
  isDefault: boolean;
}

export interface TaskStats {
  completed: number;
  pending: number;
  overdue: number;
  total: number;
  completionRate: number;
}

export interface ProfileRef {
  id: string;
  fullName: string | null;
  avatarUrl: string | null;
}

// ═══════════════════════════════════════════════════════════════════
//  CHECKLISTS
// ═══════════════════════════════════════════════════════════════════

export interface Checklist {
  id: string;
  householdId: string;
  title: string;
  createdBy: string;
  createdAt: string;
  updatedAt: string | null;
  items: ChecklistItem[];
}

export interface ChecklistItem {
  id: string;
  checklistId: string;
  householdId: string;
  title: string;
  quantity: string | null;
  isChecked: boolean;
  createdBy: string | null;
  createdAt: string | null;
  checkedAt: string | null;
  checkedBy: string | null;
}

// ═══════════════════════════════════════════════════════════════════
//  PLANS
// ═══════════════════════════════════════════════════════════════════

export interface Plan {
  id: string;
  householdId: string;
  title: string;
  type: "weekly" | "daily" | "custom";
  status: "draft" | "finalised";
  startDate: string; // YYYY-MM-DD
  endDate: string;
  isTemplate: boolean;
  templateName: string | null;
  createdBy: string;
  createdAt: string;
  updatedAt: string | null;
  entries: PlanEntry[];
  checklistItems: PlanChecklistItem[];
}

export interface PlanEntry {
  id: string;
  planId: string;
  householdId: string;
  entryDate: string; // YYYY-MM-DD
  title: string;
  label: string | null;
  description: string | null;
  sortOrder: number;
  createdBy: string | null;
  createdAt: string | null;
}

export interface PlanChecklistItem {
  id: string;
  planId: string;
  householdId: string;
  entryId: string | null;
  title: string;
  quantity: string | null;
  isChecked: boolean;
  createdBy: string | null;
  createdAt: string | null;
  checkedAt: string | null;
  checkedBy: string | null;
}

// ═══════════════════════════════════════════════════════════════════
//  ATTACHMENTS (Task + Plan)
// ═══════════════════════════════════════════════════════════════════

export interface TaskAttachment {
  id: string;
  taskId: string;
  householdId: string;
  driveFileId: string;
  fileName: string;
  mimeType: string;
  fileSizeBytes: number;
  thumbnailUrl: string | null;
  webViewLink: string;
  uploadedBy: string;
  uploadedAt: string;
  description: string | null;
}

export interface PlanAttachment {
  id: string;
  planId: string;
  entryId: string;
  householdId: string;
  driveFileId: string;
  fileName: string;
  mimeType: string;
  fileSizeBytes: number;
  thumbnailUrl: string | null;
  webViewLink: string;
  uploadedBy: string;
  uploadedAt: string;
  description: string | null;
}

// ═══════════════════════════════════════════════════════════════════
//  INVENTORY
// ═══════════════════════════════════════════════════════════════════

export interface InventoryItem {
  id: string;
  householdId: string;
  name: string;
  description: string | null;
  categoryId: string | null;
  locationId: string | null;
  quantity: number;
  unit: string;
  lowStockThreshold: number | null;
  barcode: string | null;
  barcodeType: "real" | "virtual" | "none";
  expiryDate: string | null;
  purchaseDate: string | null;
  notes: string | null;
  createdBy: string;
  createdAt: string;
  updatedAt: string | null;
  category: InventoryCategory | null;
  location: InventoryLocation | null;
  attachments: InventoryAttachment[];
}

export interface InventoryCategory {
  id: string;
  householdId: string;
  name: string;
  icon: string;
  color: string;
  isDefault: boolean;
  sortOrder: number;
  createdAt: string | null;
}

export interface InventoryLocation {
  id: string;
  householdId: string;
  name: string;
  icon: string;
  isDefault: boolean;
  sortOrder: number;
  createdAt: string | null;
}

export interface InventoryLog {
  id: string;
  itemId: string;
  householdId: string;
  action: "added" | "removed" | "adjusted" | "expired";
  quantityChange: number;
  quantityAfter: number;
  note: string | null;
  performedBy: string;
  performedAt: string;
}

export interface InventoryAttachment {
  id: string;
  itemId: string;
  householdId: string;
  driveFileId: string;
  fileName: string;
  mimeType: string;
  fileSizeBytes: number;
  thumbnailUrl: string | null;
  webViewLink: string;
  description: string | null;
  uploadedBy: string;
  uploadedAt: string;
}

export interface InventoryStats {
  totalItems: number;
  lowStock: number;
  expiringSoon: number;
  expired: number;
}

// ═══════════════════════════════════════════════════════════════════
//  SEARCH
// ═══════════════════════════════════════════════════════════════════

export interface SearchResult {
  id: string;
  entityType: "task" | "checklist" | "plan" | "attachment" | "inventory";
  householdId: string;
  title: string;
  subtitle: string | null;
  parentId: string | null;
  metadata: Record<string, unknown>;
  relevanceDate: string | null;
}

// ═══════════════════════════════════════════════════════════════════
//  REQUEST TYPES
// ═══════════════════════════════════════════════════════════════════

// ── Tasks ──

export interface ListTasksRequest {
  status?: string;
  categoryId?: string;
  priority?: string;
  assignedTo?: string;
  isShared?: boolean;
}

export interface CreateTaskRequest {
  title: string;
  description?: string;
  categoryId?: string;
  priority?: string;
  dueDate?: string;
  startDate?: string;
  assignedTo?: string;
  isShared?: boolean;
  recurrence?: string;
  subtaskTitles?: string[];
}

export interface UpdateTaskRequest {
  taskId: string;
  title?: string;
  description?: string;
  categoryId?: string;
  priority?: string;
  status?: string;
  dueDate?: string;
  startDate?: string;
  assignedTo?: string;
  isShared?: boolean;
  recurrence?: string;
}

// ── Checklists ──

export interface CreateChecklistRequest {
  title: string;
}

export interface AddChecklistItemRequest {
  checklistId: string;
  title: string;
  quantity?: string;
}

// ── Plans ──

export interface CreatePlanRequest {
  title: string;
  type?: string;
  startDate: string;
  endDate: string;
  isTemplate?: boolean;
  templateName?: string;
}

export interface AddPlanEntryRequest {
  planId: string;
  entryDate: string;
  title: string;
  label?: string;
  description?: string;
  sortOrder?: number;
}

export interface UpdatePlanEntryRequest {
  entryId: string;
  title?: string;
  label?: string;
  description?: string;
}

export interface AddPlanChecklistItemRequest {
  planId: string;
  entryId?: string;
  title: string;
  quantity?: string;
}

export interface SaveAsTemplateRequest {
  planId: string;
  templateName: string;
}

export interface CreateFromTemplateRequest {
  templateId: string;
  title: string;
  startDate: string;
  endDate: string;
}

export interface FinalisePlanRequest {
  planId: string;
  entryActions: Record<string, string>;
}

// ── Inventory ──

export interface CreateInventoryItemRequest {
  name: string;
  description?: string;
  categoryId?: string;
  locationId?: string;
  quantity?: number;
  unit?: string;
  lowStockThreshold?: number;
  barcode?: string;
  barcodeType?: string;
  expiryDate?: string;
  purchaseDate?: string;
  notes?: string;
}

export interface UpdateInventoryItemRequest {
  itemId: string;
  name?: string;
  description?: string;
  categoryId?: string;
  locationId?: string;
  quantity?: number;
  unit?: string;
  lowStockThreshold?: number;
  barcode?: string;
  barcodeType?: string;
  expiryDate?: string;
  purchaseDate?: string;
  notes?: string;
}

export interface ListInventoryRequest {
  categoryId?: string;
  locationId?: string;
  lowStockOnly?: boolean;
  expiringOnly?: boolean;
}

export interface LogInventoryActionRequest {
  itemId: string;
  action: string;
  quantityChange: number;
  quantityAfter: number;
  note?: string;
}

export interface GetInventoryLogsRequest {
  itemId: string;
  limit?: number;
}

// ── Categories ──

export interface CreateCategoryRequest {
  name: string;
  icon?: string;
  color?: string;
}

export interface CreateInventoryCategoryRequest {
  name: string;
  icon?: string;
  color?: string;
}

export interface CreateInventoryLocationRequest {
  name: string;
  icon?: string;
}

// ── Attachments ──

export interface CreateAttachmentRequest {
  taskId: string;
  driveFileId: string;
  fileName: string;
  mimeType: string;
  fileSizeBytes: number;
  thumbnailUrl?: string;
  webViewLink: string;
  description?: string;
}

export interface CreatePlanAttachmentRequest {
  planId: string;
  entryId: string;
  driveFileId: string;
  fileName: string;
  mimeType: string;
  fileSizeBytes: number;
  thumbnailUrl?: string;
  webViewLink: string;
  description?: string;
}

export interface CreateInventoryAttachmentRequest {
  itemId: string;
  driveFileId: string;
  fileName: string;
  mimeType: string;
  fileSizeBytes: number;
  thumbnailUrl?: string;
  webViewLink: string;
  description?: string;
}

// ── Search ──

export interface SearchRequest {
  query: string;
  entityTypes?: string[];
}

// ── API response wrapper ──

export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
}
