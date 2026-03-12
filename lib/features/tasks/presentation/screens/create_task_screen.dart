import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/utils/extensions.dart';
import '../../../household/data/household_providers.dart';
import '../../data/task_providers.dart';
import '../../../../core/data/data_repository_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../widgets/attachment_picker.dart';

/// Screen for creating a new task.
class CreateTaskScreen extends ConsumerStatefulWidget {
  final String householdId;

  const CreateTaskScreen({super.key, required this.householdId});

  @override
  ConsumerState<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends ConsumerState<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subtaskController = TextEditingController();

  String _priority = 'medium';
  String? _categoryId;
  String? _assignedTo;
  bool _isShared = false;
  String _recurrence = 'none';
  DateTime _startDate = DateTime.now();
  DateTime? _dueDate;
  final List<String> _subtasks = [];
  final List<PickedFileInfo> _pendingAttachments = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (!mounted) return;
      setState(() {
        if (time != null) {
          _dueDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        } else {
          _dueDate = DateTime(date.year, date.month, date.day, 23, 59);
        }
      });
    }
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (!mounted) return;
      setState(() {
        if (time != null) {
          _startDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        } else {
          _startDate = DateTime(date.year, date.month, date.day, 0, 0);
        }
      });
    }
  }

  void _addSubtask() {
    final text = _subtaskController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _subtasks.add(text);
        _subtaskController.clear();
      });
    }
  }

  /// Returns true if the form has user-entered data.
  bool get _hasUnsavedChanges =>
      _titleController.text.trim().isNotEmpty ||
      _descriptionController.text.trim().isNotEmpty ||
      _subtasks.isNotEmpty ||
      _pendingAttachments.isNotEmpty ||
      _categoryId != null ||
      _dueDate != null ||
      _priority != 'medium';

  /// Confirms discard if there are unsaved changes.
  Future<bool> _confirmDiscard() async {
    if (!_hasUnsavedChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.taskDiscardTitle),
        content: Text(context.l10n.taskDiscardMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.taskKeepEditing),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.taskDiscard),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(dataRepositoryProvider);

      final createdTask = await repo.createTask(
        householdId: widget.householdId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        categoryId: _categoryId,
        priority: _priority,
        dueDate: _dueDate,
        startDate: _startDate,
        assignedTo: _isShared ? null : _assignedTo,
        isShared: _isShared,
        recurrence: _recurrence,
        subtaskTitles: _subtasks.isEmpty ? null : _subtasks,
      );

      // Upload any pending attachments now that we have a taskId
      if (_pendingAttachments.isNotEmpty && mounted) {
        final taskId = createdTask.id;
        for (final picked in _pendingAttachments) {
          if (!mounted) break;
          await AttachmentPicker.uploadPickedFileForTask(
            context: context,
            picked: picked,
            taskId: taskId,
            householdId: widget.householdId,
            repo: repo,
            showOverlay: false,
          );
        }
      }

      // Schedule a notification reminder if the task has a due date.
      ref.read(notificationServiceProvider).scheduleTaskReminder(
        taskId: createdTask.id,
        taskTitle: createdTask.title,
        dueDate: createdTask.dueDate,
      );

      // Refresh task lists
      ref.invalidate(householdTasksProvider(widget.householdId));
      ref.invalidate(taskStatsProvider(widget.householdId));

      if (mounted) {
        context.showSnackBar(context.l10n.taskCreated);
        context.pop();
      }
    } catch (e) {
      debugPrint('Error creating task: $e');
      if (mounted) {
        context.showSnackBar(context.l10n.commonErrorGeneric,
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync =
        ref.watch(taskCategoriesProvider(widget.householdId));
    final membersAsync =
        ref.watch(householdMembersProvider(widget.householdId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) {
          if (mounted) navigator.pop();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            final navigator = Navigator.of(context);
            if (await _confirmDiscard()) {
              if (mounted) navigator.pop();
            }
          },
        ),
        title: Text(context.l10n.taskNewTask),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _handleCreate,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.commonSave),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _isLoading,
        child: Opacity(
          opacity: _isLoading ? 0.6 : 1.0,
          child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Title ──────────────────────────────────────
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.l10n.taskTitle,
                hintText: context.l10n.taskTitleHint,
                prefixIcon: const Icon(Icons.task_alt),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? context.l10n.taskEnterTitle
                  : null,
            ),
            const SizedBox(height: 16),

            // ── Description ────────────────────────────────
            TextFormField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.l10n.taskDescriptionOptional,
                hintText: context.l10n.taskDescriptionHint,
                prefixIcon: const Icon(Icons.notes),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            // ── Category ───────────────────────────────────
            Text(context.l10n.taskCategory,
                style: context.textTheme.titleSmall
                    ?.copyWith(color: AppColors.textSecondaryLight)),
            const SizedBox(height: 8),
            categoriesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => Text(context.l10n.taskFailedToLoadCategories),
              data: (categories) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...categories.map((cat) {
                    final isSelected = _categoryId == cat['id'];
                    return ChoiceChip(
                      label: Text(cat['name'] as String),
                      selected: isSelected,
                      onSelected: (_) => setState(() =>
                          _categoryId = isSelected ? null : cat['id'] as String),
                    );
                  }),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: Text(context.l10n.commonNew),
                    onPressed: () async {
                      final errorColor = Theme.of(context).colorScheme.error;
                      final messenger = ScaffoldMessenger.of(context);
                      final name = await showDialog<String>(
                        context: context,
                        builder: (ctx) {
                          final controller = TextEditingController();
                          return AlertDialog(
                            title: Text(context.l10n.taskNewCategory),
                            content: TextField(
                              controller: controller,
                              autofocus: true,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(hintText: context.l10n.taskCategoryName),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.commonCancel)),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                                child: Text(context.l10n.commonAdd),
                              ),
                            ],
                          );
                        },
                      );
                      if (name != null && name.isNotEmpty) {
                        try {
                          await ref.read(dataRepositoryProvider).createCategory(
                            householdId: widget.householdId,
                            name: name,
                          );
                          ref.invalidate(taskCategoriesProvider(widget.householdId));
                        } catch (e) {
                          debugPrint('Error creating category: $e');
                          if (mounted) {
                            messenger.showSnackBar(SnackBar(
                              content: Text(context.l10n.commonErrorGeneric),
                              backgroundColor: errorColor,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              margin: const EdgeInsets.all(16),
                            ));
                          }
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Priority ───────────────────────────────────
            Text(context.l10n.taskPriority,
                style: context.textTheme.titleSmall
                    ?.copyWith(color: AppColors.textSecondaryLight)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'low', label: Text(context.l10n.taskPriorityLow)),
                ButtonSegment(value: 'medium', label: Text(context.l10n.taskPriorityMedium)),
                ButtonSegment(value: 'high', label: Text(context.l10n.taskPriorityHigh)),
                ButtonSegment(value: 'urgent', label: Text(context.l10n.taskPriorityUrgent)),
              ],
              selected: {_priority},
              onSelectionChanged: (s) =>
                  setState(() => _priority = s.first),
            ),
            const SizedBox(height: 24),

            // ── Start date ─────────────────────────────────
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_arrow_rounded),
              title: Text(
                _startDate.isToday ? context.l10n.taskStartsToday : context.l10n.taskStartsDate(_startDate.formattedWithTime),
              ),
              trailing: !_startDate.isToday
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _startDate = DateTime.now()),
                    )
                  : null,
              onTap: _pickStartDate,
            ),

            // ── Due date ───────────────────────────────────
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(
                _dueDate != null
                    ? context.l10n.taskDueDate(_dueDate!.formattedWithTime)
                    : context.l10n.taskNoDueDate,
              ),
              trailing: _dueDate != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _dueDate = null),
                    )
                  : null,
              onTap: _pickDueDate,
            ),
            const Divider(),

            // ── Assignment ─────────────────────────────────
            Text(context.l10n.taskAssignTo,
                style: context.textTheme.titleSmall
                    ?.copyWith(color: AppColors.textSecondaryLight)),
            const SizedBox(height: 8),

            // Shared toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.taskSharedTask),
              subtitle: Text(context.l10n.taskSharedTaskSubtitle),
              value: _isShared,
              onChanged: (v) => setState(() {
                _isShared = v;
                if (v) _assignedTo = null;
              }),
            ),

            if (!_isShared)
              membersAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => Text(context.l10n.taskFailedToLoadMembers),
                data: (members) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(context.l10n.taskUnassigned),
                      selected: _assignedTo == null,
                      onSelected: (_) =>
                          setState(() => _assignedTo = null),
                    ),
                    ...members.map((m) {
                      final profile =
                          m['profiles'] as Map<String, dynamic>?;
                      final userId = m['user_id'] as String;
                      final name =
                          profile?['full_name'] as String? ?? 'Unknown';
                      final isMe = userId == FirebaseAuth.instance.currentUser?.uid;
                      return ChoiceChip(
                        label: Text(isMe ? '$name ${context.l10n.taskMeSuffix}' : name),
                        selected: _assignedTo == userId,
                        onSelected: (_) => setState(
                            () => _assignedTo = userId),
                      );
                    }),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // ── Recurrence ─────────────────────────────────
            Text(context.l10n.taskRepeat,
                style: context.textTheme.titleSmall
                    ?.copyWith(color: AppColors.textSecondaryLight)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _recurrence,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.repeat),
              ),
              items: [
                DropdownMenuItem(value: 'none', child: Text(context.l10n.taskRepeatNever)),
                DropdownMenuItem(value: 'daily', child: Text(context.l10n.taskRepeatDaily)),
                DropdownMenuItem(value: 'weekly', child: Text(context.l10n.taskRepeatWeekly)),
                DropdownMenuItem(
                    value: 'biweekly', child: Text(context.l10n.taskRepeatBiweekly)),
                DropdownMenuItem(value: 'monthly', child: Text(context.l10n.taskRepeatMonthly)),
              ],
              onChanged: (v) => setState(() => _recurrence = v ?? 'none'),
            ),
            const SizedBox(height: 24),

            // ── Subtasks ───────────────────────────────────
            Text(context.l10n.taskSubtasks,
                style: context.textTheme.titleSmall
                    ?.copyWith(color: AppColors.textSecondaryLight)),
            const SizedBox(height: 8),

            // Existing subtasks
            ..._subtasks.asMap().entries.map((e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_box_outline_blank,
                      size: 20),
                  title: Text(e.value),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () =>
                        setState(() => _subtasks.removeAt(e.key)),
                  ),
                )),

            // Add subtask input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subtaskController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: context.l10n.taskAddSubtaskHint,
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

            const SizedBox(height: 24),

            // ── Attachments ─────────────────────────────────
            const Divider(),
            const SizedBox(height: 8),

            // Pending attachment chips
            if (_pendingAttachments.isNotEmpty) ...[
              Text(
                context.l10n.taskPendingAttachments(_pendingAttachments.length),
                style: context.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _pendingAttachments.asMap().entries.map((e) {
                  return Chip(
                    avatar: const Icon(Icons.attach_file_rounded, size: 16),
                    label: Text(
                      e.value.fileName,
                      overflow: TextOverflow.ellipsis,
                    ),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => setState(
                        () => _pendingAttachments.removeAt(e.key)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],

            // Attach button
            TextButton.icon(
              onPressed: () async {
                final picked =
                    await AttachmentPicker.pickFileOnly(context);
                if (picked != null) {
                  setState(() => _pendingAttachments.add(picked));
                }
              },
              icon: const Icon(Icons.attach_file_rounded, size: 18),
              label: Text(context.l10n.taskAttachFile),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
          ),
        ),
      ),
    );
  }
}
