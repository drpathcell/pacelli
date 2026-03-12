import 'package:equatable/equatable.dart';

import 'attachment.dart';

/// A task within a household.
class Task extends Equatable {
  final String id;
  final String householdId;
  final String title;
  final String? description;
  final String? categoryId;
  final String priority; // 'low', 'medium', 'high', 'urgent'
  final String status; // 'pending', 'in_progress', 'completed'
  final DateTime? dueDate;
  final DateTime? startDate;
  final String? assignedTo;
  final bool isShared;
  final String recurrence; // 'none', 'daily', 'weekly', 'monthly'
  final String createdBy;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? completedBy;

  // Joined / denormalized fields (from profiles, categories)
  final TaskCategory? category;
  final ProfileRef? assignedProfile;
  final ProfileRef? creatorProfile;
  final List<Subtask> subtasks;
  final List<TaskAttachment> attachments;

  const Task({
    required this.id,
    required this.householdId,
    required this.title,
    this.description,
    this.categoryId,
    this.priority = 'medium',
    this.status = 'pending',
    this.dueDate,
    this.startDate,
    this.assignedTo,
    this.isShared = false,
    this.recurrence = 'none',
    required this.createdBy,
    required this.createdAt,
    this.completedAt,
    this.completedBy,
    this.category,
    this.assignedProfile,
    this.creatorProfile,
    this.subtasks = const [],
    this.attachments = const [],
  });

  /// Creates a Task from a data map (with nested joins/lookups).
  factory Task.fromMap(Map<String, dynamic> map) {
    final categoryMap = map['task_categories'] as Map<String, dynamic>?;
    final assignedMap = map['assigned'] as Map<String, dynamic>?;
    final creatorMap = map['creator'] as Map<String, dynamic>?;
    final subtaskList = map['subtasks'] as List<dynamic>? ?? [];

    return Task(
      id: map['id'] as String,
      householdId: map['household_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      categoryId: map['category_id'] as String?,
      priority: map['priority'] as String? ?? 'medium',
      status: map['status'] as String? ?? 'pending',
      dueDate: _parseDate(map['due_date']),
      startDate: _parseDate(map['start_date']),
      assignedTo: map['assigned_to'] as String?,
      isShared: map['is_shared'] as bool? ?? false,
      recurrence: map['recurrence'] as String? ?? 'none',
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      completedAt: _parseDate(map['completed_at']),
      completedBy: map['completed_by'] as String?,
      category:
          categoryMap != null ? TaskCategory.fromMap(categoryMap) : null,
      assignedProfile:
          assignedMap != null ? ProfileRef.fromMap(assignedMap) : null,
      creatorProfile:
          creatorMap != null ? ProfileRef.fromMap(creatorMap) : null,
      subtasks: subtaskList
          .map((s) => Subtask.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList(),
    );
  }

  /// Converts to a flat map for database storage (no nested objects).
  Map<String, dynamic> toMap() => {
        'id': id,
        'household_id': householdId,
        'title': title,
        'description': description,
        'category_id': categoryId,
        'priority': priority,
        'status': status,
        'due_date': dueDate?.toIso8601String(),
        'start_date': startDate?.toIso8601String(),
        'assigned_to': assignedTo,
        'is_shared': isShared,
        'recurrence': recurrence,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'completed_by': completedBy,
      };

  /// Convenience: converts back to the `Map<String, dynamic>` shape the UI
  /// currently expects (with nested 'task_categories', 'assigned', etc.).
  Map<String, dynamic> toDisplayMap() => {
        ...toMap(),
        'task_categories': category?.toMap(),
        'assigned': assignedProfile?.toMap(),
        'creator': creatorProfile?.toMap(),
        'subtasks': subtasks.map((s) => s.toMap()).toList(),
      };

  Task copyWith({
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
    DateTime? completedAt,
    String? completedBy,
    TaskCategory? category,
    ProfileRef? assignedProfile,
    ProfileRef? creatorProfile,
    List<Subtask>? subtasks,
    List<TaskAttachment>? attachments,
  }) {
    return Task(
      id: id,
      householdId: householdId,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      startDate: startDate ?? this.startDate,
      assignedTo: assignedTo ?? this.assignedTo,
      isShared: isShared ?? this.isShared,
      recurrence: recurrence ?? this.recurrence,
      createdBy: createdBy,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      category: category ?? this.category,
      assignedProfile: assignedProfile ?? this.assignedProfile,
      creatorProfile: creatorProfile ?? this.creatorProfile,
      subtasks: subtasks ?? this.subtasks,
      attachments: attachments ?? this.attachments,
    );
  }

  @override
  List<Object?> get props => [id, status, completedAt];

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value as String);
  }
}

