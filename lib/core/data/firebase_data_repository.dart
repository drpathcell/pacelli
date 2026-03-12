import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../crypto/encryption_service.dart';
import '../crypto/key_manager.dart';
import '../models/models.dart';
import 'data_repository.dart';

/// [DataRepository] implementation backed by Cloud Firestore with end-to-end
/// encryption for all human-readable content fields.
///
/// **Encrypted**: titles, descriptions, names, labels (anything personal).
/// **Unencrypted**: IDs, status, priority, timestamps, booleans, sort orders.
///
/// Requires a [KeyManager] to access the household encryption key.
class FirebaseDataRepository implements DataRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final KeyManager _keyManager;
  static const _uuid = Uuid();

  FirebaseDataRepository({
    required KeyManager keyManager,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _keyManager = keyManager,
        _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Current authenticated user's UID.
  String? get _uid => _auth.currentUser?.uid;

  /// The decrypted household key, or null if not loaded yet.
  String? get _key => _keyManager.householdKey;

  // ── Encryption helpers ──

  String _enc(String plaintext) =>
      _key != null ? EncryptionService.encrypt(plaintext, _key!) : plaintext;

  /// Decrypts a non-null ciphertext.
  ///
  /// If decryption fails (e.g. the value is already plaintext), returns the
  /// original string rather than a placeholder.
  String _dec(String ciphertext) {
    if (_key == null) return ciphertext;
    try {
      return EncryptionService.decrypt(ciphertext, _key!);
    } catch (e) {
      debugPrint('[FirebaseDataRepository] _dec failed (returning as-is): $e');
      return ciphertext;
    }
  }

  String? _encN(String? plaintext) =>
      _key != null ? EncryptionService.encryptNullable(plaintext, _key!) : plaintext;

  /// Decrypts a nullable ciphertext.
  ///
  /// If decryption fails (e.g. the value is already plaintext), returns the
  /// original string rather than a placeholder.
  String? _decN(String? ciphertext) {
    if (_key == null || ciphertext == null || ciphertext.isEmpty) {
      return ciphertext;
    }
    try {
      return EncryptionService.decrypt(ciphertext, _key!);
    } catch (e) {
      debugPrint('[FirebaseDataRepository] _decN failed (returning as-is): $e');
      return ciphertext;
    }
  }

  // ── Firestore timestamp helpers ──

  static String _dateOnly(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  // ignore: unused_element
  static String? _tsToIso(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is String) return value;
    return null;
  }

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
    final now = DateTime.now();
    final batch = _db.batch();

    // Task document (encrypt title + description).
    batch.set(_db.collection('tasks').doc(taskId), {
      'id': taskId,
      'household_id': householdId,
      'title': _enc(title),
      'description': _encN(description),
      'category_id': categoryId,
      'priority': priority,
      'status': 'pending',
      'due_date': dueDate?.toIso8601String(),
      'start_date': startDate?.toIso8601String(),
      'assigned_to': isShared ? null : assignedTo,
      'is_shared': isShared,
      'recurrence': recurrence,
      'created_by': _uid,
      'created_at': now.toIso8601String(),
      'completed_at': null,
      'completed_by': null,
    });

    // Subtask documents (encrypt titles).
    if (subtaskTitles != null) {
      for (var i = 0; i < subtaskTitles.length; i++) {
        final sid = _uuid.v4();
        batch.set(_db.collection('subtasks').doc(sid), {
          'id': sid,
          'task_id': taskId,
          'household_id': householdId,
          'title': _enc(subtaskTitles[i]),
          'is_completed': false,
          'sort_order': i,
        });
      }
    }

    await batch.commit();
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
    try {
      Query<Map<String, dynamic>> query = _db
          .collection('tasks')
          .where('household_id', isEqualTo: householdId);

      if (status != null) query = query.where('status', isEqualTo: status);
      if (categoryId != null) {
        query = query.where('category_id', isEqualTo: categoryId);
      }
      if (assignedTo != null) {
        query = query.where('assigned_to', isEqualTo: assignedTo);
      }
      if (priority != null) {
        query = query.where('priority', isEqualTo: priority);
      }

      // Limit results per query to avoid excessive reads.
      final snapshot = await query
          .orderBy('created_at', descending: true)
          .limit(200)
          .get();

      if (snapshot.docs.isEmpty) return [];

      // Collect task IDs for subtask query.
      final taskIds = snapshot.docs.map((d) => d.id).toList();

      // Bulk fetch subtasks, categories, and profiles — each wrapped in
      // try-catch so a single failure doesn't crash the whole task list.
      Map<String, List<Subtask>> allSubtasks;
      try {
        allSubtasks = await _getSubtasksForTasks(taskIds);
      } catch (e) {
        debugPrint('[FirebaseDataRepository] getTasks: subtask fetch failed: $e');
        allSubtasks = {};
      }

      final categoryIds = <String>{};
      final profileIds = <String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['category_id'] != null) categoryIds.add(data['category_id']);
        if (data['assigned_to'] != null) profileIds.add(data['assigned_to']);
        if (data['created_by'] != null) profileIds.add(data['created_by']);
      }

      Map<String, TaskCategory> categories;
      try {
        categories = await _getCategoriesByIds(categoryIds);
      } catch (e) {
        debugPrint('[FirebaseDataRepository] getTasks: category fetch failed: $e');
        categories = {};
      }

      Map<String, ProfileRef> profiles;
      try {
        profiles = await _getProfilesByIds(profileIds);
      } catch (e) {
        debugPrint('[FirebaseDataRepository] getTasks: profile fetch failed: $e');
        profiles = {};
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return _taskFromFirestore(data, allSubtasks, categories, profiles);
      }).toList();
    } catch (e) {
      debugPrint('[FirebaseDataRepository] getTasks failed: $e');
      rethrow;
    }
  }

  @override
  Future<Task> getTask(String taskId) async {
    final doc = await _db.collection('tasks').doc(taskId).get();
    if (!doc.exists) throw StateError('Task $taskId not found');
    final data = doc.data()!;

    final subtaskSnap = await _db
        .collection('subtasks')
        .where('task_id', isEqualTo: taskId)
        .orderBy('sort_order')
        .get();
    final subtasks = subtaskSnap.docs
        .map((d) => _subtaskFromFirestore(d.data()))
        .toList();

    TaskCategory? category;
    if (data['category_id'] != null) {
      final catDoc = await _db
          .collection('task_categories')
          .doc(data['category_id'])
          .get();
      if (catDoc.exists) category = _categoryFromFirestore(catDoc.data()!);
    }

    ProfileRef? assignedProfile;
    if (data['assigned_to'] != null) {
      assignedProfile = await _getProfile(data['assigned_to']);
    }
    ProfileRef? creatorProfile;
    if (data['created_by'] != null) {
      creatorProfile = await _getProfile(data['created_by']);
    }

    return Task(
      id: data['id'] as String? ?? taskId,
      householdId: data['household_id'] as String? ?? '',
      title: _dec(data['title'] as String? ?? ''),
      description: _decN(data['description'] as String?),
      categoryId: data['category_id'] as String?,
      priority: data['priority'] as String? ?? 'medium',
      status: data['status'] as String? ?? 'pending',
      dueDate: _parseDate(data['due_date']),
      startDate: _parseDate(data['start_date']),
      assignedTo: data['assigned_to'] as String?,
      isShared: data['is_shared'] as bool? ?? false,
      recurrence: data['recurrence'] as String? ?? 'none',
      createdBy: data['created_by'] as String? ?? '',
      createdAt: _parseDate(data['created_at']) ?? DateTime.now(),
      completedAt: _parseDate(data['completed_at']),
      completedBy: data['completed_by'] as String?,
      category: category,
      assignedProfile: assignedProfile,
      creatorProfile: creatorProfile,
      subtasks: subtasks,
    );
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
    if (title != null) updates['title'] = _enc(title);
    if (description != null) updates['description'] = _enc(description);
    if (categoryId != null) updates['category_id'] = categoryId;
    if (priority != null) updates['priority'] = priority;
    if (status != null) updates['status'] = status;
    if (dueDate != null) updates['due_date'] = dueDate.toIso8601String();
    if (startDate != null) updates['start_date'] = startDate.toIso8601String();
    if (assignedTo != null) updates['assigned_to'] = assignedTo;
    if (isShared != null) updates['is_shared'] = isShared;
    if (recurrence != null) updates['recurrence'] = recurrence;

    if (updates.isEmpty) return;
    await _db.collection('tasks').doc(taskId).update(updates);
  }

  @override
  Future<void> completeTask(String taskId) async {
    await _db.collection('tasks').doc(taskId).update({
      'status': 'completed',
      'completed_at': DateTime.now().toIso8601String(),
      'completed_by': _uid,
    });
  }

  @override
  Future<void> reopenTask(String taskId) async {
    await _db.collection('tasks').doc(taskId).update({
      'status': 'pending',
      'completed_at': null,
      'completed_by': null,
    });
  }

  @override
  Future<void> deleteTask(String taskId) async {
    // Delete subtasks first, then the task.
    final subtasks = await _db
        .collection('subtasks')
        .where('task_id', isEqualTo: taskId)
        .get();
    final batch = _db.batch();
    for (final doc in subtasks.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_db.collection('tasks').doc(taskId));
    await batch.commit();
  }

  // ── Subtasks ──

  @override
  Future<Subtask> addSubtask({
    required String taskId,
    required String householdId,
    required String title,
    int sortOrder = 0,
  }) async {
    final id = _uuid.v4();
    final data = {
      'id': id,
      'task_id': taskId,
      'household_id': householdId,
      'title': _enc(title),
      'is_completed': false,
      'sort_order': sortOrder,
    };
    await _db.collection('subtasks').doc(id).set(data);
    return Subtask(id: id, taskId: taskId, householdId: householdId, title: title, sortOrder: sortOrder);
  }

  @override
  Future<void> toggleSubtask({
    required String subtaskId,
    required bool isCompleted,
  }) async {
    await _db
        .collection('subtasks')
        .doc(subtaskId)
        .update({'is_completed': isCompleted});
  }

  @override
  Future<void> deleteSubtask(String subtaskId) async {
    await _db.collection('subtasks').doc(subtaskId).delete();
  }

  // ── Categories ──

  @override
  Future<List<TaskCategory>> getCategories(String householdId) async {
    final snapshot = await _db
        .collection('task_categories')
        .where('household_id', isEqualTo: householdId)
        .get();
    final list = snapshot.docs
        .map((d) => _categoryFromFirestore(d.data()))
        .toList();
    // Sort: defaults first, then by name.
    list.sort((a, b) {
      if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return list;
  }

  @override
  Future<TaskCategory> createCategory({
    required String householdId,
    required String name,
    String icon = 'category',
    String color = '#7EA87E',
  }) async {
    final id = _uuid.v4();
    final data = {
      'id': id,
      'household_id': householdId,
      'name': _enc(name),
      'icon': icon,
      'color': color,
      'is_default': false,
    };
    await _db.collection('task_categories').doc(id).set(data);
    return TaskCategory(
      id: id,
      householdId: householdId,
      name: name,
      icon: icon,
      color: color,
      isDefault: false,
    );
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    final doc = await _db.collection('task_categories').doc(categoryId).get();
    if (doc.exists && doc.data()?['is_default'] == true) return; // Don't delete defaults
    await _db.collection('task_categories').doc(categoryId).delete();
  }

  // ── Stats ──

  @override
  Future<TaskStats> getTaskStats(String householdId) async {
    final snapshot = await _db
        .collection('tasks')
        .where('household_id', isEqualTo: householdId)
        .get();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int completed = 0, pending = 0, overdue = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final status = data['status'] as String? ?? 'pending';
      if (status == 'completed') {
        completed++;
      } else {
        pending++;
        final dueDateStr = data['due_date'] as String?;
        if (dueDateStr != null) {
          final dueDate = DateTime.tryParse(dueDateStr);
          if (dueDate != null && dueDate.isBefore(today)) overdue++;
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
    final now = DateTime.now();
    await _db.collection('checklists').doc(id).set({
      'id': id,
      'household_id': householdId,
      'title': _enc(title),
      'created_by': _uid,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
    return Checklist(
      id: id,
      householdId: householdId,
      title: title,
      createdBy: _uid ?? '',
      createdAt: now,
      items: [],
    );
  }

  @override
  Future<List<Checklist>> getChecklists(String householdId) async {
    final snapshot = await _db
        .collection('checklists')
        .where('household_id', isEqualTo: householdId)
        .orderBy('created_at', descending: true)
        .get();

    if (snapshot.docs.isEmpty) return [];

    // Get all checklist items for these checklists.
    final checklistIds = snapshot.docs.map((d) => d.id).toList();
    final itemsMap = await _getChecklistItemsByChecklistIds(checklistIds);

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final items = itemsMap[doc.id] ?? [];
      return Checklist(
        id: data['id'] as String? ?? doc.id,
        householdId: data['household_id'] as String? ?? '',
        title: _dec(data['title'] as String? ?? ''),
        createdBy: data['created_by'] as String? ?? '',
        createdAt: _parseDate(data['created_at']) ?? DateTime.now(),
        updatedAt: _parseDate(data['updated_at']),
        items: items,
      );
    }).toList();
  }

  @override
  Future<void> updateChecklist(String checklistId, String title) async {
    await _db.collection('checklists').doc(checklistId).update({
      'title': _enc(title),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> deleteChecklist(String checklistId) async {
    // Delete items first.
    final items = await _db
        .collection('checklist_items')
        .where('checklist_id', isEqualTo: checklistId)
        .get();
    final batch = _db.batch();
    for (final doc in items.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_db.collection('checklists').doc(checklistId));
    await batch.commit();
  }

  @override
  Future<ChecklistItem> addChecklistItem({
    required String checklistId,
    required String householdId,
    required String title,
    String? quantity,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await _db.collection('checklist_items').doc(id).set({
      'id': id,
      'checklist_id': checklistId,
      'household_id': householdId,
      'title': _enc(title),
      'quantity': quantity,
      'is_checked': false,
      'checked_at': null,
      'checked_by': null,
      'created_by': _uid,
      'created_at': now.toIso8601String(),
    });
    return ChecklistItem(
      id: id,
      checklistId: checklistId,
      householdId: householdId,
      title: title,
      quantity: quantity,
      createdBy: _uid,
      createdAt: now,
    );
  }

  @override
  Future<void> toggleChecklistItem(String itemId, bool isChecked) async {
    await _db.collection('checklist_items').doc(itemId).update({
      'is_checked': isChecked,
      'checked_at': isChecked ? DateTime.now().toIso8601String() : null,
      'checked_by': isChecked ? _uid : null,
    });
  }

  @override
  Future<void> deleteChecklistItem(String itemId) async {
    await _db.collection('checklist_items').doc(itemId).delete();
  }

  @override
  Future<void> pushChecklistItemAsTask({
    required String householdId,
    required String itemTitle,
    required String itemId,
  }) async {
    await createTask(
      householdId: householdId,
      title: itemTitle,
      dueDate: DateTime.now(),
      startDate: DateTime.now(),
      isShared: true,
    );
    await deleteChecklistItem(itemId);
  }

  @override
  Future<void> pushPlanChecklistItemAsTask({
    required String householdId,
    required String itemTitle,
    required String itemId,
  }) async {
    await createTask(
      householdId: householdId,
      title: itemTitle,
      dueDate: DateTime.now(),
      startDate: DateTime.now(),
      isShared: true,
    );
    await _db.collection('plan_checklist_items').doc(itemId).delete();
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
    final now = DateTime.now();
    await _db.collection('scratch_plans').doc(id).set({
      'id': id,
      'household_id': householdId,
      'title': _enc(title),
      'type': type,
      'status': 'draft',
      'start_date': _dateOnly(startDate),
      'end_date': _dateOnly(endDate),
      'is_template': isTemplate,
      'template_name': _encN(templateName),
      'created_by': _uid,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
    return Plan(
      id: id,
      householdId: householdId,
      title: title,
      type: type,
      startDate: startDate,
      endDate: endDate,
      isTemplate: isTemplate,
      templateName: templateName,
      createdBy: _uid ?? '',
      createdAt: now,
      entries: [],
      checklistItems: [],
    );
  }

  @override
  Future<List<Plan>> getPlans(String householdId) async {
    final snapshot = await _db
        .collection('scratch_plans')
        .where('household_id', isEqualTo: householdId)
        .where('is_template', isEqualTo: false)
        .orderBy('created_at', descending: true)
        .limit(100)
        .get();

    if (snapshot.docs.isEmpty) return [];

    final planIds = snapshot.docs.map((d) => d.id).toList();
    final entriesMap = await _getEntriesByPlanIds(planIds);
    final checklistMap = await _getPlanChecklistByPlanIds(planIds);

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return _planFromFirestore(
          data, entriesMap[doc.id] ?? [], checklistMap[doc.id] ?? []);
    }).toList();
  }

  @override
  Future<Plan> getPlan(String planId) async {
    final doc = await _db.collection('scratch_plans').doc(planId).get();
    if (!doc.exists) throw StateError('Plan $planId not found');
    final data = doc.data()!;

    final entriesSnap = await _db
        .collection('plan_entries')
        .where('plan_id', isEqualTo: planId)
        .orderBy('sort_order')
        .get();
    final entries =
        entriesSnap.docs.map((d) => _entryFromFirestore(d.data())).toList();

    final checklistSnap = await _db
        .collection('plan_checklist_items')
        .where('plan_id', isEqualTo: planId)
        .get();
    final checklistItems = checklistSnap.docs
        .map((d) => _planChecklistFromFirestore(d.data()))
        .toList();

    return _planFromFirestore(data, entries, checklistItems);
  }

  @override
  Future<void> deletePlan(String planId) async {
    final batch = _db.batch();

    // Delete entries.
    final entries = await _db
        .collection('plan_entries')
        .where('plan_id', isEqualTo: planId)
        .get();
    for (final doc in entries.docs) {
      batch.delete(doc.reference);
    }

    // Delete checklist items.
    final items = await _db
        .collection('plan_checklist_items')
        .where('plan_id', isEqualTo: planId)
        .get();
    for (final doc in items.docs) {
      batch.delete(doc.reference);
    }

    // Delete the plan itself.
    batch.delete(_db.collection('scratch_plans').doc(planId));
    await batch.commit();
  }

  @override
  Future<void> updatePlanStatus(String planId, String status) async {
    await _db.collection('scratch_plans').doc(planId).update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // ── Plan Entries ──

  @override
  Future<PlanEntry> addEntry({
    required String planId,
    required String householdId,
    required DateTime entryDate,
    required String title,
    String? label,
    String? description,
    int sortOrder = 0,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await _db.collection('plan_entries').doc(id).set({
      'id': id,
      'plan_id': planId,
      'household_id': householdId,
      'entry_date': _dateOnly(entryDate),
      'title': _enc(title),
      'label': _encN(label),
      'description': _encN(description),
      'sort_order': sortOrder,
      'created_by': _uid,
      'created_at': now.toIso8601String(),
    });
    return PlanEntry(
      id: id,
      planId: planId,
      householdId: householdId,
      entryDate: entryDate,
      title: title,
      label: label,
      description: description,
      sortOrder: sortOrder,
      createdBy: _uid,
      createdAt: now,
    );
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
    if (title != null) updates['title'] = _enc(title);
    if (label != null) updates['label'] = _enc(label);
    if (description != null) updates['description'] = _enc(description);

    await _db.collection('plan_entries').doc(entryId).update(updates);
  }

  @override
  Future<void> deleteEntry(String entryId) async {
    await _db.collection('plan_entries').doc(entryId).delete();
  }

  // ── Plan Checklist Items ──

  @override
  Future<PlanChecklistItem> addPlanChecklistItem({
    required String planId,
    required String householdId,
    String? entryId,
    required String title,
    String? quantity,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await _db.collection('plan_checklist_items').doc(id).set({
      'id': id,
      'plan_id': planId,
      'household_id': householdId,
      'entry_id': entryId,
      'title': _enc(title),
      'quantity': quantity,
      'is_checked': false,
      'checked_at': null,
      'checked_by': null,
      'created_by': _uid,
      'created_at': now.toIso8601String(),
    });
    return PlanChecklistItem(
      id: id,
      planId: planId,
      householdId: householdId,
      entryId: entryId,
      title: title,
      quantity: quantity,
      createdBy: _uid,
      createdAt: now,
    );
  }

  @override
  Future<void> togglePlanChecklistItem(String itemId, bool isChecked) async {
    await _db.collection('plan_checklist_items').doc(itemId).update({
      'is_checked': isChecked,
      'checked_at': isChecked ? DateTime.now().toIso8601String() : null,
      'checked_by': isChecked ? _uid : null,
    });
  }

  @override
  Future<void> deletePlanChecklistItem(String itemId) async {
    await _db.collection('plan_checklist_items').doc(itemId).delete();
  }

  // ── Templates ──

  @override
  Future<List<Plan>> getTemplates(String householdId) async {
    final snapshot = await _db
        .collection('scratch_plans')
        .where('household_id', isEqualTo: householdId)
        .where('is_template', isEqualTo: true)
        .orderBy('created_at', descending: true)
        .get();

    if (snapshot.docs.isEmpty) return [];

    final planIds = snapshot.docs.map((d) => d.id).toList();
    final entriesMap = await _getEntriesByPlanIds(planIds);

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return _planFromFirestore(data, entriesMap[doc.id] ?? [], []);
    }).toList();
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
        householdId: householdId,
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
          householdId: householdId,
          entryDate: newDate,
          title: entry.title,
          label: entry.label,
          sortOrder: entry.sortOrder,
        );
      }
    }

    return getPlan(newPlan.id);
  }

  // ── Realtime ──

  @override
  dynamic subscribeToEntries(
    String planId, {
    required void Function(dynamic payload) onEvent,
  }) {
    return _db
        .collection('plan_entries')
        .where('plan_id', isEqualTo: planId)
        .snapshots()
        .listen((snapshot) {
      // Decrypt and forward as list of PlanEntry maps.
      final entries = snapshot.docs.map((d) {
        final data = d.data();
        return _entryFromFirestore(data).toMap();
      }).toList();
      onEvent(entries);
    });
  }

  @override
  dynamic subscribeToChecklist(
    String planId, {
    required void Function(dynamic payload) onEvent,
  }) {
    return _db
        .collection('plan_checklist_items')
        .where('plan_id', isEqualTo: planId)
        .snapshots()
        .listen((snapshot) {
      final items = snapshot.docs.map((d) {
        final data = d.data();
        return _planChecklistFromFirestore(data).toMap();
      }).toList();
      onEvent(items);
    });
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

      final priorityForAction = action == 'note' ? 'low' : 'medium';
      final descForAction = action == 'note'
          ? '[Plan Note] ${entry.description ?? ''}'
          : entry.description;

      await createTask(
        householdId: householdId,
        title: title,
        description: descForAction,
        priority: priorityForAction,
        dueDate: entry.entryDate,
        startDate: entry.entryDate,
        isShared: true,
      );
    }

    await updatePlanStatus(planId, 'finalised');
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
    final id = _uuid.v4();
    final now = DateTime.now();

    final doc = {
      'id': id,
      'task_id': taskId,
      'household_id': householdId,
      'drive_file_id': driveFileId,
      'file_name': _enc(fileName),
      'mime_type': _enc(mimeType),
      'file_size_bytes': fileSizeBytes,
      'thumbnail_url': _encN(thumbnailUrl),
      'web_view_link': _enc(webViewLink),
      'uploaded_by': _uid,
      'uploaded_at': Timestamp.fromDate(now),
      'description': _encN(description),
    };

    await _db.collection('task_attachments').doc(id).set(doc);

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
      uploadedBy: _uid!,
      uploadedAt: now,
      description: description,
    );
  }

  @override
  Future<List<TaskAttachment>> getTaskAttachments(String taskId) async {
    final snap = await _db
        .collection('task_attachments')
        .where('task_id', isEqualTo: taskId)
        .orderBy('uploaded_at')
        .get();

    return snap.docs.map((d) {
      final data = d.data();
      return TaskAttachment(
        id: data['id'] as String? ?? d.id,
        taskId: data['task_id'] as String? ?? '',
        householdId: data['household_id'] as String? ?? '',
        driveFileId: data['drive_file_id'] as String? ?? '',
        fileName: _dec(data['file_name'] as String? ?? ''),
        mimeType: _dec(data['mime_type'] as String? ?? 'application/octet-stream'),
        fileSizeBytes: (data['file_size_bytes'] as num?)?.toInt() ?? 0,
        thumbnailUrl: _decN(data['thumbnail_url'] as String?),
        webViewLink: _dec(data['web_view_link'] as String? ?? ''),
        uploadedBy: data['uploaded_by'] as String? ?? '',
        uploadedAt: _parseDate(data['uploaded_at']) ?? DateTime.now(),
        description: _decN(data['description'] as String?),
      );
    }).toList();
  }

  @override
  Future<void> deleteAttachment(String attachmentId) async {
    await _db.collection('task_attachments').doc(attachmentId).delete();
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
    final id = _uuid.v4();
    final now = DateTime.now();

    final doc = {
      'id': id,
      'plan_id': planId,
      'entry_id': entryId,
      'household_id': householdId,
      'drive_file_id': driveFileId,
      'file_name': _enc(fileName),
      'mime_type': _enc(mimeType),
      'file_size_bytes': fileSizeBytes,
      'thumbnail_url': _encN(thumbnailUrl),
      'web_view_link': _enc(webViewLink),
      'uploaded_by': _uid,
      'uploaded_at': Timestamp.fromDate(now),
      'description': _encN(description),
    };

    await _db.collection('plan_attachments').doc(id).set(doc);

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
      uploadedBy: _uid!,
      uploadedAt: now,
      description: description,
    );
  }

  @override
  Future<List<PlanAttachment>> getPlanEntryAttachments(String entryId) async {
    final snap = await _db
        .collection('plan_attachments')
        .where('entry_id', isEqualTo: entryId)
        .orderBy('uploaded_at')
        .get();

    return snap.docs.map((d) => _planAttachmentFromFirestore(d.data())).toList();
  }

  @override
  Future<List<PlanAttachment>> getPlanAttachments(String planId) async {
    final snap = await _db
        .collection('plan_attachments')
        .where('plan_id', isEqualTo: planId)
        .orderBy('uploaded_at')
        .get();

    return snap.docs.map((d) => _planAttachmentFromFirestore(d.data())).toList();
  }

  PlanAttachment _planAttachmentFromFirestore(Map<String, dynamic> data) {
    return PlanAttachment(
      id: data['id'] as String? ?? '',
      planId: data['plan_id'] as String? ?? '',
      entryId: data['entry_id'] as String? ?? '',
      householdId: data['household_id'] as String? ?? '',
      driveFileId: data['drive_file_id'] as String? ?? '',
      fileName: _dec(data['file_name'] as String? ?? ''),
      mimeType: _dec(data['mime_type'] as String? ?? 'application/octet-stream'),
      fileSizeBytes: (data['file_size_bytes'] as num?)?.toInt() ?? 0,
      thumbnailUrl: _decN(data['thumbnail_url'] as String?),
      webViewLink: _dec(data['web_view_link'] as String? ?? ''),
      uploadedBy: data['uploaded_by'] as String? ?? '',
      uploadedAt: _parseDate(data['uploaded_at']) ?? DateTime.now(),
      description: _decN(data['description'] as String?),
    );
  }

  @override
  Future<void> deletePlanAttachment(String attachmentId) async {
    await _db.collection('plan_attachments').doc(attachmentId).delete();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  INVENTORY
  // ═══════════════════════════════════════════════════════════════════

  @override
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
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    final doc = {
      'id': id,
      'household_id': householdId,
      'name': _enc(name),
      'description': _encN(description),
      'category_id': categoryId,
      'location_id': locationId,
      'quantity': quantity,
      'unit': _enc(unit),
      'low_stock_threshold': lowStockThreshold,
      'barcode': _encN(barcode),
      'barcode_type': barcodeType,
      'expiry_date': expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
      'purchase_date': purchaseDate != null ? Timestamp.fromDate(purchaseDate) : null,
      'notes': _encN(notes),
      'created_by': _uid,
      'created_at': Timestamp.fromDate(now),
      'updated_at': Timestamp.fromDate(now),
    };

    await _db.collection('inventory_items').doc(id).set(doc);

    // Log the initial quantity if > 0.
    if (quantity > 0) {
      await logInventoryAction(
        itemId: id,
        householdId: householdId,
        action: 'added',
        quantityChange: quantity,
        quantityAfter: quantity,
      );
    }

    return getInventoryItem(id);
  }

  @override
  Future<List<InventoryItem>> getInventoryItems({
    required String householdId,
    String? categoryId,
    String? locationId,
    bool? lowStockOnly,
    bool? expiringOnly,
  }) async {
    Query<Map<String, dynamic>> query = _db
        .collection('inventory_items')
        .where('household_id', isEqualTo: householdId);

    if (categoryId != null) {
      query = query.where('category_id', isEqualTo: categoryId);
    }
    if (locationId != null) {
      query = query.where('location_id', isEqualTo: locationId);
    }

    final snapshot = await query
        .orderBy('created_at', descending: true)
        .limit(500)
        .get();

    if (snapshot.docs.isEmpty) return [];

    // Collect category and location IDs for bulk lookup.
    final categoryIds = <String>{};
    final locationIds = <String>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['category_id'] != null) {
        categoryIds.add(data['category_id'] as String);
      }
      if (data['location_id'] != null) {
        locationIds.add(data['location_id'] as String);
      }
    }

    // Bulk-fetch categories in parallel.
    final categories = <String, InventoryCategory>{};
    final catDocs = await Future.wait(
      categoryIds.map((catId) =>
          _db.collection('inventory_categories').doc(catId).get()),
    );
    for (final catDoc in catDocs) {
      if (catDoc.exists) {
        final cd = catDoc.data()!;
        final catId = catDoc.id;
        categories[catId] = InventoryCategory(
          id: cd['id'] as String? ?? catId,
          householdId: cd['household_id'] as String? ?? '',
          name: _dec(cd['name'] as String? ?? ''),
          icon: cd['icon'] as String? ?? 'inventory_2',
          color: cd['color'] as String? ?? '#A5B4A5',
          isDefault: cd['is_default'] as bool? ?? false,
          sortOrder: (cd['sort_order'] as num?)?.toInt() ?? 0,
          createdAt: _parseDate(cd['created_at']) ?? DateTime.now(),
        );
      }
    }

    // Bulk-fetch locations in parallel.
    final locations = <String, InventoryLocation>{};
    final locDocs = await Future.wait(
      locationIds.map((locId) =>
          _db.collection('inventory_locations').doc(locId).get()),
    );
    for (final locDoc in locDocs) {
      if (locDoc.exists) {
        final ld = locDoc.data()!;
        final locId = locDoc.id;
        locations[locId] = InventoryLocation(
          id: ld['id'] as String? ?? locId,
          householdId: ld['household_id'] as String? ?? '',
          name: _dec(ld['name'] as String? ?? ''),
          icon: ld['icon'] as String? ?? 'place',
          isDefault: ld['is_default'] as bool? ?? false,
          sortOrder: (ld['sort_order'] as num?)?.toInt() ?? 0,
          createdAt: _parseDate(ld['created_at']) ?? DateTime.now(),
        );
      }
    }

    // Build items list.
    var items = snapshot.docs.map((doc) {
      final d = doc.data();
      return InventoryItem(
        id: d['id'] as String? ?? doc.id,
        householdId: d['household_id'] as String? ?? '',
        name: _dec(d['name'] as String? ?? ''),
        description: _decN(d['description'] as String?),
        categoryId: d['category_id'] as String?,
        locationId: d['location_id'] as String?,
        quantity: (d['quantity'] as num?)?.toInt() ?? 0,
        unit: _dec(d['unit'] as String? ?? 'pieces'),
        lowStockThreshold: (d['low_stock_threshold'] as num?)?.toInt(),
        barcode: _decN(d['barcode'] as String?),
        barcodeType: d['barcode_type'] as String? ?? 'none',
        expiryDate: _parseDate(d['expiry_date']),
        purchaseDate: _parseDate(d['purchase_date']),
        notes: _decN(d['notes'] as String?),
        createdBy: d['created_by'] as String? ?? '',
        createdAt: _parseDate(d['created_at']) ?? DateTime.now(),
        updatedAt: _parseDate(d['updated_at']) ?? DateTime.now(),
        category: d['category_id'] != null
            ? categories[d['category_id'] as String]
            : null,
        location: d['location_id'] != null
            ? locations[d['location_id'] as String]
            : null,
      );
    }).toList();

    // Client-side filters for lowStockOnly / expiringOnly.
    if (lowStockOnly == true) {
      items = items.where((i) => i.isLowStock).toList();
    }
    if (expiringOnly == true) {
      items = items.where((i) => i.isExpiringSoon).toList();
    }

    return items;
  }

  @override
  Future<InventoryItem> getInventoryItem(String itemId) async {
    final doc = await _db.collection('inventory_items').doc(itemId).get();
    if (!doc.exists) throw StateError('Inventory item $itemId not found');
    final d = doc.data()!;

    // Join category.
    InventoryCategory? category;
    if (d['category_id'] != null) {
      final catDoc = await _db
          .collection('inventory_categories')
          .doc(d['category_id'] as String)
          .get();
      if (catDoc.exists) {
        final cd = catDoc.data()!;
        category = InventoryCategory(
          id: cd['id'] as String? ?? catDoc.id,
          householdId: cd['household_id'] as String? ?? '',
          name: _dec(cd['name'] as String? ?? ''),
          icon: cd['icon'] as String? ?? 'inventory_2',
          color: cd['color'] as String? ?? '#A5B4A5',
          isDefault: cd['is_default'] as bool? ?? false,
          sortOrder: (cd['sort_order'] as num?)?.toInt() ?? 0,
          createdAt: _parseDate(cd['created_at']) ?? DateTime.now(),
        );
      }
    }

    // Join location.
    InventoryLocation? location;
    if (d['location_id'] != null) {
      final locDoc = await _db
          .collection('inventory_locations')
          .doc(d['location_id'] as String)
          .get();
      if (locDoc.exists) {
        final ld = locDoc.data()!;
        location = InventoryLocation(
          id: ld['id'] as String? ?? locDoc.id,
          householdId: ld['household_id'] as String? ?? '',
          name: _dec(ld['name'] as String? ?? ''),
          icon: ld['icon'] as String? ?? 'place',
          isDefault: ld['is_default'] as bool? ?? false,
          sortOrder: (ld['sort_order'] as num?)?.toInt() ?? 0,
          createdAt: _parseDate(ld['created_at']) ?? DateTime.now(),
        );
      }
    }

    // Join creator profile.
    ProfileRef? creatorProfile;
    if (d['created_by'] != null) {
      creatorProfile = await _getProfile(d['created_by'] as String);
    }

    // Join attachments.
    final attSnap = await _db
        .collection('inventory_attachments')
        .where('item_id', isEqualTo: itemId)
        .orderBy('uploaded_at')
        .get();
    final attachments = attSnap.docs.map((a) {
      final ad = a.data();
      return InventoryAttachment(
        id: ad['id'] as String? ?? a.id,
        itemId: ad['item_id'] as String? ?? '',
        householdId: ad['household_id'] as String? ?? '',
        driveFileId: ad['drive_file_id'] as String? ?? '',
        fileName: _dec(ad['file_name'] as String? ?? ''),
        mimeType: _dec(ad['mime_type'] as String? ?? 'application/octet-stream'),
        fileSizeBytes: (ad['file_size_bytes'] as num?)?.toInt() ?? 0,
        thumbnailUrl: _decN(ad['thumbnail_url'] as String?),
        webViewLink: _dec(ad['web_view_link'] as String? ?? ''),
        uploadedBy: ad['uploaded_by'] as String? ?? '',
        uploadedAt: _parseDate(ad['uploaded_at']) ?? DateTime.now(),
        description: _decN(ad['description'] as String?),
      );
    }).toList();

    return InventoryItem(
      id: d['id'] as String? ?? itemId,
      householdId: d['household_id'] as String? ?? '',
      name: _dec(d['name'] as String? ?? ''),
      description: _decN(d['description'] as String?),
      categoryId: d['category_id'] as String?,
      locationId: d['location_id'] as String?,
      quantity: (d['quantity'] as num?)?.toInt() ?? 0,
      unit: _dec(d['unit'] as String? ?? 'pieces'),
      lowStockThreshold: (d['low_stock_threshold'] as num?)?.toInt(),
      barcode: _decN(d['barcode'] as String?),
      barcodeType: d['barcode_type'] as String? ?? 'none',
      expiryDate: _parseDate(d['expiry_date']),
      purchaseDate: _parseDate(d['purchase_date']),
      notes: _decN(d['notes'] as String?),
      createdBy: d['created_by'] as String? ?? '',
      createdAt: _parseDate(d['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(d['updated_at']) ?? DateTime.now(),
      category: category,
      location: location,
      creatorProfile: creatorProfile,
      attachments: attachments,
    );
  }

  @override
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
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = _enc(name);
    if (description != null) updates['description'] = _enc(description);
    if (categoryId != null) updates['category_id'] = categoryId;
    if (locationId != null) updates['location_id'] = locationId;
    if (quantity != null) updates['quantity'] = quantity;
    if (unit != null) updates['unit'] = _enc(unit);
    if (lowStockThreshold != null) {
      updates['low_stock_threshold'] = lowStockThreshold;
    }
    if (barcode != null) updates['barcode'] = _enc(barcode);
    if (barcodeType != null) updates['barcode_type'] = barcodeType;
    if (expiryDate != null) {
      updates['expiry_date'] = Timestamp.fromDate(expiryDate);
    }
    if (purchaseDate != null) {
      updates['purchase_date'] = Timestamp.fromDate(purchaseDate);
    }
    if (notes != null) updates['notes'] = _enc(notes);
    updates['updated_at'] = Timestamp.fromDate(DateTime.now());

    await _db.collection('inventory_items').doc(itemId).update(updates);
  }

  @override
  Future<void> deleteInventoryItem(String itemId) async {
    // Collect related logs and attachments, then batch-delete everything.
    final logSnap = await _db
        .collection('inventory_logs')
        .where('item_id', isEqualTo: itemId)
        .get();
    final attSnap = await _db
        .collection('inventory_attachments')
        .where('item_id', isEqualTo: itemId)
        .get();

    final allRefs = <DocumentReference>[
      _db.collection('inventory_items').doc(itemId),
      ...logSnap.docs.map((d) => d.reference),
      ...attSnap.docs.map((d) => d.reference),
    ];

    for (final chunk in _chunk(allRefs, 400)) {
      final batch = _db.batch();
      for (final ref in chunk) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  @override
  Future<List<InventoryCategory>> getInventoryCategories(
      String householdId) async {
    final snap = await _db
        .collection('inventory_categories')
        .where('household_id', isEqualTo: householdId)
        .orderBy('sort_order')
        .get();

    return snap.docs.map((doc) {
      final d = doc.data();
      return InventoryCategory(
        id: d['id'] as String? ?? doc.id,
        householdId: d['household_id'] as String? ?? '',
        name: _dec(d['name'] as String? ?? ''),
        icon: d['icon'] as String? ?? 'inventory_2',
        color: d['color'] as String? ?? '#A5B4A5',
        isDefault: d['is_default'] as bool? ?? false,
        sortOrder: (d['sort_order'] as num?)?.toInt() ?? 0,
        createdAt: _parseDate(d['created_at']) ?? DateTime.now(),
      );
    }).toList();
  }

  @override
  Future<InventoryCategory> createInventoryCategory({
    required String householdId,
    required String name,
    String icon = 'inventory_2',
    String color = '#A5B4A5',
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    // Determine next sort_order.
    final existing = await _db
        .collection('inventory_categories')
        .where('household_id', isEqualTo: householdId)
        .orderBy('sort_order', descending: true)
        .limit(1)
        .get();
    final nextOrder = existing.docs.isNotEmpty
        ? ((existing.docs.first.data()['sort_order'] as num?)?.toInt() ?? 0) + 1
        : 0;

    final doc = {
      'id': id,
      'household_id': householdId,
      'name': _enc(name),
      'icon': icon,
      'color': color,
      'is_default': false,
      'sort_order': nextOrder,
      'created_at': Timestamp.fromDate(now),
    };

    await _db.collection('inventory_categories').doc(id).set(doc);

    return InventoryCategory(
      id: id,
      householdId: householdId,
      name: name,
      icon: icon,
      color: color,
      isDefault: false,
      sortOrder: nextOrder,
      createdAt: now,
    );
  }

  @override
  Future<void> deleteInventoryCategory(String categoryId) async {
    await _db.collection('inventory_categories').doc(categoryId).delete();
  }

  @override
  Future<List<InventoryLocation>> getInventoryLocations(
      String householdId) async {
    final snap = await _db
        .collection('inventory_locations')
        .where('household_id', isEqualTo: householdId)
        .orderBy('sort_order')
        .get();

    return snap.docs.map((doc) {
      final d = doc.data();
      return InventoryLocation(
        id: d['id'] as String? ?? doc.id,
        householdId: d['household_id'] as String? ?? '',
        name: _dec(d['name'] as String? ?? ''),
        icon: d['icon'] as String? ?? 'place',
        isDefault: d['is_default'] as bool? ?? false,
        sortOrder: (d['sort_order'] as num?)?.toInt() ?? 0,
        createdAt: _parseDate(d['created_at']) ?? DateTime.now(),
      );
    }).toList();
  }

  @override
  Future<InventoryLocation> createInventoryLocation({
    required String householdId,
    required String name,
    String icon = 'place',
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    // Determine next sort_order.
    final existing = await _db
        .collection('inventory_locations')
        .where('household_id', isEqualTo: householdId)
        .orderBy('sort_order', descending: true)
        .limit(1)
        .get();
    final nextOrder = existing.docs.isNotEmpty
        ? ((existing.docs.first.data()['sort_order'] as num?)?.toInt() ?? 0) + 1
        : 0;

    final doc = {
      'id': id,
      'household_id': householdId,
      'name': _enc(name),
      'icon': icon,
      'is_default': false,
      'sort_order': nextOrder,
      'created_at': Timestamp.fromDate(now),
    };

    await _db.collection('inventory_locations').doc(id).set(doc);

    return InventoryLocation(
      id: id,
      householdId: householdId,
      name: name,
      icon: icon,
      isDefault: false,
      sortOrder: nextOrder,
      createdAt: now,
    );
  }

  @override
  Future<void> deleteInventoryLocation(String locationId) async {
    await _db.collection('inventory_locations').doc(locationId).delete();
  }

  @override
  Future<void> logInventoryAction({
    required String itemId,
    required String householdId,
    required String action,
    required int quantityChange,
    required int quantityAfter,
    String? note,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    final doc = {
      'id': id,
      'item_id': itemId,
      'household_id': householdId,
      'action': action,
      'quantity_change': quantityChange,
      'quantity_after': quantityAfter,
      'note': _encN(note),
      'performed_by': _uid,
      'performed_at': Timestamp.fromDate(now),
    };

    await _db.collection('inventory_logs').doc(id).set(doc);
  }

  @override
  Future<List<InventoryLog>> getInventoryLogs({
    required String itemId,
    required String householdId,
    int limit = 50,
  }) async {
    final snap = await _db
        .collection('inventory_logs')
        .where('household_id', isEqualTo: householdId)
        .where('item_id', isEqualTo: itemId)
        .orderBy('performed_at', descending: true)
        .limit(limit)
        .get();

    // Collect performer IDs for bulk profile lookup.
    final profileIds = <String>{};
    for (final doc in snap.docs) {
      final uid = doc.data()['performed_by'] as String?;
      if (uid != null) profileIds.add(uid);
    }

    final profiles = <String, ProfileRef>{};
    for (final uid in profileIds) {
      final p = await _getProfile(uid);
      if (p != null) profiles[uid] = p;
    }

    return snap.docs.map((doc) {
      final d = doc.data();
      final performedBy = d['performed_by'] as String? ?? '';
      return InventoryLog(
        id: d['id'] as String? ?? doc.id,
        itemId: d['item_id'] as String? ?? '',
        householdId: d['household_id'] as String? ?? '',
        action: d['action'] as String? ?? '',
        quantityChange: (d['quantity_change'] as num?)?.toInt() ?? 0,
        quantityAfter: (d['quantity_after'] as num?)?.toInt() ?? 0,
        note: _decN(d['note'] as String?),
        performedBy: performedBy,
        performedAt: _parseDate(d['performed_at']) ?? DateTime.now(),
        performerProfile: profiles[performedBy],
      );
    }).toList();
  }

  @override
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
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    final doc = {
      'id': id,
      'item_id': itemId,
      'household_id': householdId,
      'drive_file_id': driveFileId,
      'file_name': _enc(fileName),
      'mime_type': _enc(mimeType),
      'file_size_bytes': fileSizeBytes,
      'thumbnail_url': _encN(thumbnailUrl),
      'web_view_link': _enc(webViewLink),
      'uploaded_by': _uid,
      'uploaded_at': Timestamp.fromDate(now),
      'description': _encN(description),
    };

    await _db.collection('inventory_attachments').doc(id).set(doc);

    return InventoryAttachment(
      id: id,
      itemId: itemId,
      householdId: householdId,
      driveFileId: driveFileId,
      fileName: fileName,
      mimeType: mimeType,
      fileSizeBytes: fileSizeBytes,
      thumbnailUrl: thumbnailUrl,
      webViewLink: webViewLink,
      uploadedBy: _uid!,
      uploadedAt: now,
      description: description,
    );
  }

  @override
  Future<List<InventoryAttachment>> getInventoryAttachments(
      String itemId, {required String householdId}) async {
    final snap = await _db
        .collection('inventory_attachments')
        .where('household_id', isEqualTo: householdId)
        .where('item_id', isEqualTo: itemId)
        .orderBy('uploaded_at')
        .get();

    return snap.docs.map((d) {
      final data = d.data();
      return InventoryAttachment(
        id: data['id'] as String? ?? d.id,
        itemId: data['item_id'] as String? ?? '',
        householdId: data['household_id'] as String? ?? '',
        driveFileId: data['drive_file_id'] as String? ?? '',
        fileName: _dec(data['file_name'] as String? ?? ''),
        mimeType:
            _dec(data['mime_type'] as String? ?? 'application/octet-stream'),
        fileSizeBytes: (data['file_size_bytes'] as num?)?.toInt() ?? 0,
        thumbnailUrl: _decN(data['thumbnail_url'] as String?),
        webViewLink: _dec(data['web_view_link'] as String? ?? ''),
        uploadedBy: data['uploaded_by'] as String? ?? '',
        uploadedAt: _parseDate(data['uploaded_at']) ?? DateTime.now(),
        description: _decN(data['description'] as String?),
      );
    }).toList();
  }

  @override
  Future<void> deleteInventoryAttachment(String attachmentId) async {
    await _db.collection('inventory_attachments').doc(attachmentId).delete();
  }

  @override
  Future<Map<String, int>> getInventoryStats(String householdId) async {
    final baseQuery = _db
        .collection('inventory_items')
        .where('household_id', isEqualTo: householdId);

    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));

    // Total count via aggregation (no doc reads).
    final totalAgg = await baseQuery.count().get();
    final total = totalAgg.count ?? 0;

    // Low stock: must read docs because Firestore can't compare two fields.
    // Only fetch items that HAVE a threshold set to minimise reads.
    final lowStockQuery =
        baseQuery.where('low_stock_threshold', isGreaterThan: 0);
    final lowStockDocs = await lowStockQuery.get();
    int lowStock = 0;
    for (final doc in lowStockDocs.docs) {
      final d = doc.data();
      final qty = (d['quantity'] as num?)?.toInt() ?? 0;
      final threshold = (d['low_stock_threshold'] as num?)?.toInt() ?? 0;
      if (qty <= threshold) lowStock++;
    }

    // Expired: expiry_date < now (server-side filter).
    final expiredAgg = await baseQuery
        .where('expiry_date', isLessThan: Timestamp.fromDate(now))
        .where('expiry_date',
            isGreaterThan: Timestamp.fromDate(DateTime(2000)))
        .count()
        .get();
    final expired = expiredAgg.count ?? 0;

    // Expiring soon: expiry_date between now and now+7 days.
    final expiringAgg = await baseQuery
        .where('expiry_date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .where('expiry_date',
            isLessThanOrEqualTo: Timestamp.fromDate(weekFromNow))
        .count()
        .get();
    final expiringSoon = expiringAgg.count ?? 0;

    return {
      'total': total,
      'lowStock': lowStock,
      'expiringSoon': expiringSoon,
      'expired': expired,
    };
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
    final q = query.toLowerCase();
    final results = <SearchResult>[];

    bool matches(String? text) =>
        text != null && text.toLowerCase().contains(q);

    // ── Tasks ──
    if (entityTypes.contains('task')) {
      final snap = await _db
          .collection('tasks')
          .where('household_id', isEqualTo: householdId)
          .limit(200)
          .get();
      for (final doc in snap.docs) {
        final d = doc.data();
        final title = _dec(d['title'] as String? ?? '');
        final desc = _decN(d['description'] as String?);
        if (matches(title) || matches(desc)) {
          results.add(SearchResult(
            id: doc.id,
            entityType: 'task',
            householdId: householdId,
            title: title,
            subtitle: desc,
            relevanceDate: _parseDate(d['due_date']) ??
                _parseDate(d['created_at']),
          ));
        }
      }
    }

    // ── Checklists + items ──
    if (entityTypes.contains('checklist')) {
      final clSnap = await _db
          .collection('checklists')
          .where('household_id', isEqualTo: householdId)
          .limit(200)
          .get();

      // Build name lookup for parent context on items.
      final clNames = <String, String>{};
      for (final doc in clSnap.docs) {
        final title = _dec(doc.data()['title'] as String? ?? '');
        clNames[doc.id] = title;
        if (matches(title)) {
          results.add(SearchResult(
            id: doc.id,
            entityType: 'checklist',
            householdId: householdId,
            title: title,
            relevanceDate: _parseDate(doc.data()['created_at']),
          ));
        }
      }

      // Search checklist items.
      if (clNames.isNotEmpty) {
        final itemSnap = await _db
            .collection('checklist_items')
            .where('checklist_id', whereIn: clNames.keys.take(10).toList())
            .limit(500)
            .get();
        for (final doc in itemSnap.docs) {
          final d = doc.data();
          final title = _dec(d['title'] as String? ?? '');
          if (matches(title)) {
            final parentId = d['checklist_id'] as String?;
            results.add(SearchResult(
              id: doc.id,
              entityType: 'checklist',
              householdId: householdId,
              title: title,
              subtitle: parentId != null ? clNames[parentId] : null,
              parentId: parentId,
              relevanceDate: _parseDate(d['created_at']),
            ));
          }
        }
      }
    }

    // ── Plans + entries ──
    if (entityTypes.contains('plan')) {
      final planSnap = await _db
          .collection('scratch_plans')
          .where('household_id', isEqualTo: householdId)
          .where('is_template', isEqualTo: false)
          .limit(200)
          .get();

      final planNames = <String, String>{};
      for (final doc in planSnap.docs) {
        final title = _dec(doc.data()['title'] as String? ?? '');
        planNames[doc.id] = title;
        if (matches(title)) {
          results.add(SearchResult(
            id: doc.id,
            entityType: 'plan',
            householdId: householdId,
            title: title,
            relevanceDate: _parseDate(doc.data()['start_date']),
          ));
        }
      }

      // Search plan entries.
      if (planNames.isNotEmpty) {
        final entrySnap = await _db
            .collection('plan_entries')
            .where('plan_id', whereIn: planNames.keys.take(10).toList())
            .limit(500)
            .get();
        for (final doc in entrySnap.docs) {
          final d = doc.data();
          final title = _dec(d['title'] as String? ?? '');
          final desc = _decN(d['description'] as String?);
          if (matches(title) || matches(desc)) {
            final parentId = d['plan_id'] as String?;
            results.add(SearchResult(
              id: doc.id,
              entityType: 'plan',
              householdId: householdId,
              title: title,
              subtitle: parentId != null ? planNames[parentId] : null,
              parentId: parentId,
              relevanceDate: _parseDate(d['entry_date']),
            ));
          }
        }
      }
    }

    // ── Attachments (task + plan) ──
    if (entityTypes.contains('attachment')) {
      final taskAttSnap = await _db
          .collection('task_attachments')
          .where('household_id', isEqualTo: householdId)
          .limit(200)
          .get();
      for (final doc in taskAttSnap.docs) {
        final d = doc.data();
        final name = _dec(d['file_name'] as String? ?? '');
        final desc = _decN(d['description'] as String?);
        if (matches(name) || matches(desc)) {
          results.add(SearchResult(
            id: doc.id,
            entityType: 'attachment',
            householdId: householdId,
            title: name,
            subtitle: desc,
            parentId: d['task_id'] as String?,
            metadata: {'source': 'task'},
            relevanceDate: _parseDate(d['created_at']),
          ));
        }
      }

      final planAttSnap = await _db
          .collection('plan_attachments')
          .where('household_id', isEqualTo: householdId)
          .limit(200)
          .get();
      for (final doc in planAttSnap.docs) {
        final d = doc.data();
        final name = _dec(d['file_name'] as String? ?? '');
        final desc = _decN(d['description'] as String?);
        if (matches(name) || matches(desc)) {
          results.add(SearchResult(
            id: doc.id,
            entityType: 'attachment',
            householdId: householdId,
            title: name,
            subtitle: desc,
            parentId: d['plan_id'] as String?,
            metadata: {'source': 'plan'},
            relevanceDate: _parseDate(d['created_at']),
          ));
        }
      }
    }

    // ── Inventory items ──
    if (entityTypes.contains('inventory')) {
      final invSnap = await _db
          .collection('inventory_items')
          .where('household_id', isEqualTo: householdId)
          .limit(200)
          .get();
      for (final doc in invSnap.docs) {
        final d = doc.data();
        final itemName = _dec(d['name'] as String? ?? '');
        final desc = _decN(d['description'] as String?);
        final notes = _decN(d['notes'] as String?);
        if (matches(itemName) || matches(desc) || matches(notes)) {
          results.add(SearchResult(
            id: doc.id,
            entityType: 'inventory',
            householdId: householdId,
            title: itemName,
            subtitle: desc,
            relevanceDate: _parseDate(d['created_at']),
          ));
        }
      }
    }

    // Sort by relevance date (most recent first), nulls last.
    results.sort((a, b) {
      if (a.relevanceDate == null && b.relevanceDate == null) return 0;
      if (a.relevanceDate == null) return 1;
      if (b.relevanceDate == null) return -1;
      return b.relevanceDate!.compareTo(a.relevanceDate!);
    });

    return results;
  }

  // ═══════════════════════════════════════════════════════════════════
  //  DATA WIPE
  // ═══════════════════════════════════════════════════════════════════

  @override
  Future<void> wipeAllData(String userId) async {
    debugPrint('[BURN] Starting Firestore data wipe…');

    // Find all households this user belongs to.
    final memberSnap = await _db
        .collection('household_members')
        .where('user_id', isEqualTo: userId)
        .get();
    debugPrint('[BURN] household_members query returned ${memberSnap.docs.length} docs for userId=$userId');

    final householdIds = memberSnap.docs
        .map((d) => d.data()['household_id'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    debugPrint('[BURN] householdIds=$householdIds');

    if (householdIds.isEmpty) {
      debugPrint('[BURN] No households found for user — skipping Firestore wipe');
      return;
    }

    for (final hid in householdIds) {
      // Delete Drive config FIRST — requires isMember() which needs the
      // member doc to still exist.
      try {
        await _db.collection('household_drive_config').doc(hid).delete();
      } catch (_) {}

      // Now wipe all household data (including the member doc itself).
      await _wipeHouseholdData(hid);
    }

    // Delete user's profile.
    await _db.collection('profiles').doc(userId).delete();

    // Clear encryption keys.
    await _keyManager.clearKeys();
    for (final hid in householdIds) {
      await _keyManager.deleteKeyFromFirestore(hid);
    }

    debugPrint('[BURN] ✓ All data wiped for user $userId');
  }

  /// Deletes all data for a household (tasks, subtasks, categories,
  /// checklists, plans, entries, plan checklist items, inventory).
  ///
  /// Collects child doc IDs BEFORE deleting parents (Firestore doesn't
  /// cascade deletes). Respects 500-operation batch limit by chunking.
  Future<void> _wipeHouseholdData(String householdId) async {
    // ── Step 1: Collect parent IDs needed for child lookups ──

    final taskSnap = await _db
        .collection('tasks')
        .where('household_id', isEqualTo: householdId)
        .get();
    final taskIds = taskSnap.docs.map((d) => d.id).toList();

    final checklistSnap = await _db
        .collection('checklists')
        .where('household_id', isEqualTo: householdId)
        .get();
    final checklistIds = checklistSnap.docs.map((d) => d.id).toList();

    final planSnap = await _db
        .collection('scratch_plans')
        .where('household_id', isEqualTo: householdId)
        .get();
    final planIds = planSnap.docs.map((d) => d.id).toList();

    debugPrint(
      '[BURN] Found ${taskSnap.docs.length} tasks, '
      '${checklistSnap.docs.length} checklists, '
      '${planSnap.docs.length} plans for household $householdId',
    );

    // ── Step 2: Collect all documents to delete ──

    final allDocs = <DocumentReference>[
      ...taskSnap.docs.map((d) => d.reference),
      ...checklistSnap.docs.map((d) => d.reference),
      ...planSnap.docs.map((d) => d.reference),
    ];

    // Categories, attachments, invites, and inventory (household-scoped).
    for (final col in [
      'task_categories',
      'task_attachments',
      'plan_attachments',
      'household_invites',
      'inventory_items',
      'inventory_categories',
      'inventory_locations',
      'inventory_logs',
      'inventory_attachments',
    ]) {
      final snap = await _db
          .collection(col)
          .where('household_id', isEqualTo: householdId)
          .get();
      debugPrint('[BURN] Found ${snap.docs.length} docs in $col');
      allDocs.addAll(snap.docs.map((d) => d.reference));
    }

    // Subtasks (child of tasks).
    for (final chunk in _chunk(taskIds, 30)) {
      final snap = await _db
          .collection('subtasks')
          .where('task_id', whereIn: chunk)
          .get();
      debugPrint('[BURN] Found ${snap.docs.length} subtasks (chunk of ${chunk.length} tasks)');
      allDocs.addAll(snap.docs.map((d) => d.reference));
    }

    // Checklist items (child of checklists).
    for (final chunk in _chunk(checklistIds, 30)) {
      final snap = await _db
          .collection('checklist_items')
          .where('checklist_id', whereIn: chunk)
          .get();
      debugPrint('[BURN] Found ${snap.docs.length} checklist_items (chunk of ${chunk.length} checklists)');
      allDocs.addAll(snap.docs.map((d) => d.reference));
    }

    // Plan entries and plan checklist items (child of plans).
    for (final chunk in _chunk(planIds, 30)) {
      final entrySnap = await _db
          .collection('plan_entries')
          .where('plan_id', whereIn: chunk)
          .get();
      debugPrint('[BURN] Found ${entrySnap.docs.length} plan_entries (chunk of ${chunk.length} plans)');
      allDocs.addAll(entrySnap.docs.map((d) => d.reference));

      final pciSnap = await _db
          .collection('plan_checklist_items')
          .where('plan_id', whereIn: chunk)
          .get();
      debugPrint('[BURN] Found ${pciSnap.docs.length} plan_checklist_items (chunk of ${chunk.length} plans)');
      allDocs.addAll(pciSnap.docs.map((d) => d.reference));
    }

    // Household members.
    final memberSnap = await _db
        .collection('household_members')
        .where('household_id', isEqualTo: householdId)
        .get();
    debugPrint('[BURN] Found ${memberSnap.docs.length} household_members');
    allDocs.addAll(memberSnap.docs.map((d) => d.reference));

    // The household document itself.
    allDocs.add(_db.collection('households').doc(householdId));

    // ── Step 3: Batch-delete in chunks of 400 (under 500-op limit) ──

    final chunks = _chunk(allDocs, 400);
    debugPrint('[BURN] Deleting ${allDocs.length} total docs in ${chunks.length} batches');
    var deleted = 0;
    const maxRetries = 3;

    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      var retries = 0;

      while (retries < maxRetries) {
        try {
          final batch = _db.batch();
          for (final ref in chunk) {
            batch.delete(ref);
          }
          await batch.commit();
          deleted += chunk.length;
          debugPrint('[BURN] ✓ Batch ${i + 1}/${chunks.length} committed ($deleted total)');
          break;
        } catch (e) {
          retries++;
          if (retries >= maxRetries) {
            debugPrint('[BURN] ✗ Batch ${i + 1} failed after $maxRetries retries: $e');
            break;
          }
          debugPrint('[BURN] Batch ${i + 1} attempt $retries failed, retrying in ${retries * 2}s...');
          await Future.delayed(Duration(seconds: retries * 2));
        }
      }
    }

    debugPrint(
      '[BURN] ✓ Household $householdId: deleted ${allDocs.length} docs',
    );
  }

  /// Splits a list into chunks of the given size.
  static List<List<T>> _chunk<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, i + size > list.length ? list.length : i + size));
    }
    return chunks;
  }

  // ═══════════════════════════════════════════════════════════════════
  //  PRIVATE HELPERS — Bulk fetching & Firestore ↔ Model conversion
  // ═══════════════════════════════════════════════════════════════════

  /// Fetches subtasks for a list of task IDs, grouped by task_id.
  Future<Map<String, List<Subtask>>> _getSubtasksForTasks(
      List<String> taskIds) async {
    if (taskIds.isEmpty) return {};
    // Firestore 'whereIn' is limited to 30 items per query.
    final result = <String, List<Subtask>>{};
    for (var i = 0; i < taskIds.length; i += 30) {
      final chunk = taskIds.sublist(
          i, i + 30 > taskIds.length ? taskIds.length : i + 30);
      final snap = await _db
          .collection('subtasks')
          .where('task_id', whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final st = _subtaskFromFirestore(doc.data());
        result.putIfAbsent(st.taskId, () => []).add(st);
      }
    }
    return result;
  }

  /// Fetches categories by IDs.
  Future<Map<String, TaskCategory>> _getCategoriesByIds(
      Set<String> ids) async {
    if (ids.isEmpty) return {};
    final result = <String, TaskCategory>{};
    final idList = ids.toList();
    for (var i = 0; i < idList.length; i += 30) {
      final chunk = idList.sublist(
          i, i + 30 > idList.length ? idList.length : i + 30);
      final snap = await _db
          .collection('task_categories')
          .where('id', whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final cat = _categoryFromFirestore(doc.data());
        result[cat.id] = cat;
      }
    }
    return result;
  }

  /// Fetches profiles by UIDs.
  Future<Map<String, ProfileRef>> _getProfilesByIds(Set<String> uids) async {
    if (uids.isEmpty) return {};
    final result = <String, ProfileRef>{};
    final uidList = uids.toList();
    for (var i = 0; i < uidList.length; i += 30) {
      final chunk = uidList.sublist(
          i, i + 30 > uidList.length ? uidList.length : i + 30);
      final snap = await _db
          .collection('profiles')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        result[doc.id] = ProfileRef(
          id: doc.id,
          fullName: _decN(data['full_name'] as String?),
          avatarUrl: data['avatar_url'] as String?,
        );
      }
    }
    return result;
  }

  /// Fetches a single profile.
  Future<ProfileRef?> _getProfile(String uid) async {
    final doc = await _db.collection('profiles').doc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    return ProfileRef(
      id: uid,
      fullName: _decN(data['full_name'] as String?),
      avatarUrl: data['avatar_url'] as String?,
    );
  }

  /// Fetches checklist items grouped by checklist_id.
  Future<Map<String, List<ChecklistItem>>> _getChecklistItemsByChecklistIds(
      List<String> checklistIds) async {
    if (checklistIds.isEmpty) return {};
    final result = <String, List<ChecklistItem>>{};
    for (var i = 0; i < checklistIds.length; i += 30) {
      final chunk = checklistIds.sublist(
          i, i + 30 > checklistIds.length ? checklistIds.length : i + 30);
      final snap = await _db
          .collection('checklist_items')
          .where('checklist_id', whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final item = _checklistItemFromFirestore(doc.data());
        result.putIfAbsent(item.checklistId, () => []).add(item);
      }
    }
    return result;
  }

  /// Fetches plan entries grouped by plan_id.
  Future<Map<String, List<PlanEntry>>> _getEntriesByPlanIds(
      List<String> planIds) async {
    if (planIds.isEmpty) return {};
    final result = <String, List<PlanEntry>>{};
    for (var i = 0; i < planIds.length; i += 30) {
      final chunk =
          planIds.sublist(i, i + 30 > planIds.length ? planIds.length : i + 30);
      final snap = await _db
          .collection('plan_entries')
          .where('plan_id', whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final entry = _entryFromFirestore(doc.data());
        result.putIfAbsent(entry.planId, () => []).add(entry);
      }
    }
    return result;
  }

  /// Fetches plan checklist items grouped by plan_id.
  Future<Map<String, List<PlanChecklistItem>>> _getPlanChecklistByPlanIds(
      List<String> planIds) async {
    if (planIds.isEmpty) return {};
    final result = <String, List<PlanChecklistItem>>{};
    for (var i = 0; i < planIds.length; i += 30) {
      final chunk =
          planIds.sublist(i, i + 30 > planIds.length ? planIds.length : i + 30);
      final snap = await _db
          .collection('plan_checklist_items')
          .where('plan_id', whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final item = _planChecklistFromFirestore(doc.data());
        result.putIfAbsent(item.planId, () => []).add(item);
      }
    }
    return result;
  }

  // ── Firestore → Model conversions (with decryption) ──

  Task _taskFromFirestore(
    Map<String, dynamic> data,
    Map<String, List<Subtask>> subtasksMap,
    Map<String, TaskCategory> categoriesMap,
    Map<String, ProfileRef> profilesMap,
  ) {
    final taskId = data['id'] as String? ?? '';
    return Task(
      id: taskId,
      householdId: data['household_id'] as String? ?? '',
      title: _dec(data['title'] as String? ?? ''),
      description: _decN(data['description'] as String?),
      categoryId: data['category_id'] as String?,
      priority: data['priority'] as String? ?? 'medium',
      status: data['status'] as String? ?? 'pending',
      dueDate: _parseDate(data['due_date']),
      startDate: _parseDate(data['start_date']),
      assignedTo: data['assigned_to'] as String?,
      isShared: data['is_shared'] as bool? ?? false,
      recurrence: data['recurrence'] as String? ?? 'none',
      createdBy: data['created_by'] as String? ?? '',
      createdAt: _parseDate(data['created_at']) ?? DateTime.now(),
      completedAt: _parseDate(data['completed_at']),
      completedBy: data['completed_by'] as String?,
      category: data['category_id'] != null
          ? categoriesMap[data['category_id']]
          : null,
      assignedProfile: data['assigned_to'] != null
          ? profilesMap[data['assigned_to']]
          : null,
      creatorProfile: data['created_by'] != null
          ? profilesMap[data['created_by']]
          : null,
      subtasks: subtasksMap[taskId] ?? [],
    );
  }

  Subtask _subtaskFromFirestore(Map<String, dynamic> data) => Subtask(
        id: data['id'] as String? ?? '',
        taskId: data['task_id'] as String? ?? '',
        title: _dec(data['title'] as String? ?? ''),
        isCompleted: data['is_completed'] as bool? ?? false,
        sortOrder: data['sort_order'] as int? ?? 0,
      );

  TaskCategory _categoryFromFirestore(Map<String, dynamic> data) =>
      TaskCategory(
        id: data['id'] as String? ?? '',
        householdId: data['household_id'] as String?,
        name: _dec(data['name'] as String? ?? ''),
        icon: data['icon'] as String? ?? 'category',
        color: data['color'] as String? ?? '#7EA87E',
        isDefault: data['is_default'] as bool? ?? false,
      );

  ChecklistItem _checklistItemFromFirestore(Map<String, dynamic> data) =>
      ChecklistItem(
        id: data['id'] as String? ?? '',
        checklistId: data['checklist_id'] as String? ?? '',
        title: _dec(data['title'] as String? ?? ''),
        quantity: data['quantity'] as String?,
        isChecked: data['is_checked'] as bool? ?? false,
        createdBy: data['created_by'] as String?,
        createdAt: _parseDate(data['created_at']),
        checkedAt: _parseDate(data['checked_at']),
        checkedBy: data['checked_by'] as String?,
      );

  Plan _planFromFirestore(
    Map<String, dynamic> data,
    List<PlanEntry> entries,
    List<PlanChecklistItem> checklistItems,
  ) =>
      Plan(
        id: data['id'] as String? ?? '',
        householdId: data['household_id'] as String? ?? '',
        title: _dec(data['title'] as String? ?? ''),
        type: data['type'] as String? ?? 'weekly',
        status: data['status'] as String? ?? 'draft',
        startDate: _parseDate(data['start_date']) ?? DateTime.now(),
        endDate: _parseDate(data['end_date']) ?? DateTime.now(),
        isTemplate: data['is_template'] as bool? ?? false,
        templateName: _decN(data['template_name'] as String?),
        createdBy: data['created_by'] as String? ?? '',
        createdAt: _parseDate(data['created_at']) ?? DateTime.now(),
        updatedAt: _parseDate(data['updated_at']),
        entries: entries,
        checklistItems: checklistItems,
      );

  PlanEntry _entryFromFirestore(Map<String, dynamic> data) => PlanEntry(
        id: data['id'] as String? ?? '',
        planId: data['plan_id'] as String? ?? '',
        entryDate: _parseDate(data['entry_date']) ?? DateTime.now(),
        title: _dec(data['title'] as String? ?? ''),
        label: _decN(data['label'] as String?),
        description: _decN(data['description'] as String?),
        sortOrder: data['sort_order'] as int? ?? 0,
        createdBy: data['created_by'] as String?,
        createdAt: _parseDate(data['created_at']),
      );

  PlanChecklistItem _planChecklistFromFirestore(Map<String, dynamic> data) =>
      PlanChecklistItem(
        id: data['id'] as String? ?? '',
        planId: data['plan_id'] as String? ?? '',
        entryId: data['entry_id'] as String?,
        title: _dec(data['title'] as String? ?? ''),
        quantity: data['quantity'] as String?,
        isChecked: data['is_checked'] as bool? ?? false,
        createdBy: data['created_by'] as String?,
        createdAt: _parseDate(data['created_at']),
        checkedAt: _parseDate(data['checked_at']),
        checkedBy: data['checked_by'] as String?,
      );
}
