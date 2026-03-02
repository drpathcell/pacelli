import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

/// Service for task CRUD operations via Supabase.
class TaskService {
  // ── Tasks ─────────────────────────────────────────────────

  /// Creates a new task in the household.
  static Future<Map<String, dynamic>> createTask({
    required String householdId,
    required String title,
    String? description,
    String? categoryId,
    String priority = 'medium',
    DateTime? dueDate,
    String? assignedTo,
    bool isShared = false,
    String recurrence = 'none',
    List<String>? subtaskTitles,
  }) async {
    final response = await supabase.rpc('create_task', params: {
      'p_household_id': householdId,
      'p_title': title,
      'p_description': description,
      'p_category_id': categoryId,
      'p_priority': priority,
      'p_due_date': dueDate?.toIso8601String(),
      'p_assigned_to': isShared ? null : assignedTo,
      'p_is_shared': isShared,
      'p_recurrence': recurrence,
      'p_subtask_titles': subtaskTitles,
    });
    return Map<String, dynamic>.from(response as Map);
  }

  /// Fetches all tasks for a household with optional filters.
  static Future<List<Map<String, dynamic>>> getTasks({
    required String householdId,
    String? status,
    String? categoryId,
    String? assignedTo,
    String? priority,
    bool? isShared,
  }) async {
    var query = supabase
        .from('tasks')
        .select('''
          *,
          task_categories!category_id(id, name, icon, color),
          assigned:profiles!assigned_to(id, full_name, avatar_url),
          creator:profiles!created_by(id, full_name, avatar_url),
          subtasks(id, title, is_completed, sort_order)
        ''')
        .eq('household_id', householdId);

    if (status != null) query = query.eq('status', status);
    if (categoryId != null) query = query.eq('category_id', categoryId);
    if (assignedTo != null) query = query.eq('assigned_to', assignedTo);
    if (priority != null) query = query.eq('priority', priority);

    final data = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Fetches a single task by ID.
  static Future<Map<String, dynamic>> getTask(String taskId) async {
    return await supabase
        .from('tasks')
        .select('''
          *,
          task_categories!category_id(id, name, icon, color),
          assigned:profiles!assigned_to(id, full_name, avatar_url),
          creator:profiles!created_by(id, full_name, avatar_url),
          subtasks(id, title, is_completed, sort_order)
        ''')
        .eq('id', taskId)
        .single();
  }

  /// Updates a task.
  static Future<void> updateTask({
    required String taskId,
    String? title,
    String? description,
    String? categoryId,
    String? priority,
    String? status,
    DateTime? dueDate,
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
    if (assignedTo != null) updates['assigned_to'] = assignedTo;
    if (isShared != null) updates['is_shared'] = isShared;
    if (recurrence != null) updates['recurrence'] = recurrence;

    if (updates.isEmpty) return;

    await supabase.from('tasks').update(updates).eq('id', taskId);
  }

  /// Mark task as completed.
  static Future<void> completeTask(String taskId) async {
    await supabase.from('tasks').update({
      'status': 'completed',
      'completed_at': DateTime.now().toIso8601String(),
      'completed_by': currentUserId,
    }).eq('id', taskId);
  }

  /// Reopen a completed task.
  static Future<void> reopenTask(String taskId) async {
    await supabase.from('tasks').update({
      'status': 'pending',
      'completed_at': null,
      'completed_by': null,
    }).eq('id', taskId);
  }

  /// Delete a task.
  static Future<void> deleteTask(String taskId) async {
    await supabase.from('tasks').delete().eq('id', taskId);
  }

  // ── Subtasks ──────────────────────────────────────────────

  /// Add a subtask to an existing task.
  static Future<Map<String, dynamic>> addSubtask({
    required String taskId,
    required String title,
    int sortOrder = 0,
  }) async {
    return await supabase
        .from('subtasks')
        .insert({
          'task_id': taskId,
          'title': title,
          'sort_order': sortOrder,
        })
        .select()
        .single();
  }

  /// Toggle subtask completion.
  static Future<void> toggleSubtask({
    required String subtaskId,
    required bool isCompleted,
  }) async {
    await supabase
        .from('subtasks')
        .update({'is_completed': isCompleted})
        .eq('id', subtaskId);
  }

  /// Delete a subtask.
  static Future<void> deleteSubtask(String subtaskId) async {
    await supabase.from('subtasks').delete().eq('id', subtaskId);
  }

  // ── Categories ────────────────────────────────────────────

  /// Get all categories for a household.
  static Future<List<Map<String, dynamic>>> getCategories(
      String householdId) async {
    final data = await supabase
        .from('task_categories')
        .select()
        .eq('household_id', householdId)
        .order('is_default', ascending: false)
        .order('name');
    return List<Map<String, dynamic>>.from(data);
  }

  /// Create a custom category.
  static Future<Map<String, dynamic>> createCategory({
    required String householdId,
    required String name,
    String icon = 'category',
    String color = '#7EA87E',
  }) async {
    return await supabase
        .from('task_categories')
        .insert({
          'household_id': householdId,
          'name': name,
          'icon': icon,
          'color': color,
          'is_default': false,
        })
        .select()
        .single();
  }

  /// Delete a custom category (default categories can't be deleted).
  static Future<void> deleteCategory(String categoryId) async {
    await supabase
        .from('task_categories')
        .delete()
        .eq('id', categoryId)
        .eq('is_default', false);
  }

  // ── Stats ─────────────────────────────────────────────────

  /// Get task counts for the household dashboard.
  static Future<Map<String, int>> getTaskStats(String householdId) async {
    final tasks = await supabase
        .from('tasks')
        .select('status, due_date')
        .eq('household_id', householdId);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int completed = 0;
    int pending = 0;
    int overdue = 0;

    for (final task in tasks) {
      final status = task['status'] as String;
      if (status == 'completed') {
        completed++;
      } else {
        pending++;
        final dueDateStr = task['due_date'] as String?;
        if (dueDateStr != null) {
          final dueDate = DateTime.parse(dueDateStr);
          if (dueDate.isBefore(today)) {
            overdue++;
          }
        }
      }
    }

    return {
      'completed': completed,
      'pending': pending,
      'overdue': overdue,
    };
  }
}
