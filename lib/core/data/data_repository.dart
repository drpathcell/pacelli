import '../models/models.dart';

/// Abstract interface for all user-data storage operations.
///
/// Implementations exist for:
///   • [FirebaseDataRepository] — Cloud Firestore with E2E encryption
///   • LocalDataRepository — SQLite (on-device, offline-first)
///
/// Household management (invites, members) is handled separately by
/// HouseholdService and is NOT part of this interface.
abstract class DataRepository {
  // ═══════════════════════════════════════════════════════════════════
  //  TASKS
  // ═══════════════════════════════════════════════════════════════════

  /// Creates a new task. Returns the created task.
  Future<Task> createTask({
    required String householdId,
    required String title,
    String? description,
    String? categoryId,
    String priority = 'medium',
    DateTime? dueDate,
    DateTime? startDate,
    String? assignedTo,
    bool isShared = false,
    String recurrence = 'none',
    List<String>? subtaskTitles,
  });

  /// Fetches all tasks for a household with optional filters.
  Future<List<Task>> getTasks({
    required String householdId,
    String? status,
    String? categoryId,
    String? assignedTo,
    String? priority,
    bool? isShared,
  });

  /// Fetches a single task by ID.
  Future<Task> getTask(String taskId);

  /// Updates task fields. Only non-null fields are changed.
  Future<void> updateTask({
    required String taskId,
    String? title,
    String? description,
    String? categoryId,
    String? priority,
    String? status,
    DateTime? dueDate,
    DateTime? startDate,
    String? assignedTo,
    bool? isShared,
    String? recurrence,
  });

  /// Marks a task as completed.
  Future<void> completeTask(String taskId);

  /// Reopens a completed task.
  Future<void> reopenTask(String taskId);

  /// Deletes a task.
  Future<void> deleteTask(String taskId);

  // ── Subtasks ──

  /// Adds a subtask to a task. Returns the created subtask.
  Future<Subtask> addSubtask({
    required String taskId,
    required String householdId,
    required String title,
    int sortOrder = 0,
  });

  /// Toggles subtask completion.
  Future<void> toggleSubtask({
    required String subtaskId,
    required bool isCompleted,
  });

  /// Deletes a subtask.
  Future<void> deleteSubtask(String subtaskId);

  // ── Categories ──

  /// Gets all categories for a household.
  Future<List<TaskCategory>> getCategories(String householdId);

  /// Creates a new category. Returns the created category.
  Future<TaskCategory> createCategory({
    required String householdId,
    required String name,
    String icon = 'category',
    String color = '#7EA87E',
  });

  /// Deletes a custom (non-default) category.
  Future<void> deleteCategory(String categoryId);

  // ── Stats ──

  /// Gets task statistics for the household dashboard.
  Future<TaskStats> getTaskStats(String householdId);

  // ═══════════════════════════════════════════════════════════════════
  //  CHECKLISTS (standalone)
  // ═══════════════════════════════════════════════════════════════════

  /// Creates a new standalone checklist. Returns it.
  Future<Checklist> createChecklist({
    required String householdId,
    required String title,
  });

  /// Fetches all standalone checklists (with items) for a household.
  Future<List<Checklist>> getChecklists(String householdId);

  /// Updates a checklist title.
  Future<void> updateChecklist(String checklistId, String title);

  /// Deletes a checklist and all its items.
  Future<void> deleteChecklist(String checklistId);

  /// Adds an item to a checklist. Returns it.
  Future<ChecklistItem> addChecklistItem({
    required String checklistId,
    required String householdId,
    required String title,
    String? quantity,
  });

  /// Toggles a checklist item's checked state.
  Future<void> toggleChecklistItem(String itemId, bool isChecked);

  /// Deletes a checklist item.
  Future<void> deleteChecklistItem(String itemId);

  /// Pushes a checklist item as a task, then removes it.
  Future<void> pushChecklistItemAsTask({
    required String householdId,
    required String itemTitle,
    required String itemId,
  });

  /// Pushes a plan checklist item as a task, then removes it.
  Future<void> pushPlanChecklistItemAsTask({
    required String householdId,
    required String itemTitle,
    required String itemId,
  });

  // ═══════════════════════════════════════════════════════════════════
  //  PLANS (scratch plans)
  // ═══════════════════════════════════════════════════════════════════

  /// Creates a new plan. Returns it.
  Future<Plan> createPlan({
    required String householdId,
    required String title,
    String type = 'weekly',
    required DateTime startDate,
    required DateTime endDate,
    bool isTemplate = false,
    String? templateName,
  });

  /// Fetches all non-template plans for a household (with entries + checklist).
  Future<List<Plan>> getPlans(String householdId);

  /// Fetches a single plan with all entries and checklist items.
  Future<Plan> getPlan(String planId);

  /// Deletes a plan.
  Future<void> deletePlan(String planId);