/// A subtask belonging to a parent Task.
class Subtask extends Equatable {
  final String id;
  final String taskId;
  final String householdId;
  final String title;
  final bool isCompleted;
  final int sortOrder;

  const Subtask({
    required this.id,
    required this.taskId,
    this.householdId = '',
    required this.title,
    this.isCompleted = false,
    this.sortOrder = 0,
  });

  factory Subtask.fromMap(Map<String, dynamic> map) => Subtask(
        id: map['id'] as String,
        taskId: map['task_id'] as String? ?? '',
        householdId: map['household_id'] as String? ?? '',
        title: map['title'] as String,
        isCompleted: map['is_completed'] as bool? ?? false,
        sortOrder: map['sort_order'] as int? ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'task_id': taskId,
        'household_id': householdId,
        'title': title,
        'is_completed': isCompleted,
        'sort_order': sortOrder,
      };

  @override
  List<Object?> get props => [id, isCompleted];
}

/// Lightweight reference to a profile (used for assigned/creator joins).
class ProfileRef extends Equatable {
  final String id;
  final String? fullName;
  final String? avatarUrl;

  const ProfileRef({
    required this.id,
    this.fullName,
    this.avatarUrl,
  });

  factory ProfileRef.fromMap(Map<String, dynamic> map) => ProfileRef(
        id: map['id'] as String,
        fullName: map['full_name'] as String?,
        avatarUrl: map['avatar_url'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'full_name': fullName,
        'avatar_url': avatarUrl,
      };

  @override
  List<Object?> get props => [id];
}

/// A task category.
class TaskCategory extends Equatable {
  final String id;
  final String? householdId;
  final String name;
  final String icon;
  final String color;
  final bool isDefault;

  const TaskCategory({
    required this.id,
    this.householdId,
    required this.name,
    this.icon = 'category',
    this.color = '#7EA87E',
    this.isDefault = false,
  });

  factory TaskCategory.fromMap(Map<String, dynamic> map) => TaskCategory(
        id: map['id'] as String,
        householdId: map['household_id'] as String?,
        name: map['name'] as String,
        icon: map['icon'] as String? ?? 'category',
        color: map['color'] as String? ?? '#7EA87E',
        isDefault: map['is_default'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'household_id': householdId,
        'name': name,
        'icon': icon,
        'color': color,
        'is_default': isDefault,
      };

  @override
  List<Object?> get props => [id];
}

/// Task statistics for the household dashboard.
class TaskStats extends Equatable {
  final int completed;
  final int pending;
  final int overdue;

  const TaskStats({
    this.completed = 0,
    this.pending = 0,
    this.overdue = 0,
  });

  int get total => completed + pending;

  double get completionRate =>
      total == 0 ? 0.0 : completed / total;

  factory TaskStats.fromMap(Map<String, dynamic> map) => TaskStats(
        completed: map['completed'] as int? ?? 0,
        pending: map['pending'] as int? ?? 0,
        overdue: map['overdue'] as int? ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'completed': completed,
        'pending': pending,
        'overdue': overdue,
      };

  @override
  List<Object?> get props => [completed, pending, overdue];
}
