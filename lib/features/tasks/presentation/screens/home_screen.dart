import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../household/data/household_providers.dart';
import '../../data/task_providers.dart';
import '../../../../core/data/data_repository_provider.dart';
import '../../utils/task_helpers.dart';

/// Home screen — the main hub of the Pacelli app.
///
/// Shows the user's household dashboard if they have a household,
/// or prompts them to create one if they don't.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = FirebaseAuth.instance.currentUser?.displayName ?? 'Friend';
    final householdAsync = ref.watch(currentHouseholdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.homeHelloGreeting(userName),
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
        loading: () => LoadingView(message: context.l10n.homeLoadingHousehold),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(context.l10n.homeSomethingWentWrong, style: context.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(currentHouseholdProvider),
                child: Text(context.l10n.homeTryAgain),
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
            householdName: household['name'] ?? context.l10n.homeMyHousehold,
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
              context.l10n.homeWelcomeToPacelli,
              style: context.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.homeWelcomeSubtitle,
              style: context.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.push(AppRoutes.createHousehold),
              icon: const Icon(Icons.add_rounded),
              label: Text(context.l10n.homeCreateHousehold),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashboard view shown when the user has a household.
class _HouseholdDashboard extends ConsumerStatefulWidget {
  final String householdId;
  final String householdName;

  const _HouseholdDashboard({
    required this.householdId,
    required this.householdName,
  });

  @override
  ConsumerState<_HouseholdDashboard> createState() =>
      _HouseholdDashboardState();
}

class _HouseholdDashboardState extends ConsumerState<_HouseholdDashboard> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(milliseconds: 1200));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(taskStatsProvider(widget.householdId));
    final tasksAsync = ref.watch(householdTasksProvider(widget.householdId));

    final stats = statsAsync.valueOrNull ??
        {'completed': 0, 'pending': 0, 'overdue': 0};

    return Stack(
      children: [
        RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(taskStatsProvider(widget.householdId));
        ref.invalidate(householdTasksProvider(widget.householdId));
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
                        Text(widget.householdName,
                            style: context.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.homeHouseholdSetUp,
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
          Text(context.l10n.homeTodaysOverview,
              style: context.textTheme.titleLarge),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle_outline,
                  label: context.l10n.homeCompleted,
                  value: '${stats['completed']}',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.pending_outlined,
                  label: context.l10n.homePending,
                  value: '${stats['pending']}',
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.warning_amber_outlined,
                  label: context.l10n.homeOverdue,
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
              Text(context.l10n.homeRecentTasks, style: context.textTheme.titleLarge),
              TextButton(
                onPressed: () => context.go(AppRoutes.tasks),
                child: Text(context.l10n.homeViewAll),
              ),
            ],
          ),
          const SizedBox(height: 8),

          tasksAsync.when(
            skipLoadingOnRefresh: true,
            skipLoadingOnReload: true,
            loading: () => const RecentTaskListSkeleton(),
            error: (_, __) => Text(context.l10n.homeFailedToLoadTasks),
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
                            context.l10n.homeNoTasksYet,
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondaryLight,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => context.push(
                                '${AppRoutes.tasks}/create',
                                extra: widget.householdId),
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(context.l10n.homeCreateTask),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: recentTasks
                    .map<Widget>((task) => _RecentTaskTile(
                          key: ValueKey(task['id']),
                          task: task,
                          householdId: widget.householdId,
                          onCompleted: () => _confettiController.play(),
                        ))
                    .toList(),
              );
            },
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
            numberOfParticles: 20,
            gravity: 0.2,
            shouldLoop: false,
            colors: const [
              AppColors.primaryLight,
              AppColors.accentLight,
              AppColors.success,
              AppColors.warning,
              AppColors.info,
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentTaskTile extends ConsumerStatefulWidget {
  final Map<String, dynamic> task;
  final String householdId;
  final VoidCallback? onCompleted;

  _RecentTaskTile({
    super.key,
    required this.task,
    required this.householdId,
    this.onCompleted,
  });

  @override
  ConsumerState<_RecentTaskTile> createState() => _RecentTaskTileState();
}

class _RecentTaskTileState extends ConsumerState<_RecentTaskTile> {
  bool _isCompleting = false;

  @override
  void didUpdateWidget(covariant _RecentTaskTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset optimistic state when real data catches up
    if (oldWidget.task['id'] != widget.task['id'] ||
        oldWidget.task['status'] != widget.task['status']) {
      _isCompleting = false;
    }
  }

  Future<void> _completeTask() async {
    setState(() => _isCompleting = true);
    HapticFeedback.lightImpact();

    try {
      await ref.read(dataRepositoryProvider).completeTask(widget.task['id'] as String);
      widget.onCompleted?.call();
      ref.invalidate(householdTasksProvider(widget.householdId));
      ref.invalidate(taskStatsProvider(widget.householdId));
    } catch (e) {
      if (mounted) {
        setState(() => _isCompleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.homeCouldNotCompleteTask)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dueDateStr = widget.task['due_date'] as String?;
    final priority = widget.task['priority'] as String?;
    DateTime? dueDate;
    if (dueDateStr != null) dueDate = DateTime.tryParse(dueDateStr);
    final isOverdue = dueDate != null && dueDate.isOverdue;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _isCompleting ? 0.4 : 1.0,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () =>
              context.push('${AppRoutes.tasks}/${widget.task['id']}'),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Tappable completion circle — optimistic
                GestureDetector(
                  onTap: _isCompleting ? null : _completeTask,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isCompleting
                          ? AppColors.success
                          : Colors.transparent,
                      border: Border.all(
                        color: _isCompleting
                            ? AppColors.success
                            : isOverdue
                                ? AppColors.error
                                : priorityColor(priority),
                        width: 2,
                      ),
                    ),
                    child: _isCompleting
                        ? const Icon(Icons.check,
                            size: 16, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                // Task content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.task['title'] as String,
                          style: context.textTheme.titleSmall?.copyWith(
                            decoration: _isCompleting
                                ? TextDecoration.lineThrough
                                : null,
                          )),
                      if (dueDate != null)
                        Text(
                          dueDate.isToday
                              ? context.l10n.homeDueToday
                              : dueDate.isTomorrow
                                  ? context.l10n.homeDueTomorrow
                                  : context.l10n.homeDueDate(dueDate.formatted),
                          style: context.textTheme.bodySmall?.copyWith(
                            color: isOverdue
                                ? AppColors.error
                                : AppColors.textSecondaryLight,
                            fontWeight:
                                isOverdue ? FontWeight.w600 : null,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: AppColors.textSecondaryLight),
              ],
            ),
          ),
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: context.textTheme.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