  /// Updates plan status (e.g. draft → finalised).
  Future<void> updatePlanStatus(String planId, String status);

  // ── Plan Entries ──

  /// Adds an entry to a plan day. Returns it.
  Future<PlanEntry> addEntry({
    required String planId,
    required String householdId,
    required DateTime entryDate,
    required String title,
    String? label,
    String? description,
    int sortOrder = 0,
  });

  /// Updates an existing entry.
  Future<void> updateEntry({
    required String entryId,
    String? title,
    String? label,
    String? description,
  });

  /// Deletes an entry.
  Future<void> deleteEntry(String entryId);

  // ── Plan Checklist Items ──

  /// Adds a checklist item to a plan. Returns it.
  Future<PlanChecklistItem> addPlanChecklistItem({
    required String planId,
    required String householdId,
    String? entryId,
    required String title,
    String? quantity,
  });

  /// Toggles a plan checklist item.
  Future<void> togglePlanChecklistItem(String itemId, bool isChecked);

  /// Deletes a plan checklist item.
  Future<void> deletePlanChecklistItem(String itemId);

  // ── Templates ──

  /// Fetches all user-created templates for a household.
  Future<List<Plan>> getTemplates(String householdId);

  /// Saves a copy of a plan as a template.
  Future<Plan> savePlanAsTemplate({
    required String planId,
    required String templateName,
    required String householdId,
  });

  /// Creates a new plan from a template with shifted dates.
  Future<Plan> createFromTemplate({
    required String templateId,
    required String householdId,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
  });

  // ── Realtime ──

  /// Subscribes to entry changes for a plan. Returns a channel/subscription.
  ///
  /// For Firebase: returns a [StreamSubscription].
  /// For SQLite: returns a StreamController-backed subscription.
  dynamic subscribeToEntries(
    String planId, {
    required void Function(dynamic payload) onEvent,
  });

  /// Subscribes to checklist changes for a plan.
  dynamic subscribeToChecklist(
    String planId, {
    required void Function(dynamic payload) onEvent,
  });

  // ── Finalise ──

  /// Pushes plan entries to the calendar as tasks/notes, then marks finalised.
  Future<void> finalisePlan({
    required String planId,
    required String householdId,
    required Map<String, String> entryActions,
  });

  // ═══════════════════════════════════════════════════════════════════
  //  TASK ATTACHMENTS
  // ═══════════════════════════════════════════════════════════════════

  /// Creates a new attachment record for a task.
  Future<TaskAttachment> createAttachment({
    required String taskId,
    required String householdId,
    required String driveFileId,
    required String fileName,
    required String mimeType,
    required int fileSizeBytes,
    String? thumbnailUrl,
    required String webViewLink,
    String? description,
  });

  /// Fetches all attachments for a task.
  Future<List<TaskAttachment>> getTaskAttachments(String taskId);

  /// Deletes an attachment record (does NOT delete the file from Drive).
  Future<void> deleteAttachment(String attachmentId);

  // ═══════════════════════════════════════════════════════════════════
  //  PLAN ATTACHMENTS
  // ═══════════════════════════════════════════════════════════════════

  /// Creates a new attachment record for a plan entry.
  Future<PlanAttachment> createPlanAttachment({
    required String planId,
    required String entryId,
    required String householdId,
    required String driveFileId,
    required String fileName,
    required String mimeType,
    required int fileSizeBytes,
    String? thumbnailUrl,
    required String webViewLink,
    String? description,
  });

  /// Fetches all attachments for a plan entry.
  Future<List<PlanAttachment>> getPlanEntryAttachments(String entryId);

  /// Fetches all attachments for an entire plan (across all entries).
  Future<List<PlanAttachment>> getPlanAttachments(String planId);

  /// Deletes a plan attachment record (does NOT delete the file from Drive).
  Future<void> deletePlanAttachment(String attachmentId);

  // ═══════════════════════════════════════════════════════════════════
  //  INVENTORY
  // ═══════════════════════════════════════════════════════════════════

  /// Creates a new inventory item. Returns the created item.
  Future<InventoryItem> createInventoryItem({
    required String householdId,
    required String name,
    String? description,
    String? categoryId,
    String? locationId,
    int quantity = 0,
    String unit = 'pieces',
    int? lowStockThreshold,
    String? barcode,
    String barcodeType = 'none',
    DateTime? expiryDate,
    DateTime? purchaseDate,
    String? notes,
  });

  /// Fetches all inventory items for a household with optional filters.
  Future<List<InventoryItem>> getInventoryItems({
    required String householdId,
    String? categoryId,
    String? locationId,
    bool? lowStockOnly,
    bool? expiringOnly,
  });

  /// Fetches a single inventory item by ID.
  Future<InventoryItem> getInventoryItem(String itemId);

