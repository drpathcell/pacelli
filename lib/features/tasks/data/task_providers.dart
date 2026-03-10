import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/data_repository_provider.dart';
import '../../../core/models/attachment.dart';

/// Provider for all tasks in the household.
/// Pass the householdId to fetch tasks.
final householdTasksProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, householdId) async {
    final repo = ref.watch(dataRepositoryProvider);
    final tasks = await repo.getTasks(householdId: householdId);
    return tasks.map((t) => t.toDisplayMap()).toList();
  },
);

/// Provider for a single task by ID.
final taskDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
  (ref, taskId) async {
    final repo = ref.watch(dataRepositoryProvider);
    final task = await repo.getTask(taskId);
    return task.toDisplayMap();
  },
);

/// Provider for task categories in a household.
final taskCategoriesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, householdId) async {
    final repo = ref.watch(dataRepositoryProvider);
    final categories = await repo.getCategories(householdId);
    return categories.map((c) => c.toMap()).toList();
  },
);

/// Provider for task attachments.
final taskAttachmentsProvider =
    FutureProvider.family<List<TaskAttachment>, String>(
  (ref, taskId) async {
    final repo = ref.watch(dataRepositoryProvider);
    return repo.getTaskAttachments(taskId);
  },
);

/// Provider for task stats (completed, pending, overdue counts).
final taskStatsProvider =
    FutureProvider.family<Map<String, int>, String>(
  (ref, householdId) async {
    final repo = ref.watch(dataRepositoryProvider);
    final stats = await repo.getTaskStats(householdId);
    return {
      'completed': stats.completed,
      'pending': stats.pending,
      'overdue': stats.overdue,
    };
  },
);
