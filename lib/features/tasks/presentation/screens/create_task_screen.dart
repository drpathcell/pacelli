import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/extensions.dart';
import '../../../household/data/household_providers.dart';
import '../../data/task_providers.dart';
import '../../data/task_service.dart';

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
  DateTime? _dueDate;
  final List<String> _subtasks = [];
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
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      setState(() {
        if (time != null) {
          _dueDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        } else {
          _dueDate = DateTime(date.year, date.month, date.day, 23, 59);
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

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await TaskService.createTask(
        householdId: widget.householdId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        categoryId: _categoryId,
        priority: _priority,
        dueDate: _dueDate,
        assignedTo: _isShared ? null : _assignedTo,
        isShared: _isShared,
        recurrence: _recurrence,
        subtaskTitles: _subtasks.isEmpty ? null : _subtasks,
      );

      // Refresh task lists
      ref.invalidate(householdTasksProvider(widget.householdId));
      ref.invalidate(taskStatsProvider(widget.householdId));

      if (mounted) {
        context.showSnackBar('Task created!');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Error: $e',
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const Text('New Task'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _handleCreate,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Title ──────────────────────────────────────
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Task title',
                hintText: 'e.g. Clean the kitchen',
                prefixIcon: Icon(Icons.task_alt),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please enter a title'
                  : null,
            ),
            const SizedBox(height: 16),

            // ── Description ────────────────────────────────
            TextFormField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Add any details...',
                prefixIcon: Icon(Icons.notes),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            // ── Category ───────────────────────────────────
            Text('Category',
                style: context.textTheme.titleSmall
                    ?.copyWith(color: AppColors.textSecondaryLight)),
            const SizedBox(height: 8),
            categoriesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Failed to load categories'),
              data: (categories) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories.map((cat) {
                  final isSelected = _categoryId == cat['id'];
                  return ChoiceChip(
                    label: Text(cat['name'] as String),
                    selected: isSelected,
                    onSelected: (_) => setState(() =>
                        _categoryId = isSelected ? null : cat['id'] as String),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // ── Priority ───────────────────────────────────
            Text('Priority',
                style: context.textTheme.titleSmall
                    ?.copyWith(color: AppColors.textSecondaryLight)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'low', label: Text('Low')),
                ButtonSegment(value: 'medium', label: Text('Medium')),
                ButtonSegment(value: 'high', label: Text('High')),
                ButtonSegment(value: 'urgent', label: Text('Urgent')),
              ],
              selected: {_priority},
              onSelectionChanged: (s) =>
                  setState(() => _priority = s.first),
            ),
            const SizedBox(height: 24),

            // ── Due date ───────────────────────────────────
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(
                _dueDate != null
                    ? _dueDate!.formattedWithTime
                    : 'No due date',
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
            Text('Assign to',
                style: context.textTheme.titleSmall
                    ?.copyWith(color: AppColors.textSecondaryLight)),
            const SizedBox(height: 8),

            // Shared toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Shared task (both of you)'),
              subtitle: const Text('Anyone can complete it'),
              value: _isShared,
              onChanged: (v) => setState(() {
                _isShared = v;
                if (v) _assignedTo = null;
              }),
            ),

            if (!_isShared)
              membersAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Failed to load members'),
                data: (members) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Unassigned'),
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
                      final isMe = userId == currentUserId;
                      return ChoiceChip(
                        label: Text(isMe ? '$name (me)' : name),
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
            Text('Repeat',
                style: context.textTheme.titleSmall
                    ?.copyWith(color: AppColors.textSecondaryLight)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _recurrence,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.repeat),
              ),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('Never')),
                DropdownMenuItem(value: 'daily', child: Text('Daily')),
                DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                DropdownMenuItem(
                    value: 'biweekly', child: Text('Every 2 weeks')),
                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
              ],
              onChanged: (v) => setState(() => _recurrence = v ?? 'none'),
            ),
            const SizedBox(height: 24),

            // ── Subtasks ───────────────────────────────────
            Text('Subtasks',
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

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
