import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/task_providers.dart';
import '../../data/task_service.dart';

/// Screen showing full task details with subtasks.
class TaskDetailScreen extends ConsumerStatefulWidget {
  final String taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  final _subtaskController = TextEditingController();

  @override
  void dispose() {
    _subtaskController.dispose();
    super.dispose();
  }

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

  String _priorityLabel(String? priority) {
    switch (priority) {
      case 'urgent':
        return 'Urgent';
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      default:
        return 'None';
    }
  }

  String _recurrenceLabel(String? recurrence) {
    switch (recurrence) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'biweekly':
        return 'Every 2 weeks';
      case 'monthly':
        return 'Monthly';
      default:
        return 'Never';
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

  Future<void> _addSubtask() async {
    final text = _subtaskController.text.trim();
    if (text.isEmpty) return;

    await TaskService.addSubtask(taskId: widget.taskId, title: text);
    _subtaskController.clear();
    ref.invalidate(taskDetailProvider(widget.taskId));
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(taskDetailProvider(widget.taskId));

    return taskAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (task) {
        final isCompleted = task['status'] == 'completed';
        final priority = task['priority'] as String?;
        final category = task['task_categories'] as Map<String, dynamic>?;
        final assigned = task['assigned'] as Map<String, dynamic>?;
        final creator = task['creator'] as Map<String, dynamic>?;
        final isShared = task['is_shared'] as bool? ?? false;
        final recurrence = task['recurrence'] as String?;
        final description = task['description'] as String?;
        final householdId = task['household_id'] as String;

        final dueDateStr = task['due_date'] as String?;
        DateTime? dueDate;
        if (dueDateStr != null) dueDate = DateTime.tryParse(dueDateStr);
        final isOverdue = dueDate != null && !isCompleted && dueDate.isOverdue;

        final subtasks = List<Map<String, dynamic>>.from(
            (task['subtasks'] as List<dynamic>?) ?? []);
        subtasks.sort((a, b) =>
            (a['sort_order'] as int).compareTo(b['sort_order'] as int));

        final completedSubtasks =
            subtasks.where((s) => s['is_completed'] == true).length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Task Details'),
            actions: [
              // Delete
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete task?'),
                      content: const Text(
                          'This will permanently delete this task and all its subtasks.'),
                      actions: [
                        TextButton(
                          onPressed: () => ctx.pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => ctx.pop(true),
                          child: const Text('Delete',
                              style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && mounted) {
                    await TaskService.deleteTask(widget.taskId);
                    ref.invalidate(householdTasksProvider(householdId));
                    ref.invalidate(taskStatsProvider(householdId));
                    if (mounted) context.pop();
                  }
                },
              ),
            ],
          ),
          // Complete / Reopen button
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (isCompleted) {
                    await TaskService.reopenTask(widget.taskId);
                  } else {
                    await TaskService.completeTask(widget.taskId);
                  }
                  ref.invalidate(taskDetailProvider(widget.taskId));
                  ref.invalidate(householdTasksProvider(householdId));
                  ref.invalidate(taskStatsProvider(householdId));
                },
                icon: Icon(isCompleted
                    ? Icons.replay
                    : Icons.check_circle_outline),
                label: Text(isCompleted ? 'Reopen Task' : 'Mark Complete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isCompleted ? AppColors.warning : AppColors.success,
                ),
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Title & Status ────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task['title'] as String,
                      style: context.textTheme.headlineSmall?.copyWith(
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppColors.success.withOpacity(0.15)
                          : _priorityColor(priority).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isCompleted ? 'Completed' : _priorityLabel(priority),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: isCompleted
                            ? AppColors.success
                            : _priorityColor(priority),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Description ───────────────────────────────
              if (description != null && description.isNotEmpty) ...[
                Text(description,
                    style: context.textTheme.bodyLarge),
                const SizedBox(height: 16),
              ],

              // ── Details card ──────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (category != null)
                        _DetailRow(
                          icon: _categoryIcon(category['icon'] as String?),
                          label: 'Category',
                          value: category['name'] as String,
                        ),
                      if (dueDate != null)
                        _DetailRow(
                          icon: Icons.calendar_today,
                          label: 'Due',
                          value: dueDate.isToday
                              ? 'Today'
                              : dueDate.isTomorrow
                                  ? 'Tomorrow'
                                  : dueDate.formattedWithTime,
                          valueColor:
                              isOverdue ? AppColors.error : null,
                        ),
                      _DetailRow(
                        icon: isShared
                            ? Icons.people_outline
                            : Icons.person_outline,
                        label: 'Assigned to',
                        value: isShared
                            ? 'Shared (both)'
                            : (assigned?['full_name'] as String? ??
                                'Unassigned'),
                      ),
                      if (recurrence != null && recurrence != 'none')
                        _DetailRow(
                          icon: Icons.repeat,
                          label: 'Repeats',
                          value: _recurrenceLabel(recurrence),
                        ),
                      _DetailRow(
                        icon: Icons.person,
                        label: 'Created by',
                        value:
                            creator?['full_name'] as String? ?? 'Unknown',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Subtasks ──────────────────────────────────
              Row(
                children: [
                  Text('Subtasks',
                      style: context.textTheme.titleMedium),
                  if (subtasks.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      '$completedSubtasks/${subtasks.length}',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // Subtask progress bar
              if (subtasks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(
                    value: subtasks.isEmpty
                        ? 0
                        : completedSubtasks / subtasks.length,
                    backgroundColor: AppColors.textSecondaryLight
                        .withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.success),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),

              // Subtask items
              ...subtasks.map((st) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: st['is_completed'] as bool,
                    title: Text(
                      st['title'] as String,
                      style: (st['is_completed'] as bool)
                          ? const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: AppColors.textSecondaryLight,
                            )
                          : null,
                    ),
                    secondary: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () async {
                        await TaskService.deleteSubtask(st['id']);
                        ref.invalidate(
                            taskDetailProvider(widget.taskId));
                      },
                    ),
                    onChanged: (v) async {
                      await TaskService.toggleSubtask(
                        subtaskId: st['id'],
                        isCompleted: v ?? false,
                      );
                      ref.invalidate(
                          taskDetailProvider(widget.taskId));
                    },
                  )),

              // Add subtask
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subtaskController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Add a subtask...',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.add, size: 20),
                      ),
                      onSubmitted: (_) => _addSubtask(),
                    ),
                  ),
                  TextButton(
                    onPressed: _addSubtask,
                    child: const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondaryLight),
          const SizedBox(width: 12),
          Text(label,
              style: context.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondaryLight)),
          const Spacer(),
          Text(value,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: valueColor,
              )),
        ],
      ),
    );
  }
}
