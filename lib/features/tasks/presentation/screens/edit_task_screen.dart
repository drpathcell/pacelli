import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../household/data/household_providers.dart';
import '../../data/task_providers.dart';
import '../../../../core/data/data_repository_provider.dart';
import '../widgets/attachment_list.dart' show AttachmentList, AttachmentDisplayItem;
import '../widgets/attachment_picker.dart';

/// Screen for editing an existing task — pre-fills from existing data.
class EditTaskScreen extends ConsumerStatefulWidget {
  final String taskId;

  const EditTaskScreen({super.key, required this.taskId});

  @override
  ConsumerState<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends ConsumerState<EditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _priority = 'medium';
  String? _categoryId;
  String? _assignedTo;
  bool _isShared = false;
  String _recurrence = 'none';
  DateTime _startDate = DateTime.now();
  DateTime? _dueDate;
  String? _householdId;

  bool _isLoading = false;
  bool _isInitialising = true;

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  Future<void> _loadTask() async {
    try {
      final taskModel = await ref.read(dataRepositoryProvider).getTask(widget.taskId);
      final task = taskModel.toDisplayMap();
      if (!mounted) return;

      _titleController.text = task['title'] as String? ?? '';
      _descriptionController.text = task['description'] as String? ?? '';
      _priority = task['priority'] as String? ?? 'medium';
      _categoryId = task['category_id'] as String?;
      _assignedTo = task['assigned_to'] as String?;
      _isShared = task['is_shared'] as bool? ?? false;
      _recurrence = task['recurrence'] as String? ?? 'none';
      _householdId = task['household_id'] as String?;

      final startStr = task['start_date'] as String?;
      if (startStr != null) {
        _startDate = DateTime.tryParse(startStr) ?? DateTime.now();
      }
      final dueStr = task['due_date'] as String?;
      if (dueStr != null) {
        _dueDate = DateTime.tryParse(dueStr);
      }

      setState(() => _isInitialising = false);
    } catch (e) {
      if (mounted) {
        context.showSnackBar(context.l10n.taskFailedToLoadTask, isError: true);
        context.pop();
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: _dueDate != null
            ? TimeOfDay.fromDateTime(_dueDate!)
            : TimeOfDay.now(),
      );
      setState(() {
        if (time != null) {
          _dueDate = DateTime(
              date.year, date.month, date.day, time.hour, time.minute);
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
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_startDate),
      );
      setState(() {
        if (time != null) {
          _startDate = DateTime(
              date.year, date.month, date.day, time.hour, time.minute);
        } else {
          _startDate = DateTime(date.year, date.month, date.day, 0, 0);
        }
      });
    }
  }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      await ref.read(dataRepositoryProvider).updateTask(
        taskId: widget.taskId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? ''
            : _descriptionController.text.trim(),
        categoryId: _categoryId,
        priority: _priority,
        dueDate: _dueDate,
        startDate: _startDate,
        assignedTo: _isShared ? null : _assignedTo,
        isShared: _isShared,
        recurrence: _recurrence,
      );

      // Refresh providers
      ref.invalidate(taskDetailProvider(widget.taskId));
      if (_householdId != null) {
        ref.invalidate(householdTasksProvider(_householdId!));
        ref.invalidate(taskStatsProvider(_householdId!));
      }

      if (mounted) {
        context.showSnackBar(context.l10n.taskUpdated);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialising) {
      return Scaffold(
        body: LoadingView(message: context.l10n.taskLoadingTask),
      );
    }

    final householdId = _householdId;
    if (householdId == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.l10n.taskNoHousehold)),
      );
    }

    final categoriesAsync = ref.watch(taskCategoriesProvider(householdId));
    final membersAsync = ref.watch(householdMembersProvider(householdId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(context.l10n.taskEditTask),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _handleUpdate,
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
                    labelText: context.l10n.taskDescription,
                    hintText: context.l10n.taskDescriptionHint,
                    prefixIcon: const Icon(Icons.notes),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Category ───────────────────────────────────
                Text(context.l10n.taskLabelCategory,
                    style: context.textTheme.titleSmall
                        ?.copyWith(color: AppColors.textSecondaryLight)),
                const SizedBox(height: 8),
                categoriesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => Text(context.l10n.taskFailedToLoadCategories),
                  data: (categories) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final isSelected = _categoryId == cat['id'];
                      return ChoiceChip(
                        label: Text(cat['name'] as String),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _categoryId =
                            isSelected ? null : cat['id'] as String),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Priority ───────────────────────────────────
                Text(context.l10n.taskLabelPriority,
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
                    '${context.l10n.taskLabelStarts}: ${_startDate.isToday ? context.l10n.commonToday : _startDate.formattedWithTime}',
                  ),
                  trailing: !_startDate.isToday
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () =>
                              setState(() => _startDate = DateTime.now()),
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
                        ? '${context.l10n.taskLabelDue}: ${_dueDate!.formattedWithTime}'
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
                Text(context.l10n.taskLabelAssignTo,
                    style: context.textTheme.titleSmall
                        ?.copyWith(color: AppColors.textSecondaryLight)),
                const SizedBox(height: 8),

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
                          label: Text(context.l10n.commonUnassigned),
                          selected: _assignedTo == null,
                          onSelected: (_) =>
                              setState(() => _assignedTo = null),
                        ),
                        ...members.map((m) {
                          final profile =
                              m['profiles'] as Map<String, dynamic>?;
                          final userId = m['user_id'] as String;
                          final name =
                              profile?['full_name'] as String? ?? context.l10n.commonUnknown;
                          final isMe = userId == FirebaseAuth.instance.currentUser?.uid;
                          return ChoiceChip(
                            label: Text(isMe ? '$name (me)' : name),
                            selected: _assignedTo == userId,
                            onSelected: (_) =>
                                setState(() => _assignedTo = userId),
                          );
                        }),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // ── Recurrence ─────────────────────────────────
                Text(context.l10n.taskLabelRepeat,
                    style: context.textTheme.titleSmall
                        ?.copyWith(color: AppColors.textSecondaryLight)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _recurrence,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.repeat),
                  ),
                  items: [
                    DropdownMenuItem(value: 'none', child: Text(context.l10n.taskRecurrenceNone)),
                    DropdownMenuItem(value: 'daily', child: Text(context.l10n.taskRecurrenceDaily)),
                    DropdownMenuItem(value: 'weekly', child: Text(context.l10n.taskRecurrenceWeekly)),
                    DropdownMenuItem(
                        value: 'biweekly', child: Text(context.l10n.taskRecurrenceBiweekly)),
                    DropdownMenuItem(
                        value: 'monthly', child: Text(context.l10n.taskRecurrenceMonthly)),
                  ],
                  onChanged: (v) =>
                      setState(() => _recurrence = v ?? 'none'),
                ),

                const SizedBox(height: 24),

                // ── Attachments ──────────────────────────────
                const Divider(),
                const SizedBox(height: 8),
                _EditTaskAttachmentSection(
                  taskId: widget.taskId,
                  householdId: householdId,
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline attachment section for the edit-task form.
class _EditTaskAttachmentSection extends ConsumerWidget {
  final String taskId;
  final String householdId;

  const _EditTaskAttachmentSection({
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
