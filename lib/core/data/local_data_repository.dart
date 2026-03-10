import 'dart:async';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'data_repository.dart';

/// [DataRepository] implementation backed by local SQLite.
///
/// Provides offline-first storage with zero cloud dependency.
/// Real-time subscriptions are simulated via [StreamController]s that
/// emit after local writes.
class LocalDataRepository implements DataRepository {
  final Database _db;
  final String _userId;

  /// UUIDs are generated locally (same pattern as FirebaseDataRepository).
  static const _uuid = Uuid();

  /// Stream controllers for real-time simulation.
  final _entryStreams = <String, StreamController<dynamic>>{};
  final _checklistStreams = <String, StreamController<dynamic>>{};

  LocalDataRepository(this._db, {required String userId}) : _userId = userId;

  // ═══════════════════════════════════════════════════════════════════
  //  TASKS
  // ═══════════════════════════════════════════════════════════════════

  @override
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
  }) async {
    final taskId = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    await _db.insert('tasks', {
      'id': taskId,
      'household_id': householdId,
      'title': title,
      'description': description,
      'category_id': categoryId,
      'priority': priority,
      'status': 'pending',
      'due_date': dueDate?.toIso8601String(),
      'start_date': startDate?.toIso8601String(),
      'assigned_to': isShared ? null : assignedTo,
      'is_shared': isShared ? 1 : 0,
      'recurrence': recurrence,
      'created_by': _userId,
      'created_at': now,
    });

    // Insert subtasks
    if (subtaskTitles != null) {
      for (int i = 0; i < subtaskTitles.length; i++) {
        await _db.insert('subtasks', {
          'id': _uuid.v4(),
          'task_id': taskId,
          'title': subtaskTitles[i],
          'is_completed': 0,
          'sort_order': i,
          'created_at': now,
        });
      }
    }

    return getTask(taskId);
  }

  @override
  Future<List<Task>> getTasks({
    required String householdId,
    String? status,
    String? categoryId,
    String? assignedTo,
    String? priority,
    bool? isShared,
  }) async {
    final where = <String>['t.household_id = ?'];
    final args = <dynamic>[householdId];

    if (status != null) {
      where.add('t.status = ?');
      args.add(status);
    }
    if (categoryId != null) {
      where.add('t.category_id = ?');
      args.add(categoryId);
    }
    if (assignedTo != null) {
      where.add('t.assigned_to = ?');
      args.add(assignedTo);
    }
    if (priority != null) {
      where.add('t.priority = ?');
      args.add(priority);
    }

    final tasks = await _db.rawQuery('''
      SELECT t.*,
             c.id   AS cat_id,
             c.name AS cat_name,
             c.icon AS cat_icon,
             c.color AS cat_color
        FROM tasks t
        LEFT JOIN task_categories c ON t.category_id = c.id
       WHERE ${where.join(' AND ')}
       ORDER BY t.created_at DESC
    ''', args);

    final result = <Task>[];
    for (final row in tasks) {
      final taskId = row['id'] as String;
      final subtasks = await _db.query(
        'subtasks',
        where: 'task_id = ?',
        whereArgs: [taskId],
        orderBy: 'sort_order ASC',
      );

      result.add(_taskFromRow(row, subtasks));
    }
    return result;
  }

  @override
  Future<Task> getTask(String taskId) async {
    final rows = await _db.rawQuery('''
      SELECT t.*,
             c.id   AS cat_id,
             c.name AS cat_name,
             c.icon AS cat_icon,
             c.color AS cat_color
        FROM tasks t
        LEFT JOIN task_categories c ON t.category_id = c.id
       WHERE t.id = ?
    ''', [taskId]);

    if (rows.isEmpty) throw Exception('Task $taskId not found');

    final subtasks = await _db.query(
      'subtasks',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'sort_order ASC',
    );

    return _taskFromRow(rows.first, subtasks);
  }

  @override
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
  }) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (categoryId != null) updates['category_id'] = categoryId;
    if (priority != null) updates['priority'] = priority;
    if (status != null) updates['status'] = status;
    if (dueDate != null) updates['due_date'] = dueDate.toIso8601String();
    if (startDate != null) updates['start_date'] = startDate.toIso8601String();
    if (assignedTo != null) updates['assigned_to'] = assignedTo;
    if (isShared != null) updates['is_shared'] = isShared ? 1 : 0;
    if (recurrence != null) updates['recurrence'] = recurrence;

    if (updates.isEmpty) return;

    await _db.update('tasks', updates, where: 'id = ?', whereArgs: [taskId]);
  }

  @override
  Future<void> completeTask(String taskId) async {
    await _db.update(
      'tasks',
      {
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
        'completed_by': _userId,
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  @override
  Future<void> reopenTask(String taskId) async {
    await _db.update(
      'tasks',
      {
        'status': 'pending',
        'completed_at': null,
        'completed_by': null,
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await _db.delete('tasks', where: 'id = ?', whereArgs: [taskId]);
  }

  // ── Subtasks ──

  @override
  Future<Subtask> addSubtask({
    required String taskId,
    required String title,
    int sortOrder = 0,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    await _db.insert('subtasks', {
      'id': id,
      'task_id': taskId,
      'title': title,
      'is_completed': 0,
      'sort_order': sortOrder,
      'created_at': now,
    });

    return Subtask(
      id: id,
      taskId: taskId,
      title: title,
      isCompleted: false,
      sortOrder: sortOrder,
    );
  }

  @override
  Future<void> toggleSubtask({
    required String subtaskId,
    required bool isCompleted,
  }) async {
    await _db.update(
      'subtasks',
      {'is_completed': isCompleted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [subtaskId],
    );
  }

  @override
  Future<void> deleteSubtask(String subtaskId) async {
    await _db.delete('subtasks', where: 'id = ?', whereArgs: [subtaskId]);
  }

  // ── Categories ──

  @override
  Future<List<TaskCategory>> getCategories(String householdId) async {
    final rows = await _db.query(
      'task_categories',
      where: 'household_id = ?',
      whereArgs: [householdId],
      orderBy: 'is_default DESC, name ASC',
    );
    return rows.map((r) => TaskCategory.fromMap(_sqliteToMap(r))).toList();
  }

  @override
  Future<TaskCategory> createCategory({
    required String householdId,
    required String name,
    String icon = 'category',
    String color = '#7EA87E',
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    final map = {
      'id': id,
      'household_id': householdId,
      'name': name,
      'icon': icon,
      'color': color,
      'is_default': 0,
      'created_at': now,
    };

    await _db.insert('task_categories', map);
    return TaskCategory.fromMap({...map, 'is_default': false});
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    await _db.delete(
      'task_categories',
      where: 'id = ? AND is_default = 0',
      whereArgs: [categoryId],
    );
  }

  // ── Stats ──

  @override
  Future<TaskStats> getTaskStats(String householdId) async {
    final rows = await _db.query(
      'tasks',
      columns: ['status', 'due_date'],
      where: 'household_id = ?',
      whereArgs: [householdId],
    );

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int completed = 0, pending = 0, overdue = 0;

    for (final row in rows) {
      final status = row['status'] as String;
      if (status == 'completed') {
        completed++;
      } else {
        pending++;
        final dueDateStr = row['due_date'] as String?;
        if (dueDateStr != null) {
          final dueDate = DateTime.parse(dueDateStr);
          if (dueDate.isBefore(today)) overdue++;
        }
      }
    }

    return TaskStats(completed: completed, pending: pending, overdue: overdue);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  CHECKLISTS (standalone)
  // ═══════════════════════════════════════════════════════════════════

  @override
  Future<Checklist> createChecklist({
    required String householdId,
    required String title,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    await _db.insert('checklists', {
      'id': id,
      'household_id': householdId,
      'title': title,
      'created_by': _userId,
      'created_at': now,
    });

    return Checklist(
      id: id,
      householdId: householdId,
      title: title,
      createdBy: _userId,
      createdAt: DateTime.parse(now),
      items: [],
    );
  }

  @override
  Future<List<Checklist>> getChecklists(String householdId) async {
    final rows = await _db.query(
      'checklists',
      where: 'household_id = ?',
      whereArgs: [householdId],
      orderBy: 'created_at DESC',
    );

    final result = <Checklist>[];
    for (final row in rows) {
      final items = await _db.query(
        'checklist_items',
        where: 'checklist_id = ?',
        whereArgs: [row['id']],
      );
      result.add(Checklist.fromMap({
        ..._sqliteToMap(row),
        'checklist_items': items.map(_sqliteToMap).toList(),
      }));
    }
    return result;
  }

  @override
  Future<void> updateChecklist(String checklistId, String title) async {
    await _db.update(
      'checklists',
      {'title': title, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [checklistId],
    );
  }

  @override
  Future<void> deleteChecklist(String checklistId) async {
    await _db.delete('checklists', where: 'id = ?', whereArgs: [checklistId]);
  }

  @override
  Future<ChecklistItem> addChecklistItem({
    required String checklistId,
    required String title,
    String? quantity,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    await _db.insert('checklist_items', {
      'id': id,
      'checklist_id': checklistId,
      'title': title,
      'quantity': quantity,
      'is_checked': 0,
      'created_by': _userId,
      'created_at': now,
    });

    return ChecklistItem(
      id: id,
      checklistId: checklistId,
      title: title,
      quantity: quantity,
      isChecked: false,
    );
  }

  @override
  Future<void> toggleChecklistItem(String itemId, bool isChecked) async {
    await _db.update(
      'checklist_items',
      {
        'is_checked': isChecked ? 1 : 0,
        'checked_at': isChecked ? DateTime.now().toIso8601String() : null,
        'checked_by': isChecked ? _userId : null,
      },
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  @override
  Future<void> deleteChecklistItem(String itemId) async {
    await _db.delete('checklist_items', where: 'id = ?', whereArgs: [itemId]);
  }

  @override
  Future<void> pushChecklistItemAsTask({
    required String householdId,
    required String itemTitle,
    required String itemId,
  }) async {
    final now = DateTime.now();
    await createTask(
      householdId: householdId,
      title: itemTitle,
      priority: 'medium',
      dueDate: now,
      startDate: now,
      isShared: true,
      recurrence: 'none',
    );
    await deleteChecklistItem(itemId);
  }

  @override
  Future<void> pushPlanChecklistItemAsTask({
    required String householdId,
    required String itemTitle,
    required String itemId,
  }) async {
    final now = DateTime.now();
    await createTask(
      householdId: householdId,
      title: itemTitle,
      priority: 'medium',
      dueDate: now,
      startDate: now,
      isShared: true,
      recurrence: 'none',
    );
    await _db.delete('plan_checklist_items',
        where: 'id = ?', whereArgs: [itemId]);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  PLANS (scratch plans)
  // ═══════════════════════════════════════════════════════════════════

  @override
  Future<Plan> createPlan({
    required String householdId,
    required String title,
    String type = 'weekly',
    required DateTime startDate,
    required DateTime endDate,
    bool isTemplate = false,
    String? templateName,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    await _db.insert('scratch_plans', {
      'id': id,
      'household_id': householdId,
      'title': title,
      'type': type,
      'status': 'draft',
      'start_date': _dateOnly(startDate),
      'end_date': _dateOnly(endDate),
      'is_template': isTemplate ? 1 : 0,
      'template_name': templateName,
      'created_by': _userId,
      'created_at': now,
    });

    return Plan(
      id: id,
      householdId: householdId,
      title: title,
      type: type,
      status: 'draft',
      startDate: startDate,
      endDate: endDate,
      isTemplate: isTemplate,
      templateName: templateName,
      createdBy: _userId,
      createdAt: DateTime.parse(now),
      entries: [],
      checklistItems: [],
    );
  }

  @override
  Future<List<Plan>> getPlans(String householdId) async {
    final rows = await _db.query(
      'scratch_plans',
      where: 'household_id = ? AND is_template = 0',
      whereArgs: [householdId],
      orderBy: 'created_at DESC',
    );

    final result = <Plan>[];
    for (final row in rows) {
      final planId = row['id'] as String;
      final entries = await _db.query(
        'plan_entries',
        columns: ['id', 'entry_date', 'title', 'label', 'sort_order'],
        where: 'plan_id = ?',
        whereArgs: [planId],
      );
      final checklistItems = await _db.query(
        'plan_checklist_items',
        columns: ['id', 'title', 'quantity', 'is_checked'],
        where: 'plan_id = ?',
        whereArgs: [planId],
      );

      result.add(Plan.fromMap({
        ..._sqliteToMap(row),
        'plan_entries': entries.map(_sqliteToMap).toList(),
        'plan_checklist_items': checklistItems.map(_sqliteToMap).toList(),
      }));
    }
    return result;
  }

  @override
  Future<Plan> getPlan(String planId) async {
    final rows = await _db.query(
      'scratch_plans',
      where: 'id = ?',
      whereArgs: [planId],
    );
    if (rows.isEmpty) throw Exception('Plan $planId not found');

    final entries = await _db.query(
      'plan_entries',
      where: 'plan_id = ?',
      whereArgs: [planId],
    );
    final checklistItems = await _db.query(
      'plan_checklist_items',
      where: 'plan_id = ?',
      whereArgs: [planId],
    );

    return Plan.fromMap({
      ..._sqliteToMap(rows.first),
      'plan_entries': entries.map(_sqliteToMap).toList(),
      'plan_checklist_items': checklistItems.map(_sqliteToMap).toList(),
    });
  }

  @override
  Future<void> deletePlan(String planId) async {
    await _db.delete('scratch_plans', where: 'id = ?', whereArgs: [planId]);
  }

  @override
  Future<void> updatePlanStatus(String planId, String status) async {
    await _db.update(
      'scratch_plans',
      {'status': status, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [planId],
    );
  }

  // ── Plan Entries ──

  @override
  Future<PlanEntry> addEntry({
    required String planId,
    required DateTime entryDate,
    required String title,
    String? label,
    String? description,
    int sortOrder = 0,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    await _db.insert('plan_entries', {
      'id': id,
      'plan_id': planId,
      'entry_date': _dateOnly(entryDate),
      'title': title,
      'label': label,
      'description': description,
      'sort_order': sortOrder,
      'created_by': _userId,
      'created_at': now,
    });

    final entry = PlanEntry(
      id: id,
      planId: planId,
      entryDate: entryDate,
      title: title,
      label: label,
      description: description,
      sortOrder: sortOrder,
    );

    _notifyEntryChange(planId);
    return entry;
  }

  @override
  Future<void> updateEntry({
    required String entryId,
    String? title,
    String? label,
    String? description,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (title != null) updates['title'] = title;
    if (label != null) updates['label'] = label;
    if (description != null) updates['description'] = description;

    await _db.update('plan_entries', updates,
        where: 'id = ?', whereArgs: [entryId]);

    // Get the plan ID for stream notification
    final rows = await _db.query('plan_entries',
        columns: ['plan_id'], where: 'id = ?', whereArgs: [entryId]);
    if (rows.isNotEmpty) {
      _notifyEntryChange(rows.first['plan_id'] as String);
    }
  }

  @override
  Future<void> deleteEntry(String entryId) async {
    // Get plan ID before deleting
    final rows = await _db.query('plan_entries',
        columns: ['plan_id'], where: 'id = ?', whereArgs: [entryId]);

    await _db.delete('plan_entries', where: 'id = ?', whereArgs: [entryId]);

    if (rows.isNotEmpty) {
      _notifyEntryChange(rows.first['plan_id'] as String);
    }
  }

  // ── Plan Checklist Items ──

  @override
  Future<PlanChecklistItem> addPlanChecklistItem({
    required String planId,
    String? entryId,
    required String title,
    String? quantity,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    await _db.insert('plan_checklist_items', {
      'id': id,
      'plan_id': planId,
      'entry_id': entryId,
      'title': title,
      'quantity': quantity,
      'is_checked': 0,
      'created_by': _userId,
      'created_at': now,
    });

    final item = PlanChecklistItem(
      id: id,
      planId: planId,
      entryId: entryId,
      title: title,
      quantity: quantity,
      isChecked: false,
    );

    _notifyChecklistChange(planId);
    return item;
  }

  @override
  Future<void> togglePlanChecklistItem(String itemId, bool isChecked) async {
    await _db.update(
      'plan_checklist_items',
      {
        'is_checked': isChecked ? 1 : 0,
        'checked_at': isChecked ? DateTime.now().toIso8601String() : null,
        'checked_by': isChecked ? _userId : null,
      },
      where: 'id = ?',
      whereArgs: [itemId],
    );

    // Get plan ID for stream notification
    final rows = await _db.query('plan_checklist_items',
        columns: ['plan_id'], where: 'id = ?', whereArgs: [itemId]);
    if (rows.isNotEmpty) {
      _notifyChecklistChange(rows.first['plan_id'] as String);
    }
  }

  @override
  Future<void> deletePlanChecklistItem(String itemId) async {
    final rows = await _db.query('plan_checklist_items',
        columns: ['plan_id'], where: 'id = ?', whereArgs: [itemId]);

    await _db.delete('plan_checklist_items',
        where: 'id = ?', whereArgs: [itemId]);

    if (rows.isNotEmpty) {
      _notifyChecklistChange(rows.first['plan_id'] as String);
    }
  }

  // ── Templates ──

  @override
  Future<List<Plan>> getTemplates(String householdId) async {
    final rows = await _db.query(
      'scratch_plans',
      where: 'household_id = ? AND is_template = 1',
      whereArgs: [householdId],
      orderBy: 'created_at DESC',
    );

    final result = <Plan>[];
    for (final row in rows) {
      final planId = row['id'] as String;
      final entries = await _db.query(
        'plan_entries',
        columns: ['id', 'entry_date', 'title', 'label', 'sort_order'],
        where: 'plan_id = ?',
        whereArgs: [planId],
      );

      result.add(Plan.fromMap({
        ..._sqliteToMap(row),
        'plan_entries': entries.map(_sqliteToMap).toList(),
        'plan_checklist_items': [],
      }));
    }
    return result;
  }

  @override
  Future<Plan> savePlanAsTemplate({
    required String planId,
    required String templateName,
    required String householdId,
  }) async {
    final source = await getPlan(planId);

    final template = await createPlan(
      householdId: householdId,
      title: templateName,
      type: source.type,
      startDate: source.startDate,
      endDate: source.endDate,
      isTemplate: true,
      templateName: templateName,
    );

    for (final entry in source.entries) {
      await addEntry(
        planId: template.id,
        entryDate: entry.entryDate,
        title: entry.title,
        label: entry.label,
        sortOrder: entry.sortOrder,
      );
    }

    return getPlan(template.id);
  }

  @override
  Future<Plan> createFromTemplate({
    required String templateId,
    required String householdId,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final template = await getPlan(templateId);
    final templateStart = template.startDate;

    final newPlan = await createPlan(
      householdId: householdId,
      title: title,
      type: template.type,
      startDate: startDate,
      endDate: endDate,
    );

    for (final entry in template.entries) {
      final offset = entry.entryDate.difference(templateStart);
      final newDate = startDate.add(offset);

      if (!newDate.isAfter(endDate)) {
        await addEntry(
          planId: newPlan.id,
          entryDate: newDate,
          title: entry.title,
          label: entry.label,
          sortOrder: entry.sortOrder,
        );
      }
    }

    return getPlan(newPlan.id);
  }

  // ── Realtime (simulated) ──

  @override
  dynamic subscribeToEntries(
    String planId, {
    required void Function(dynamic payload) onEvent,
  }) {
    final controller = StreamController<dynamic>.broadcast();
    _entryStreams[planId] = controller;
    controller.stream.listen(onEvent);
    return controller; // Caller can close it like a RealtimeChannel.unsubscribe()
  }

  @override
  dynamic subscribeToChecklist(
    String planId, {
    required void Function(dynamic payload) onEvent,
  }) {
    final controller = StreamController<dynamic>.broadcast();
    _checklistStreams[planId] = controller;
    controller.stream.listen(onEvent);
    return controller;
  }

  // ── Finalise ──

  @override
  Future<void> finalisePlan({
    required String planId,
    required String householdId,
    required Map<String, String> entryActions,
  }) async {
    final plan = await getPlan(planId);

    for (final entry in plan.entries) {
      final action = entryActions[entry.id];
      if (action == null) continue;

      final title = entry.label != null
          ? '${entry.label}: ${entry.title}'
          : entry.title;

      final entryDate = entry.entryDate;
      final priorityForAction = action == 'note' ? 'low' : 'medium';
      final descForAction = action == 'note'
          ? '[Plan Note] ${entry.description ?? ''}'
          : entry.description;

      await createTask(
        householdId: householdId,
        title: title,
        description: descForAction,
        priority: priorityForAction,
        dueDate: entryDate,
        startDate: entryDate,
        isShared: true,
        recurrence: 'none',
      );
    }

    await updatePlanStatus(planId, 'finalised');
  }

  // ═══════════════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════════════

  /// Converts SQLite integer booleans (0/1) to Dart booleans for fromMap().
  static Map<String, dynamic> _sqliteToMap(Map<String, dynamic> row) {
    final m = Map<String, dynamic>.from(row);
    // Convert known boolean fields
    for (final key in [
      'is_completed',
      'is_checked',
      'is_shared',
      'is_template',
      'is_default',
    ]) {
      if (m.containsKey(key) && m[key] is int) {
        m[key] = m[key] == 1;
      }
    }
    return m;
  }

  /// Builds a [Task] from a raw SQL row (with joined category columns)
  /// and a list of subtask rows.
  Task _taskFromRow(
    Map<String, dynamic> row,
    List<Map<String, dynamic>> subtaskRows,
  ) {
    final m = _sqliteToMap(row);

    // Re-nest the category as the model's fromMap expects.
    final catId = m.remove('cat_id');
    final catName = m.remove('cat_name');
    final catIcon = m.remove('cat_icon');
    final catColor = m.remove('cat_color');
    if (catId != null) {
      m['task_categories'] = {
        'id': catId,
        'name': catName,
        'icon': catIcon,
        'color': catColor,
      };
    }

    // Profile lookups would come from profile_cache (Phase 5).
    // For now we leave assigned/creator as null maps.
    m['assigned'] = null;
    m['creator'] = null;

    m['subtasks'] = subtaskRows.map(_sqliteToMap).toList();

    return Task.fromMap(m);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  TASK ATTACHMENTS
  // ═══════════════════════════════════════════════════════════════════

  @override
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
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    final row = {
      'id': id,
      'task_id': taskId,
      'household_id': householdId,
      'drive_file_id': driveFileId,
      'file_name': fileName,
      'mime_type': mimeType,
      'file_size_bytes': fileSizeBytes,
      'thumbnail_url': thumbnailUrl,
      'web_view_link': webViewLink,
      'uploaded_by': 'local_user',
      'uploaded_at': now.toIso8601String(),
      'description': description,
    };

    await _db.insert('task_attachments', row);

    return TaskAttachment(
      id: id,
      taskId: taskId,
      householdId: householdId,
      driveFileId: driveFileId,
      fileName: fileName,
      mimeType: mimeType,
      fileSizeBytes: fileSizeBytes,
      thumbnailUrl: thumbnailUrl,
      webViewLink: webViewLink,
      uploadedBy: 'local_user',
      uploadedAt: now,
      description: description,
    );
  }

  @override
  Future<List<TaskAttachment>> getTaskAttachments(String taskId) async {
    final rows = await _db.query(
      'task_attachments',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'uploaded_at ASC',
    );
    return rows.map((r) => TaskAttachment.fromMap(r)).toList();
  }

  @override
  Future<void> deleteAttachment(String attachmentId) async {
    await _db.delete(
      'task_attachments',
      where: 'id = ?',
      whereArgs: [attachmentId],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  PLAN ATTACHMENTS
  // ═══════════════════════════════════════════════════════════════════

  @override
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
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    await _db.insert('plan_attachments', {
      'id': id,
      'plan_id': planId,
      'entry_id': entryId,
      'household_id': householdId,
      'drive_file_id': driveFileId,
      'file_name': fileName,
      'mime_type': mimeType,
      'file_size_bytes': fileSizeBytes,
      'thumbnail_url': thumbnailUrl,
      'web_view_link': webViewLink,
      'uploaded_by': 'local_user',
      'uploaded_at': now.toIso8601String(),
      'description': description,
    });

    return PlanAttachment(
      id: id,
      planId: planId,
      entryId: entryId,
      householdId: householdId,
      driveFileId: driveFileId,
      fileName: fileName,
      mimeType: mimeType,
      fileSizeBytes: fileSizeBytes,
      thumbnailUrl: thumbnailUrl,
      webViewLink: webViewLink,
      uploadedBy: 'local_user',
      uploadedAt: now,
      description: description,
    );
  }

  @override
  Future<List<PlanAttachment>> getPlanEntryAttachments(String entryId) async {
    final rows = await _db.query(
      'plan_attachments',
      where: 'entry_id = ?',
      whereArgs: [entryId],
      orderBy: 'uploaded_at ASC',
    );
    return rows.map((r) => PlanAttachment.fromMap(r)).toList();
  }

  @override
  Future<List<PlanAttachment>> getPlanAttachments(String planId) async {
    final rows = await _db.query(
      'plan_attachments',
      where: 'plan_id = ?',
      whereArgs: [planId],
      orderBy: 'uploaded_at ASC',
    );
    return rows.map((r) => PlanAttachment.fromMap(r)).toList();
  }

  @override
  Future<void> deletePlanAttachment(String attachmentId) async {
    await _db.delete(
      'plan_attachments',
      where: 'id = ?',
      whereArgs: [attachmentId],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  SEARCH
  // ═══════════════════════════════════════════════════════════════════

  @override
  Future<List<SearchResult>> searchHousehold({
    required String householdId,
    required String query,
    List<String> entityTypes = const ['task', 'checklist', 'plan', 'attachment'],
  }) async {
    final results = <SearchResult>[];
    final like = '%$query%';

    // ── Tasks ──
    if (entityTypes.contains('task')) {
      final rows = await _db.query(
        'tasks',
        where:
            "household_id = ? AND (title LIKE ? COLLATE NOCASE OR description LIKE ? COLLATE NOCASE)",
        whereArgs: [householdId, like, like],
        orderBy: 'created_at DESC',
        limit: 200,
      );
      for (final r in rows) {
        results.add(SearchResult(
          id: r['id'] as String,
          entityType: 'task',
          householdId: householdId,
          title: r['title'] as String,
          subtitle: r['description'] as String?,
          relevanceDate: r['due_date'] != null
              ? DateTime.tryParse(r['due_date'] as String)
              : DateTime.tryParse(r['created_at'] as String),
        ));
      }
    }

    // ── Checklists + items ──
    if (entityTypes.contains('checklist')) {
      final clRows = await _db.query(
        'checklists',
        where: "household_id = ? AND title LIKE ? COLLATE NOCASE",
        whereArgs: [householdId, like],
        orderBy: 'created_at DESC',
        limit: 200,
      );
      final clNames = <String, String>{};
      for (final r in clRows) {
        final id = r['id'] as String;
        final title = r['title'] as String;
        clNames[id] = title;
        results.add(SearchResult(
          id: id,
          entityType: 'checklist',
          householdId: householdId,
          title: title,
          relevanceDate: DateTime.tryParse(r['created_at'] as String? ?? ''),
        ));
      }

      // Also search checklist items.
      final itemRows = await _db.rawQuery(
        '''SELECT ci.*, c.title AS checklist_title, c.household_id
           FROM checklist_items ci
           JOIN checklists c ON c.id = ci.checklist_id
           WHERE c.household_id = ? AND ci.title LIKE ? COLLATE NOCASE
           LIMIT 500''',
        [householdId, like],
      );
      for (final r in itemRows) {
        results.add(SearchResult(
          id: r['id'] as String,
          entityType: 'checklist',
          householdId: householdId,
          title: r['title'] as String,
          subtitle: r['checklist_title'] as String?,
          parentId: r['checklist_id'] as String?,
          relevanceDate: DateTime.tryParse(r['created_at'] as String? ?? ''),
        ));
      }
    }

    // ── Plans + entries ──
    if (entityTypes.contains('plan')) {
      final planRows = await _db.query(
        'scratch_plans',
        where:
            "household_id = ? AND is_template = 0 AND title LIKE ? COLLATE NOCASE",
        whereArgs: [householdId, like],
        orderBy: 'start_date DESC',
        limit: 200,
      );
      for (final r in planRows) {
        results.add(SearchResult(
          id: r['id'] as String,
          entityType: 'plan',
          householdId: householdId,
          title: r['title'] as String,
          relevanceDate: DateTime.tryParse(r['start_date'] as String? ?? ''),
        ));
      }

      final entryRows = await _db.rawQuery(
        '''SELECT pe.*, sp.title AS plan_title
           FROM plan_entries pe
           JOIN scratch_plans sp ON sp.id = pe.plan_id
           WHERE sp.household_id = ?
             AND sp.is_template = 0
             AND (pe.title LIKE ? COLLATE NOCASE OR pe.description LIKE ? COLLATE NOCASE)
           LIMIT 500''',
        [householdId, like, like],
      );
      for (final r in entryRows) {
        results.add(SearchResult(
          id: r['id'] as String,
          entityType: 'plan',
          householdId: householdId,
          title: r['title'] as String,
          subtitle: r['plan_title'] as String?,
          parentId: r['plan_id'] as String?,
          relevanceDate: DateTime.tryParse(r['entry_date'] as String? ?? ''),
        ));
      }
    }

    // ── Attachments (task + plan) ──
    if (entityTypes.contains('attachment')) {
      final taskAttRows = await _db.query(
        'task_attachments',
        where:
            "household_id = ? AND (file_name LIKE ? COLLATE NOCASE OR description LIKE ? COLLATE NOCASE)",
        whereArgs: [householdId, like, like],
        limit: 200,
      );
      for (final r in taskAttRows) {
        results.add(SearchResult(
          id: r['id'] as String,
          entityType: 'attachment',
          householdId: householdId,
          title: r['file_name'] as String,
          subtitle: r['description'] as String?,
          parentId: r['task_id'] as String?,
          metadata: const {'source': 'task'},
          relevanceDate: DateTime.tryParse(r['created_at'] as String? ?? ''),
        ));
      }

      final planAttRows = await _db.query(
        'plan_attachments',
        where:
            "household_id = ? AND (file_name LIKE ? COLLATE NOCASE OR description LIKE ? COLLATE NOCASE)",
        whereArgs: [householdId, like, like],
        limit: 200,
      );
      for (final r in planAttRows) {
        results.add(SearchResult(
          id: r['id'] as String,
          entityType: 'attachment',
          householdId: householdId,
          title: r['file_name'] as String,
          subtitle: r['description'] as String?,
          parentId: r['plan_id'] as String?,
          metadata: const {'source': 'plan'},
          relevanceDate: DateTime.tryParse(r['created_at'] as String? ?? ''),
        ));
      }
    }

    return results;
  }

  // ═══════════════════════════════════════════════════════════════════
  //  DATA WIPE
  // ═══════════════════════════════════════════════════════════════════

  @override
  Future<void> wipeAllData(String userId) async {
    // For local SQLite, just drop all rows from every table.
    // Order: children before parents to respect FK constraints.
    await _db.delete('task_attachments');
    await _db.delete('plan_attachments');
    await _db.delete('subtasks');
    await _db.delete('plan_checklist_items');
    await _db.delete('plan_entries');
    await _db.delete('checklist_items');
    await _db.delete('tasks');
    await _db.delete('checklists');
    await _db.delete('scratch_plans');
    await _db.delete('task_categories');
  }

  static String _dateOnly(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// Notifies any active entry stream listeners for a given plan.
  void _notifyEntryChange(String planId) {
    _entryStreams[planId]?.add({'event': 'local_change', 'plan_id': planId});
  }

  /// Notifies any active checklist stream listeners for a given plan.
  void _notifyChecklistChange(String planId) {
    _checklistStreams[planId]
        ?.add({'event': 'local_change', 'plan_id': planId});
  }
}
