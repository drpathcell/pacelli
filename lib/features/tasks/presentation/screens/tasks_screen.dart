import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../../household/data/household_providers.dart';
import '../../data/task_providers.dart';
import '../../data/task_service.dart';

/// Tasks screen — shows all household tasks with filters.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final householdAsync = ref.watch(currentHouseholdProvider);

    return householdAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Scaffold(
        body: Center(child: Text('Failed to load household')),
      ),
      data: (data) {
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Tasks')),
            body: const Center(child: Text('Create a household first')),
          );
        }

        final household = data['household'] as Map<String, dynamic>;
        final householdId = household['id'] as String;

        return _TasksBody(
          householdId: householdId,
          tabController: _tabController,
          selectedCategory: _selectedCategory,
          onCategoryChanged: (cat) =>
              setState(() => _selectedCategory = cat),
        );
      },
    );
  }
}

class _TasksBody extends ConsumerWidget {
  final String householdId;
  final TabController tabController;
  final String? selectedCategory;
  final ValueChanged<String?> onCategoryChanged;

  const _TasksBody({
    required this.householdId,
    required this.tabController,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(householdTasksProvider(householdId));
    final categoriesAsync = ref.watch(taskCategoriesProvider(householdId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Pending'),
            Tab(text: 'Done'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('${AppRoutes.tasks}/create',
            extra: householdId),
        backgroundColor: context.colorScheme.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: Column(
        children: [
          // Category filter chips
          categoriesAsync.when(
            loading: () => const SizedBox(height: 56),
            error: (_, __) => const SizedBox.shrink(),
            data: (categories) => SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: selectedCategory == null,
                    onSelected: (_) => onCategoryChanged(null),
                  ),
                  const SizedBox(width: 8),
                  ...categories.map((cat) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(cat['name'] as String),
                          selected: selectedCategory == cat['id'],
                          onSelected: (_) => onCategoryChanged(
                            selectedCategory == cat['id']
                                ? null
                                : cat['id'] as String,
                          ),
                        ),
                      )),
                ],
              ),
            ),
          ),

          // Task list
          Expanded(
            child: tasksAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Error loading tasks: $e')),
              data: (tasks) {
                // Filter by category
                var filtered = selectedCategory == null
                    ? tasks
                    : tasks
                        .where(
                            (t) => t['category_id'] == selectedCategory)
                        .toList();

                return TabBarView(
                  controller: tabController,
                  children: [
                    _TaskList(
                      tasks: filtered,
                      householdId: householdId,
                      emptyMessage: 'No tasks yet.\nTap + to create one!',
                    ),
                    _TaskList(
                      tasks: filtered
                          .where((t) => t['status'] != 'completed')
                          .toList(),
                      householdId: householdId,
                      emptyMessage: 'All caught up!',
                    ),
                    _TaskList(
                      tasks: filtered
                          .where((t) => t['status'] == 'completed')
                          .toList(),
                      householdId: householdId,
                      emptyMessage: 'No completed tasks yet.',
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskList extends ConsumerWidget {
  final List<Map<String, dynamic>> tasks;
  final String householdId;
  final String emptyMessage;

  const _TaskList({
    required this.tasks,
    required this.householdId,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 64,
                color: context.colorScheme.primary.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                style: context.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(householdTasksProvider(householdId));
        ref.invalidate(taskStatsProvider(householdId));
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return _TaskCard(task: task, householdId: householdId);
        },
      ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  final Map<String, dynamic> task;
  final String householdId;

  const _TaskCard({required this.task, required this.householdId});

  Color _priorityColor(String? priority) {
    switch (priority) {
      case 'urgent':
        return AppColors.error;
      case 'high':
        return const Color(0xFFE88B5A);
      case 'medium':
        return AppColors.warning;
      case 'low':
        return AppColors.info;
      default:
        return AppColors.textSecondaryLight;
    }
  }

  IconData _categoryIcon(String? iconName) {
    switch (iconName) {
      case 'cleaning_services':
        return Icons.cleaning_services;
      case 'restaurant':
        return Icons.restaurant;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'local_laundry_service':
        return Icons.local_laundry_service;
      case 'receipt_long':
        return Icons.receipt_long;
      case 'build':
        return Icons.build;
      case 'directions_run':
        return Icons.directions_run;
      case 'more_horiz':
        return Icons.more_horiz;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCompleted = task['status'] == 'completed';
    final priority = task['priority'] as String?;
    final category = task['task_categories'] as Map<String, dynamic>?;
    final assigned = task['assigned'] as Map<String, dynamic>?;
    final isShared = task['is_shared'] as bool? ?? false;
    final subtasks = task['subtasks'] as List<dynamic>? ?? [];
    final completedSubtasks =
        subtasks.where((s) => s['is_completed'] == true).length;

    final dueDateStr = task['due_date'] as String?;
    DateTime? dueDate;
    if (dueDateStr != null) dueDate = DateTime.tryParse(dueDateStr);
    final isOverdue =
        dueDate != null && !isCompleted && dueDate.isOverdue;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('${AppRoutes.tasks}/${task['id']}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Completion checkbox
              GestureDetector(
                onTap: () async {
                  if (isCompleted) {
                    await TaskService.reopenTask(task['id']);
                  } else {
                    await TaskService.completeTask(task['id']);
                  }
                  ref.invalidate(householdTasksProvider(householdId));
                  ref.invalidate(taskStatsProvider(householdId));
                },
                child: Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? AppColors.success
                        : Colors.transparent,
                    border: Border.all(
                      color: isCompleted
                          ? AppColors.success
                          : _priorityColor(priority),
                      width: 2,
                    ),
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 12),

              // Task content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      task['title'] as String,
                      style: context.textTheme.titleMedium?.copyWith(
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: isCompleted
                            ? AppColors.textSecondaryLight
                            : null,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Meta row: category + assignee + due date
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (category != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _categoryIcon(category['icon'] as String?),
                                size: 14,
                                color: AppColors.textSecondaryLight,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                category['name'] as String,
                                style:
                                    context.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        if (assigned != null || isShared)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isShared
                                    ? Icons.people_outline
                                    : Icons.person_outline,
                                size: 14,
                                color: AppColors.textSecondaryLight,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isShared
                                    ? 'Shared'
                                    : (assigned?['full_name']
                                            as String? ??
                                        'Unassigned'),
                                style:
                                    context.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        if (dueDate != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 14,
                                color: isOverdue
                                    ? AppColors.error
                                    : AppColors.textSecondaryLight,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dueDate.isToday
                                    ? 'Today'
                                    : dueDate.isTomorrow
                                        ? 'Tomorrow'
                                        : dueDate.formatted,
                                style:
                                    context.textTheme.bodySmall?.copyWith(
                                  color: isOverdue
                                      ? AppColors.error
                                      : AppColors.textSecondaryLight,
                                  fontWeight: isOverdue
                                      ? FontWeight.w600
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        if (subtasks.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.checklist,
                                size: 14,
                                color: AppColors.textSecondaryLight,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$completedSubtasks/${subtasks.length}',
                                style:
                                    context.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Priority indicator
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: _priorityColor(priority),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