  /// Updates inventory item fields. Only non-null fields are changed.
  Future<void> updateInventoryItem({
    required String itemId,
    String? name,
    String? description,
    String? categoryId,
    String? locationId,
    int? quantity,
    String? unit,
    int? lowStockThreshold,
    String? barcode,
    String? barcodeType,
    DateTime? expiryDate,
    DateTime? purchaseDate,
    String? notes,
  });

  /// Deletes an inventory item.
  Future<void> deleteInventoryItem(String itemId);

  // ── Inventory Categories ──

  /// Gets all inventory categories for a household.
  Future<List<InventoryCategory>> getInventoryCategories(String householdId);

  /// Creates a new inventory category. Returns the created category.
  Future<InventoryCategory> createInventoryCategory({
    required String householdId,
    required String name,
    String icon = 'inventory_2',
    String color = '#A5B4A5',
  });

  /// Deletes an inventory category.
  Future<void> deleteInventoryCategory(String categoryId);

  // ── Inventory Locations ──

  /// Gets all inventory locations for a household.
  Future<List<InventoryLocation>> getInventoryLocations(String householdId);

  /// Creates a new inventory location. Returns the created location.
  Future<InventoryLocation> createInventoryLocation({
    required String householdId,
    required String name,
    String icon = 'place',
  });

  /// Deletes an inventory location.
  Future<void> deleteInventoryLocation(String locationId);

  // ── Inventory Log ──

  /// Logs an inventory action (add, remove, adjust).
  Future<void> logInventoryAction({
    required String itemId,
    required String householdId,
    required String action,
    required int quantityChange,
    required int quantityAfter,
    String? note,
  });

  /// Gets inventory logs for an item.
  Future<List<InventoryLog>> getInventoryLogs({
    required String itemId,
    required String householdId,
    int limit = 50,
  });

  // ── Inventory Attachments ──

  /// Creates a new attachment record for an inventory item.
  Future<InventoryAttachment> createInventoryAttachment({
    required String itemId,
    required String householdId,
    required String driveFileId,
    required String fileName,
    required String mimeType,
    required int fileSizeBytes,
    String? thumbnailUrl,
    required String webViewLink,
    String? description,
  });

  /// Fetches all attachments for an inventory item.
  Future<List<InventoryAttachment>> getInventoryAttachments(String itemId, {required String householdId});

  /// Deletes an inventory attachment record.
  Future<void> deleteInventoryAttachment(String attachmentId);

  // ── Inventory Stats ──

  /// Gets inventory stats for the home screen summary.
  Future<Map<String, int>> getInventoryStats(String householdId);

  // ═══════════════════════════════════════════════════════════════════
  //  HOUSE MANUAL
  // ═══════════════════════════════════════════════════════════════════

  /// Creates a new manual entry. Returns the created entry.
  Future<ManualEntry> createManualEntry({
    required String householdId,
    required String title,
    String content = '',
    String? categoryId,
    List<String> tags = const [],
    bool isPinned = false,
  });

  /// Fetches all manual entries for a household with optional filters.
  Future<List<ManualEntry>> getManualEntries({
    required String householdId,
    String? categoryId,
    bool? pinnedOnly,
    String? searchQuery,
  });

  /// Fetches a single manual entry by ID.
  Future<ManualEntry> getManualEntry(String entryId);

  /// Updates manual entry fields. Only non-null fields are changed.
  Future<void> updateManualEntry({
    required String entryId,
    String? title,
    String? content,
    String? categoryId,
    List<String>? tags,
    bool? isPinned,
  });

  /// Deletes a manual entry.
  Future<void> deleteManualEntry(String entryId);

  // ── Manual Categories ──

  /// Gets all manual categories for a household.
  Future<List<ManualCategory>> getManualCategories(String householdId);

  /// Creates a new manual category. Returns the created category.
  Future<ManualCategory> createManualCategory({
    required String householdId,
    required String name,
    String icon = 'menu_book',
    String color = '#7EA87E',
  });

  /// Deletes a manual category.
  Future<void> deleteManualCategory(String categoryId);

  // ═══════════════════════════════════════════════════════════════════
  //  SEARCH
  // ═══════════════════════════════════════════════════════════════════

  /// Searches across all entity types within a household.
  ///
  /// Returns matching [SearchResult]s filtered by [entityTypes].
  /// The search is a case-insensitive substring match on titles and
  /// descriptions.
  Future<List<SearchResult>> searchHousehold({
    required String householdId,
    required String query,
    List<String> entityTypes = const ['task', 'checklist', 'plan', 'attachment', 'inventory', 'manual'],
  });

  // ═══════════════════════════════════════════════════════════════════
  //  DATA WIPE
  // ═══════════════════════════════════════════════════════════════════

  /// Permanently deletes ALL user data from this backend.
  ///
  /// This is a destructive, irreversible operation used by the "Burn All
  /// Data" feature. Deletes tasks, subtasks, categories, checklists,
  /// plans, entries, plan checklist items, and inventory data.
  Future<void> wipeAllData(String userId);
}
