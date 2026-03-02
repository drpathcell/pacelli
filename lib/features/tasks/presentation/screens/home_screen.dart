import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/extensions.dart';
import '../../../household/data/household_providers.dart';
import '../../data/task_providers.dart';

/// Home screen — the main hub of the Pacelli app.
///
/// Shows the user's household dashboard if they have a household,
/// or prompts them to create one if they don't.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = currentUser?.userMetadata?['full_name'] ?? 'Friend';
    final householdAsync = ref.watch(currentHouseholdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, $userName',
              style: context.textTheme.titleLarge,
            ),
            Text(
              DateTime.now().formatted,
              style: context.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
      body: householdAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Something went wrong', style: context.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(currentHouseholdProvider),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
        data: (data) {
          if (data == null) {
            return _NoHouseholdView();
          }

          final household = data['household'] as Map<String, dynamic>;
          return _HouseholdDashboard(
            householdId: household['id'] as String,
            householdName: household['name'] ?? 'My Household',
          );
        },
      ),
    );
  }
}

/// Shown when the user hasn't joined a household yet.
class _NoHouseholdView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.home_rounded,
              size: 80,
              color: context.colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to Pacelli!',
              style: context.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your household tasks will appear here.\nLet\'s start by creating your household.',
              style: context.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.push(AppRoutes.createHousehold),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Household'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashboard view shown when the user has a household.
class _HouseholdDashboard extends ConsumerWidget {
  final String householdId;
  final String householdName;

  const _HouseholdDashboard({
    required this.householdId,
    required this.householdName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(taskStatsProvider(householdId));
    final tasksAsync = ref.watch(householdTasksProvider(householdId));

    final stats = statsAsync.valueOrNull ??
        {'completed': 0, 'pending': 0, 'overdue': 0};

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(taskStatsProvider(householdId));
        ref.invalidate(householdTasksProvider(householdId));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Household card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.home_rounded,
                    size: 32,
                    color: context.colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(householdName,
                            style: context.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          'Your household is set up!',
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Stats
          Text("Today's Overview",
              style: context.textTheme.titleLarge),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle_outline,
                  label: 'Completed',
                  value: '${stats['completed']}',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.pending_outlined,
                  label: 'Pending',
                  value: '${stats['pending']}',
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.warning_amber_outlined,
                  label: 'Overdue',
                  value: '${stats['overdue']}',
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Recent tasks
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Tasks', style: context.textTheme.titleLarge),
              TextButton(
                onPressed: () => context.go(AppRoutes.tasks),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          tasksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text('Failed to load tasks'),
            data: (tasks) {
              final recentTasks = tasks
                  .where((t) => t['status'] != 'completed')
                  .take(5)
                  .toList();

              if (recentTasks.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            "No tasks yet — they'll show up here once you create some!",
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondaryLight,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => context.push(
                                '${AppRoutes.tasks}/create',
                                extra: householdId),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Create Task'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: recentTasks
                    .map((task) => _RecentTaskTile(
                          task: task,
                          householdId: householdId,
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RecentTaskTile extends ConsumerWidget {
  final Map<String, dynamic> task;
  final String householdId;

  const _RecentTaskTile({
    required this.task,
    required this.householdId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dueDateStr = task['due_date'] as String?;
    DateTime? dueDate;
    if (dueDateStr != null) dueDate = DateTime.tryParse(dueDateStr);
    final isOverdue = dueDate != null && dueDate.isOverdue;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.push('${AppRoutes.tasks}/${task['id']}'),
        leading: Icon(
          Icons.circle_outlined,
          color: isOverdue ? AppColors.error : AppColors.textSecondaryLight,
        ),
        title: Text(task['title'] as String),
        subtitle: dueDate != null
            ? Text(
                dueDate.isToday
                    ? 'Due today'
                    : dueDate.isTomorrow
                        ? 'Due tomorrow'
                        : 'Due ${dueDate.formatted}',
                style: TextStyle(
                  color: isOverdue ? AppColors.error : null,
                  fontWeight: isOverdue ? FontWeight.w600 : null,
                ),
              )
            : null,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: context.textTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: context.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
