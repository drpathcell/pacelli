import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter/services.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../../core/utils/extensions.dart';
import '../../../household/data/household_providers.dart';
import '../../data/task_providers.dart';
import '../../utils/task_helpers.dart';
import '../../../../core/data/data_repository_provider.dart';

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
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
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
      loading: () => Scaffold(
        body: LoadingView(message: context.l10n.tasksLoadingHousehold),
      ),
      error: (_, __) => Scaffold(
        body: Center(child: Text(context.l10n.tasksFailedToLoadHousehold)),
      ),
      data: (data) {
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.tasksTitle)),
            body: Center(child: Text(context.l10n.tasksCreateHouseholdFirst)),
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

class _TasksBody extends ConsumerStatefulWidget {
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
  ConsumerState<_TasksBody> createState() => _TasksBodyState();
}

class _TasksBodyState extends ConsumerState<_TasksBody> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _showAllCategories(
    BuildContext context,
    List<Map<String, dynamic>> categories,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                context.l10n.tasksAllCategories,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...categories.map((cat) => ListTile(
                  leading: const Icon(Icons.label_outline, size: 20),
                  title: Text(cat['name'] as String),
                  selected: widget.selectedCategory == cat['id'],
                  onTap: () {
                    widget.onCategoryChanged(
                      widget.selectedCategory == cat['id']
                          ? null
                          : cat['id'] as String,
                    );
                    Navigator.of(ctx).pop();
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(householdTasksProvider(widget.householdId));
    final categoriesAsync = ref.watch(taskCategoriesProvider(widget.householdId));

    return Stack(
      children: [
        Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.tasksTitle),
        bottom: TabBar(
          controller: widget.tabController,
          tabs: [
            Tab(text: context.l10n.tasksFilterAll),
            Tab(text: context.l10n.tasksFilterPending),
            Tab(text: context.l10n.tasksFilterDone),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton(
          onPressed: () => context.push('${AppRoutes.tasks}/create',
              extra: widget.householdId),
          backgroundColor: context.colorScheme.primary,
          child: const Icon(Icons.add_rounded, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // Category filter chips — top 5 by usage + More
          categoriesAsync.when(
            loading: () => const SizedBox(height: 56),
            error: (_, __) => const SizedBox.shrink(),
            data: (categories) {
              // Count usage per category from tasks
              final tasks = tasksAsync.valueOrNull ?? [];
              final usageCount = <String, int>{};
              for (final t in tasks) {
                final catId = t['category_id'] as String?;
                if (catId != null) {
                  usageCount[catId] = (usageCount[catId] ?? 0) + 1;
                }
              }
              // Sort categories by usage (desc), then take top 5
              final sorted = List<Map<String, dynamic>>.from(categories)
                ..sort((a, b) => (usageCount[b['id']] ?? 0)
                    .compareTo(usageCount[a['id']] ?? 0));
              final top5 = sorted.take(5).toList();
              final hasMore = categories.length > 5;

              return SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    FilterChip(
                      label: Text(context.l10n.tasksFilterAll),
                      selected: widget.selectedCategory == null,
                      onSelected: (_) => widget.onCategoryChanged(null),
                    ),
                    const SizedBox(width: 8),
                    ...top5.map((cat) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(cat['name'] as String),
                            selected: widget.selectedCategory == cat['id'],
                            onSelected: (_) => widget.onCategoryChanged(
                              widget.selectedCategory == cat['id']
                                  ? null
                                  : cat['id'] as String,
                            ),
                          ),
                        )),
                    if (hasMore)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          avatar: const Icon(Icons.more_horiz, size: 18),
                          label: Text(context.l10n.tasksMore),
                          onPressed: () => _showAllCategories(
                            context,
                            categories,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          // Task list
          Expanded(
            child: tasksAsync.when(
              skipLoadingOnRefresh: true,
              skipLoadingOnReload: true,
              loading: () => const TaskListSkeleton(),
              error: (e, _) => ErrorView(
                message: context.l10n.tasksCouldNotLoad,
                onRetry: () =>
                    ref.invalidate(householdTasksProvider(widget.householdId)),
              ),
              data: (tasks) {
                // Filter by category
                var filtered = widget.selectedCategory == null
                    ? tasks
                    : tasks
                        .where(
                            (t) => t['category_id'] == widget.selectedCategory)
                        .toList();

                return TabBarView(
                  controller: widget.tabController,
                  children: [
                    _TaskList(
                      tasks: filtered,
                      householdId: widget.householdId,
                      emptyMessage: context.l10n.tasksNoTasksYet,
                      onTaskCompleted: () => _confettiController.play(),
                    ),
                    _TaskList(
                      tasks: filtered
                          .where((t) => t['status'] != 'completed')
                          .toList(),
                      householdId: widget.householdId,
                      emptyMessage: context.l10n.tasksAllCaughtUp,
                      onTaskCompleted: () => _confettiController.play(),
                    ),
                    _TaskList(
                      tasks: filtered
                          .where((t) => t['status'] == 'completed')
                          .toList(),
                      householdId: widget.householdId,
                      emptyMessage: context.l10n.tasksNoCompletedYet,
                      onTaskCompleted: () => _confettiController.play(),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
        ),
        // ── Confetti overlay ────────────────────────
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: pi / 2,
            blastDirectionality: BlastDirectionality.explosive,
            maxBlastForce: 20,
            minBlastForce: 8,
            emissionFrequency: 0.05,
            numberOfParticles: 25,
            gravity: 0.2,
            shouldLoop: false,
            colors: const [
              AppColors.primaryLight,
              AppColors.accentLight,
              AppColors.success,
              AppColors.warning,
              AppColors.info,
              Color(0xFFE88B5A),
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskList extends ConsumerWidget {
  final List<Map<String, dynamic>> tasks;
  final String householdId;
  final String emptyMessage;
  final VoidCallback? onTaskCompleted;

  const _TaskList({
    required this.tasks,
    required this.householdId,
    required this.emptyMessage,
    this.onTaskCompleted,
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
                color: context.colorScheme.primary.withValues(alpha: 0.3),
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return _TaskCard(
            key: ValueKey(task['id']),
            task: task,
            householdId: householdId,
            onCompleted: onTaskCompleted,
          );
        },
      ),
    );
  }
}

class _TaskCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> task;
  final String householdId;
  final VoidCallback? onCompleted;

  const _TaskCard({
    super.key,
    required this.task,
    required this.householdId,
    this.onCompleted,
  });

  @override
  ConsumerState<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends ConsumerState<_TaskCard> {
  bool? _optimisticCompleted;

  @override
  void didUpdateWidget(covariant _TaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset optimistic state when real data catches up
    if (oldWidget.task['status'] != widget.task['status']) {
      _optimisticCompleted = null;
    }
  }

  Future<void> _toggleCompletion(bool wasCompleted) async {
    // Optimistic: show new state immediately
    setState(() => _optimisticCompleted = !wasCompleted);
    HapticFeedback.lightImpact();

    try {
      if (wasCompleted) {
        await ref.read(dataRepositoryProvider).reopenTask(widget.task['id'] as String);
      } else {
        await ref.read(dataRepositoryProvider).completeTask(widget.task['id'] as String);
        widget.onCompleted?.call();
      }
      ref.invalidate(householdTasksProvider(widget.householdId));
      ref.invalidate(taskStatsProvider(widget.householdId));
    } catch (_) {
      // Revert on failure
      if (mounted) setState(() => _optimisticCompleted = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final realCompleted = widget.task['status'] == 'completed';
    final isCompleted = _optimisticCompleted ?? realCompleted;
    final priority = widget.task['priority'] as String?;
    final category = widget.task['task_categories'] as Map<String, dynamic>?;
    final assigned = widget.task['assigned'] as Map<String, dynamic>?;
    final isShared = widget.task['is_shared'] as bool? ?? false;
    final subtasks = widget.task['subtasks'] as List<dynamic>? ?? [];
    final completedSubtasks =
        subtasks.where((s) => s['is_completed'] == true).length;

    final dueDateStr = widget.task['due_date'] as String?;
    DateTime? dueDate;
    if (dueDateStr != null) dueDate = DateTime.tryParse(dueDateStr);
    final isOverdue =
        dueDate != null && !isCompleted && dueDate.isOverdue;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('${AppRoutes.tasks}/${widget.task['id']}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Completion checkbox — optimistic
              GestureDetector(
                onTap: () => _toggleCompletion(realCompleted),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
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
                          : priorityColor(priority),
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
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isCompleted ? 0.5 : 1.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: 'task-title-${widget.task['id']}',
                        child: Material(
                          color: Colors.transparent,
                          child: Text(
                            widget.task['title'] as String,
                            style: context.textTheme.titleMedium?.copyWith(
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: isCompleted
                                  ? AppColors.textSecondaryLight
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          if (category != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  categoryIcon(category['icon'] as String?),
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
                                      ? context.l10n.commonShared
                                      : (assigned?['full_name']
                                              as String? ??
                                          context.l10n.commonUnassigned),
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
                                      ? context.l10n.commonToday
                                      : dueDate.isTomorrow
                                          ? context.l10n.commonTomorrow
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
              ),

              // Priority indicator
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: priorityColor(priority),
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
