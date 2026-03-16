import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../data/plan_providers.dart';
import '../../../../core/data/data_repository_provider.dart';
import '../../../tasks/presentation/widgets/attachment_list.dart'
    show AttachmentList, AttachmentDisplayItem;
import '../../../tasks/presentation/widgets/attachment_picker.dart';

/// Full-screen day editor — loads data once, manages entries locally,
/// and refreshes from the server after each mutation.
class PlanDayEditorScreen extends ConsumerStatefulWidget {
  final String planId;
  final DateTime date;

  const PlanDayEditorScreen({
    super.key,
    required this.planId,
    required this.date,
  });

  @override
  ConsumerState<PlanDayEditorScreen> createState() =>
      _PlanDayEditorScreenState();
}

class _PlanDayEditorScreenState extends ConsumerState<PlanDayEditorScreen> {
  final _titleController = TextEditingController();
  String? _selectedLabel;
  bool _isAdding = false;

  // ── Local state — no provider watching ────────────────────────
  List<Map<String, dynamic>> _entries = [];
  bool _isLoading = true;
  String? _error;
  String? _householdId;

  /// Default labels + any custom ones the user adds during this session.
  /// Note: These will be localized via context.l10n when displayed
  final List<String> _labels = [
    'dinner',
    'breakfast',
    'lunch',
    'snack',
    'activity',
    'transport',
    'accommodation',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String get _dateKey => widget.date.toIso8601String().substring(0, 10);

  /// Fetches plan data from the server and updates local entry list.
  Future<void> _loadData() async {
    try {
      final planModel = await ref.read(dataRepositoryProvider).getPlan(widget.planId);
      if (!mounted) return;
      final plan = planModel.toDisplayMap();
      final allEntries =
          List<Map<String, dynamic>>.from(plan['plan_entries'] ?? []);

      // Collect any custom labels already used in this plan
      for (final e in allEntries) {
        final lbl = e['label'] as String?;
        if (lbl != null && !_labels.contains(lbl)) {
          _labels.add(lbl);
        }
      }

      setState(() {
        _householdId = plan['household_id'] as String?;
        _entries = _entriesForDay(allEntries);
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Filter entries for this day only.
  List<Map<String, dynamic>> _entriesForDay(
      List<Map<String, dynamic>> allEntries) {
    return allEntries
        .where(
            (e) => (e['entry_date'] as String).substring(0, 10) == _dateKey)
        .toList()
      ..sort((a, b) => ((a['sort_order'] as int?) ?? 0)
          .compareTo((b['sort_order'] as int?) ?? 0));
  }

  Future<void> _addEntry() async {
    final title = _titleController.text.trim();
    if (title.isEmpty && _selectedLabel == null) return;

    setState(() => _isAdding = true);
    try {
      await ref.read(dataRepositoryProvider).addEntry(
        planId: widget.planId,
        householdId: _householdId ?? '',
        entryDate: widget.date,
        title: title.isEmpty ? '' : title,
        label: _selectedLabel,
      );
      _titleController.clear();
      setState(() => _selectedLabel = null);
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      context.showSnackBar(context.l10n.planFailedToAdd(e.toString()), isError: true);
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _deleteEntry(String entryId) async {
    // Optimistic: remove from local list immediately
    setState(() {
      _entries.removeWhere((e) => e['id'] == entryId);
    });
    try {
      await ref.read(dataRepositoryProvider).deleteEntry(entryId);
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      context.showSnackBar(context.l10n.planFailedToDelete(e.toString()), isError: true);
      await _loadData(); // revert
    }
  }

  /// Prompts the user to type a new custom label name.
  Future<String?> _promptCustomLabel(BuildContext dialogContext) async {
    final labelController = TextEditingController();
    final result = await showDialog<String>(
      context: dialogContext,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.planNewLabel),
        content: TextField(
          controller: labelController,
          decoration:
              InputDecoration(hintText: context.l10n.planLabelHint),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, labelController.text.trim()),
            child: Text(context.l10n.commonAdd),
          ),
        ],
      ),
    );
    // Do NOT dispose labelController here — the dialog close animation
    // may still reference it. Let GC handle it.
    if (result != null && result.isNotEmpty) {
      if (!_labels.contains(result)) {
        setState(() => _labels.add(result));
      }
      return result;
    }
    return null;
  }

  Future<void> _editEntry(Map<String, dynamic> entry) async {
    final controller =
        TextEditingController(text: entry['title'] as String);
    String? label = entry['label'] as String?;

    // Make sure the entry's existing label is in our list
    if (label != null && !_labels.contains(label)) {
      setState(() => _labels.add(label!));
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(context.l10n.planEditEntry),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: context.l10n.planWhatsPlanned,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: [
                  ..._labels.map((l) {
                    return ChoiceChip(
                      label:
                          Text(l, style: const TextStyle(fontSize: 12)),
                      selected: label == l,
                      onSelected: (sel) {
                        setDialogState(() => label = sel ? l : null);
                      },
                      visualDensity: VisualDensity.compact,
                    );
                  }),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: Text(context.l10n.planCustomLabel,
                        style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      final newLabel = await _promptCustomLabel(ctx);
                      if (newLabel != null) {
                        setDialogState(() => label = newLabel);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, {
                'title': controller.text.trim(),
                'label': label,
              }),
              child: Text(context.l10n.commonSave),
            ),
          ],
        ),
      ),
    );
    // Do NOT dispose controller here — dialog close animation may
    // still reference it. Let GC handle it.

    if (result == null) return;
    try {
      await ref.read(dataRepositoryProvider).updateEntry(
        entryId: entry['id'] as String,
        title: result['title'] as String?,
        label: result['label'] as String?,
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      context.showSnackBar(context.l10n.planFailedToUpdate(e.toString()), isError: true);
    }
  }

  /// Prompts for items to add to the checklist linked to this entry.
  Future<void> _addToChecklist(Map<String, dynamic> entry) async {
    final controller = TextEditingController();
    final items = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.planAddNeedsFor(entry['title'] as String)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: context.l10n.planNeedsHint,
            helperText: context.l10n.planNeedsHelper,
          ),
          autofocus: true,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, controller.text.trim()),
            child: Text(context.l10n.planAddToList),
          ),
        ],
      ),
    );
    // Do NOT dispose controller here — the dialog close animation
    // may still reference it. Let GC handle it.

    if (items == null || items.isEmpty) return;

    // Split by comma and add each
    final parts =
        items.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
    for (final part in parts) {
      await ref.read(dataRepositoryProvider).addPlanChecklistItem(
        planId: widget.planId,
        householdId: _householdId ?? '',
        entryId: entry['id'] as String,
        title: part,
      );
    }
    if (!mounted) return;
    context.showSnackBar(context.l10n.planItemsAddedToChecklist(parts.length));
  }

  /// Opens the attachment picker for this plan entry.
  Future<void> _attachToEntry(Map<String, dynamic> entry) async {
    if (_householdId == null) return;
    final result = await AttachmentPicker.showForPlanEntry(
      context: context,
      planId: widget.planId,
      entryId: entry['id'] as String,
      householdId: _householdId!,
      repo: ref.read(dataRepositoryProvider),
    );
    if (result != null) {
      ref.invalidate(planEntryAttachmentsProvider(entry['id'] as String));
    }
  }

  String _getLocalizedLabelName(String label) {
    switch (label) {
      case 'dinner':
        return context.l10n.planLabelDinner;
      case 'breakfast':
        return context.l10n.planLabelBreakfast;
      case 'lunch':
        return context.l10n.planLabelLunch;
      case 'snack':
        return context.l10n.planLabelSnack;
      case 'activity':
        return context.l10n.planLabelActivity;
      case 'transport':
        return context.l10n.planLabelTransport;
      case 'accommodation':
        return context.l10n.planLabelAccommodation;
      default:
        return label;
    }
  }

  Color _labelColor(String? label) {
    switch (label) {
      case 'dinner':
        return AppColors.accentLight;
      case 'breakfast':
        return AppColors.warning;
      case 'lunch':
        return AppColors.primaryLight;
      case 'snack':
        return AppColors.accentLight;
      case 'activity':
        return AppColors.info;
      case 'transport':
        return const Color(0xFF9B8EC4);
      case 'accommodation':
        return const Color(0xFF6BAF6B);
      default:
        return AppColors.textSecondaryLight;
    }
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
          body: LoadingView(message: context.l10n.planLoadingDay));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          message: context.l10n.planCouldNotLoadDay,
          onRetry: () {
            setState(() {
              _isLoading = true;
              _error = null;
            });
            _loadData();
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('EEEE, d MMM').format(widget.date)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            // Invalidate the plan provider so the grid refreshes
            // when we navigate back.
            ref.invalidate(planDetailProvider(widget.planId));
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          // ── Entries list ──────────────────────────
          Expanded(
            child: _entries.isEmpty
                ? Center(
                    child: Text(
                      context.l10n.planTapToAdd,
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondaryLight
                            .withValues(alpha: 0.6),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      final entry = _entries[index];
                      final label = entry['label'] as String?;
                      final title = entry['title'] as String? ?? '';

                      return Dismissible(
                        key: Key(entry['id'] as String),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete_outline,
                              color: AppColors.error),
                        ),
                        onDismissed: (_) =>
                            _deleteEntry(entry['id'] as String),
                        child: Column(
                          children: [
                            Card(
                              margin: const EdgeInsets.only(bottom: 4),
                              child: ListTile(
                                leading: Container(
                                  width: 4,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _labelColor(label),
                                    borderRadius:
                                        BorderRadius.circular(2),
                                  ),
                                ),
                                title: Text(
                                  title.isEmpty
                                      ? (label ?? 'Untitled')
                                      : title,
                                  style: title.isEmpty
                                      ? TextStyle(
                                          color: AppColors
                                              .textSecondaryLight
                                              .withValues(alpha: 0.6),
                                          fontStyle: FontStyle.italic)
                                      : null,
                                ),
                                subtitle:
                                    label != null && title.isNotEmpty
                                        ? Text(label,
                                            style: context
                                                .textTheme.bodySmall
                                                ?.copyWith(
                                              color: AppColors
                                                  .textSecondaryLight,
                                            ))
                                        : null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _EntryAttachBadge(
                                      entryId: entry['id'] as String,
                                      onTap: () => _attachToEntry(entry),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.list_alt_rounded,
                                          size: 20),
                                      tooltip: context.l10n.planAddToChecklist,
                                      onPressed: () =>
                                          _addToChecklist(entry),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.edit_rounded,
                                          size: 20),
                                      tooltip: context.l10n.planEdit,
                                      onPressed: () =>
                                          _editEntry(entry),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Inline attachment list for this entry
                            _EntryAttachmentList(
                              entryId: entry['id'] as String,
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // ── Add entry bar ─────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Label chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ..._labels.map((l) {
                          final displayLabel = _getLocalizedLabelName(l);
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(displayLabel,
                                  style:
                                      const TextStyle(fontSize: 12)),
                              selected: _selectedLabel == l,
                              onSelected: (sel) {
                                setState(() => _selectedLabel =
                                    sel ? l : null);
                              },
                              visualDensity: VisualDensity.compact,
                            ),
                          );
                        }),
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            avatar: const Icon(Icons.add, size: 16),
                            label: Text(context.l10n.planCustomLabel,
                                style: const TextStyle(fontSize: 12)),
                            visualDensity: VisualDensity.compact,
                            onPressed: () async {
                              final newLabel =
                                  await _promptCustomLabel(context);
                              if (newLabel != null) {
                                setState(
                                    () => _selectedLabel = newLabel);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Title input + add button
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            hintText: _selectedLabel != null
                                ? context.l10n.planWhatsForLabel(_getLocalizedLabelName(_selectedLabel!))
                                : context.l10n.planWhatsPlanned,
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                          ),
                          onSubmitted: (_) => _addEntry(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _isAdding ? null : _addEntry,
                        icon: _isAdding
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Attach-file icon button that shows a small count badge when the entry
/// already has attachments.
class _EntryAttachBadge extends ConsumerWidget {
  final String entryId;
  final VoidCallback onTap;

  const _EntryAttachBadge({required this.entryId, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachAsync = ref.watch(planEntryAttachmentsProvider(entryId));

    return attachAsync.when(
      loading: () => IconButton(
        icon: const Icon(Icons.attach_file_rounded, size: 20),
        tooltip: context.l10n.planAttachFile,
        onPressed: onTap,
      ),
      error: (_, __) => IconButton(
        icon: const Icon(Icons.attach_file_rounded, size: 20),
        tooltip: context.l10n.planAttachFile,
        onPressed: onTap,
      ),
      data: (attachments) {
        if (attachments.isEmpty) {
          return IconButton(
            icon: const Icon(Icons.attach_file_rounded, size: 20),
            tooltip: context.l10n.planAttachFile,
            onPressed: onTap,
          );
        }
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file_rounded, size: 20),
              tooltip: context.l10n.planAttachmentCount(attachments.length),
              onPressed: onTap,
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${attachments.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Shows the attachment list for a plan entry (only if there are any).
class _EntryAttachmentList extends ConsumerWidget {
  final String entryId;

  const _EntryAttachmentList({required this.entryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachAsync = ref.watch(planEntryAttachmentsProvider(entryId));

    return attachAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (attachments) {
        if (attachments.isEmpty) return const SizedBox.shrink();

        final displayItems = attachments
            .map((a) => AttachmentDisplayItem.fromPlan(a))
            .toList();

        return Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
          child: AttachmentList(
            attachments: displayItems,
            onDelete: (item) async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(context.l10n.planRemoveAttachmentTitle),
                  content: Text(
                    context.l10n.planRemoveAttachmentMessage(item.fileName),
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
                    .deletePlanAttachment(item.id);
                ref.invalidate(planEntryAttachmentsProvider(entryId));
              }
            },
          ),
        );
      },
    );
  }
}
