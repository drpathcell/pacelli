import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_colors.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/task_providers.dart';
import '../../../../core/data/data_repository_provider.dart';
import '../../utils/task_helpers.dart';
import '../widgets/attachment_list.dart'
    show AttachmentList, AttachmentDisplayItem;
import '../widgets/attachment_picker.dart';

/// Screen showing full task details with subtasks.
class TaskDetailScreen extends ConsumerStatefulWidget {
  final String taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  final _subtaskController = TextEditingController();
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _subtaskController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  // Using shared helpers from task_helpers.dart

  Future<void> _addSubtask() async {
    final text = _subtaskController.text.trim();
    if (text.isEmpty) return;

    await ref.read(dataRepositoryProvider).addSubtask(taskId: widget.taskId, title: text);
    _subtaskController.clear();
    ref.invalidate(taskDetailProvider(widget.taskId));
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(taskDetailProvider(widget.taskId));

    return taskAsync.when(
      loading: () => Scaffold(
        body: LoadingView(message: context.l10n.taskLoadingDetails),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          message: context.l10n.taskCouldNotLoadDetails,
          onRetry: () => ref.invalidate(taskDetailProvider(widget.taskId)),
        ),
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

        final startDateStr = task['start_date'] as String?;
        DateTime? startDate;
        if (startDateStr != null) startDate = DateTime.tryParse(startDateStr);

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

        return Stack(
          children: [
            Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.taskDetails),
            actions: [
              // Edit
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    context.push('${AppRoutes.tasks}/${widget.taskId}/edit'),
              ),
              // Delete
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(context.l10n.taskDeleteTitle),
                      content: Text(context.l10n.taskDeleteMessage),
                      actions: [
                        TextButton(
                          onPressed: () => ctx.pop(false),
                          child: Text(context.l10n.commonCancel),
                        ),
                        TextButton(
                          onPressed: () => ctx.pop(true),
                          child: Text(context.l10n.commonDelete,
                              style: const TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && mounted) {
                    await ref.read(dataRepositoryProvider).deleteTask(widget.taskId);
                    ref.invalidate(householdTasksProvider(householdId));
                    ref.invalidate(taskStatsProvider(householdId));
                    if (mounted) navigator.pop();
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
                  HapticFeedback.mediumImpact();
                  if (isCompleted) {
                    await ref.read(dataRepositoryProvider).reopenTask(widget.taskId);
                  } else {
                    await ref.read(dataRepositoryProvider).completeTask(widget.taskId);
                    _confettiController.play();
                  }
                  ref.invalidate(taskDetailProvider(widget.taskId));
                  ref.invalidate(householdTasksProvider(householdId));
                  ref.invalidate(taskStatsProvider(householdId));
                },
                icon: Icon(isCompleted
                    ? Icons.replay
                    : Icons.check_circle_outline),
                label: Text(isCompleted ? context.l10n.taskReopenTask : context.l10n.taskMarkComplete),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isCompleted ? AppColors.warning : AppColors.success,
                ),
              ),
            ),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(taskDetailProvider(widget.taskId));
            },
            child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Title & Status ────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Hero(
                      tag: 'task-title-${widget.taskId}',
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          task['title'] as String,
                          style: context.textTheme.headlineSmall?.copyWith(
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppColors.success.withValues(alpha: 0.15)
                          : priorityColor(priority).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isCompleted ? context.l10n.taskStatusCompleted : priorityLabel(context, priority),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: isCompleted
                            ? AppColors.success
                            : priorityColor(priority),
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
                          icon: categoryIcon(category['icon'] as String?),
                          label: context.l10n.taskLabelCategory,
                          value: category['name'] as String,
                        ),
                      if (startDate != null)
                        _DetailRow(
                          icon: Icons.play_arrow_rounded,
                          label: context.l10n.taskLabelStarts,
                          value: startDate.isToday
                              ? context.l10n.commonToday
                              : startDate.isTomorrow
                                  ? context.l10n.commonTomorrow
                                  : startDate.formattedWithTime,
                        ),
                      if (dueDate != null)
                        _DetailRow(
                          icon: Icons.calendar_today,
                          label: context.l10n.taskLabelDue,
                          value: dueDate.isToday
                              ? context.l10n.commonToday
                              : dueDate.isTomorrow
                                  ? context.l10n.commonTomorrow
                                  : dueDate.formattedWithTime,
                          valueColor:
                              isOverdue ? AppColors.error : null,
                        ),
                      _DetailRow(
                        icon: isShared
                            ? Icons.people_outline
                            : Icons.person_outline,
                        label: context.l10n.taskLabelAssignedTo,
                        value: isShared
                            ? context.l10n.taskSharedBoth
                            : (assigned?['full_name'] as String? ??
                                context.l10n.commonUnassigned),
                      ),
                      if (recurrence != null && recurrence != 'none')
                        _DetailRow(
                          icon: Icons.repeat,
                          label: context.l10n.taskLabelRepeats,
                          value: recurrenceLabel(context, recurrence),
                        ),
                      _DetailRow(
                        icon: Icons.person,
                        label: context.l10n.taskLabelCreatedBy,
                        value:
                            creator?['full_name'] as String? ?? context.l10n.commonUnknown,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Attachments ────────────────────────────────
              _AttachmentSection(
                taskId: widget.taskId,
                householdId: householdId,
              ),
              const SizedBox(height: 24),

              // ── Subtasks ──────────────────────────────────
              Row(
                children: [
                  Text(context.l10n.taskSubtasks,
                      style: context.textTheme.titleMedium),
                  if (subtasks.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.taskSubtaskProgress(completedSubtasks, subtasks.length),
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
                        .withValues(alpha: 0.2),
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
                        await ref.read(dataRepositoryProvider).deleteSubtask(st['id']);
                        ref.invalidate(
                            taskDetailProvider(widget.taskId));
                      },
                    ),
                    onChanged: (v) async {
                      HapticFeedback.selectionClick();
                      await ref.read(dataRepositoryProvider).toggleSubtask(
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
                      decoration: InputDecoration(
                        hintText: context.l10n.taskAddSubtask,
                        border: InputBorder.none,
                        prefixIcon: const Icon(Icons.add, size: 20),
                      ),
                      onSubmitted: (_) => _addSubtask(),
                    ),
                  ),
                  TextButton(
                    onPressed: _addSubtask,
                    child: Text(context.l10n.commonAdd),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
            // ── Confetti overlay ────────────────────────
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: pi / 2, // downward
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

/// Section that loads and displays task attachments, with an "Attach" button.
class _AttachmentSection extends ConsumerWidget {
  final String taskId;
  final String householdId;

  const _AttachmentSection({
    required this.taskId,
    required this.householdId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachmentsAsync = ref.watch(taskAttachmentsProvider(taskId));

    return attachmentsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (attachments) {
        final displayItems = attachments
            .map((a) => AttachmentDisplayItem.fromTask(a))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Attachment list
            AttachmentList(
              attachments: displayItems,
              onDelete: (item) async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(context.l10n.taskRemoveAttachmentTitle),
                    content: Text(
                      context.l10n.taskRemoveAttachmentMessage(item.fileName),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(context.l10n.commonCancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(context.l10n.taskRemove,
                            style: const TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref
                      .read(dataRepositoryProvider)
                      .deleteAttachment(item.id);
                  ref.invalidate(taskAttachmentsProvider(taskId));
                }
              },
            ),

            // Attach button
            TextButton.icon(
              onPressed: () async {
                final result = await AttachmentPicker.show(
                  context: context,
                  taskId: taskId,
                  householdId: householdId,
                  repo: ref.read(dataRepositoryProvider),
                );
                if (result != null) {
                  ref.invalidate(taskAttachmentsProvider(taskId));
                }
              },
              icon: const Icon(Icons.attach_file_rounded, size: 18),
              label: Text(context.l10n.taskAttachFile),
            ),
          ],
        );
      },
    );
  }
}
