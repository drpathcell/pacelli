import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'task_service.dart';

/// Provider for all tasks in the household.
/// Pass the householdId to fetch tasks.
final householdTasksProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, householdId) => TaskService.getTasks(householdId: householdId),
);

/// Provider for a single task by ID.
final taskDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
  (ref, taskId) => TaskService.getTask(taskId),
);

/// Provider for task categories in a household.
final taskCategoriesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, householdId) => TaskService.getCategories(householdId),
);

/// Provider for task stats (completed, pending, overdue counts).
final taskStatsProvider =
    FutureProvider.family<Map<String, int>, String>(
  (ref, householdId) => TaskService.getTaskStats(householdId),
);
