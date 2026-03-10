import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../../checklists/data/checklist_providers.dart';
import '../../../../core/data/data_repository_provider.dart';
import '../../../plans/data/plan_providers.dart';
import '../../data/task_providers.dart';

/// Collapsible "Checklists" section showing plan + standalone checklists.
class CalendarChecklistsSection extends ConsumerStatefulWidget {
  const CalendarChecklistsSection({
    super.key,
    required this.householdId,
  });

  final String householdId;

  @override
  ConsumerState<CalendarChecklistsSection> createState() =>
      _CalendarChecklistsSectionState();
}

class _CalendarChecklistsSectionState
    extends ConsumerState<CalendarChecklistsSection> {

  Future<void> _createNewChecklist() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.checklistNewChecklist),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: ctx.l10n.checklistHint,
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(ctx.l10n.commonCreate),
          ),
        ],
      ),
    );
    if (title == null || title.isEmpty) return;

    try {
      await ref.read(dataRepositoryProvider).createChecklist(
        householdId: widget.householdId,
        title: title,
      );
      ref.invalidate(householdChecklistsProvider(widget.householdId));
    } catch (e) {
      if (mounted) _showError(context.l10n.checklistCouldNotCreate);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _addItemToChecklist(String checklistId) async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.checklistAddItem),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: ctx.l10n.checklistItemName),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(ctx.l10n.commonAdd),
          ),
        ],
      ),
    );
    if (title == null || title.isEmpty) return;

    try {
      await ref.read(dataRepositoryProvider).addChecklistItem(checklistId: checklistId, title: title);
      ref.invalidate(householdChecklistsProvider(widget.householdId));
    } catch (e) {
      if (mounted) _showError(context.l10n.checklistCouldNotAdd);
    }
  }

  Future<void> _toggleStandaloneItem(String itemId, bool current) async {
    try {
      await ref.read(dataRepositoryProvider).toggleChecklistItem(itemId, !current);
      ref.invalidate(householdChecklistsProvider(widget.householdId));
    } catch (e) {
      if (mounted) _showError(context.l10n.checklistCouldNotUpdate);
    }
  }

  Future<void> _togglePlanItem(String itemId, bool current) async {
    try {
      await ref.read(dataRepositoryProvider).togglePlanChecklistItem(itemId, !current);
      ref.invalidate(householdPlansProvider(widget.householdId));
    } catch (e) {
      if (mounted) _showError(context.l10n.checklistCouldNotUpdate);
    }
  }

  Future<void> _pushStandaloneItemAsTask(
      String itemId, String itemTitle) async {
    try {
      await ref.read(dataRepositoryProvider).pushChecklistItemAsTask(
        householdId: widget.householdId,
        itemTitle: itemTitle,
        itemId: itemId,
      );
      ref.invalidate(householdChecklistsProvider(widget.householdId));
      ref.invalidate(householdTasksProvider(widget.householdId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.checklistAddedAsTask(itemTitle))),
        );
      }
    } catch (e) {
      if (mounted) _showError(context.l10n.checklistCouldNotPush);
    }
  }

  Future<void> _pushPlanItemAsTask(String itemId, String itemTitle) async {
    try {
      await ref.read(dataRepositoryProvider).pushPlanChecklistItemAsTask(
        householdId: widget.householdId,
        itemTitle: itemTitle,
        itemId: itemId,
      );
      ref.invalidate(householdPlansProvider(widget.householdId));
      ref.invalidate(householdTasksProvider(widget.householdId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.checklistAddedAsTask(itemTitle))),
        );
      }
    } catch (e) {
      if (mounted) _showError(context.l10n.checklistCouldNotPush);
    }
  }

  Future<void> _deleteStandaloneItem(String itemId) async {
    try {
      await ref.read(dataRepositoryProvider).deleteChecklistItem(itemId);
      ref.invalidate(householdChecklistsProvider(widget.householdId));
    } catch (e) {
      if (mounted) _showError(context.l10n.checklistCouldNotDeleteItem);
    }
  }

  Future<void> _deletePlanItem(String itemId) async {
    try {
      await ref.read(dataRepositoryProvider).deletePlanChecklistItem(itemId);
      ref.invalidate(householdPlansProvider(widget.householdId));
    } catch (e) {
      if (mounted) _showError(context.l10n.checklistCouldNotDeleteItem);
    }
  }

  Future<void> _deleteChecklist(String checklistId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.checklistDeleteTitle),
        content: Text(ctx.l10n.checklistDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: Text(ctx.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(dataRepositoryProvider).deleteChecklist(checklistId);
      ref.invalidate(householdChecklistsProvider(widget.householdId));
    } catch (e) {
      if (mounted) _showError(context.l10n.checklistCouldNotDeleteList);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(householdPlansProvider(widget.householdId));
    final checklistsAsync =
        ref.watch(householdChecklistsProvider(widget.householdId));

    // Collect plan checklist items from draft plans
    final planChecklistGroups = <_ChecklistGroup>[];
    plansAsync.whenData((plans) {
      for (final plan in plans) {
        if (plan['status'] != 'draft') continue;
        final items = List<Map<String, dynamic>>.from(
            plan['plan_checklist_items'] ?? []);
        if (items.isEmpty) continue;
        planChecklistGroups.add(_ChecklistGroup(
          id: plan['id'] as String,
          title: plan['title'] as String,
          isPlan: true,
          items: items,
        ));
      }
    });

    // Collect standalone checklists
    final standaloneGroups = <_ChecklistGroup>[];
    checklistsAsync.whenData((checklists) {
      for (final cl in checklists) {
        final items =
            List<Map<String, dynamic>>.from(cl['checklist_items'] ?? []);
        standaloneGroups.add(_ChecklistGroup(
          id: cl['id'] as String,
          title: cl['title'] as String,
          isPlan: false,
          items: items,
        ));
      }
    });

    final allGroups = [...planChecklistGroups, ...standaloneGroups];
    final totalItems = allGroups.fold<int>(
        0, (sum, g) => sum + g.items.length);

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: const Icon(Icons.checklist_rounded, size: 20),
        title: Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.checklistSectionTitle(totalItems),
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            GestureDetector(
              onTap: _createNewChecklist,
              child: const Icon(Icons.add_circle_outline,
                  size: 20, color: AppColors.primaryLight),
            ),
          ],
        ),
        children: allGroups.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    context.l10n.checklistNoChecklists,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ]
            : allGroups.map((group) => _buildGroup(context, group)).toList(),
      ),
    );
  }

  Widget _buildGroup(BuildContext context, _ChecklistGroup group) {
    final checkedCount =
        group.items.where((i) => i['is_checked'] == true).length;
    final total = group.items.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Row(
            children: [
              // Source badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: group.isPlan
                      ? AppColors.primaryLight.withValues(alpha: 0.12)
                      : AppColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  group.isPlan ? context.l10n.checklistBadgePlan : context.l10n.checklistBadgeList,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: group.isPlan
                        ? AppColors.primaryLight
                        : AppColors.info,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  group.title,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                context.l10n.checklistCountProgress(checkedCount, total),
                style: context.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryLight,
                  fontSize: 11,
                ),
              ),
              if (!group.isPlan) ...[
                const SizedBox(width: 4),
                // Add item to standalone checklist
                GestureDetector(
                  onTap: () => _addItemToChecklist(group.id),
                  child: const Icon(Icons.add, size: 18,
                      color: AppColors.textSecondaryLight),
                ),
                // Delete standalone checklist
                GestureDetector(
                  onTap: () => _deleteChecklist(group.id),
                  child: const Icon(Icons.more_vert, size: 18,
                      color: AppColors.textSecondaryLight),
                ),
              ],
            ],
          ),
        ),

        // Items
        ...group.items.map((item) {
          final isChecked = item['is_checked'] == true;
          final title = item['title'] as String? ?? '';
          final quantity = item['quantity'] as String?;
          final itemId = item['id'] as String;

          return ListTile(
            dense: true,
            visualDensity: const VisualDensity(vertical: -4),
            contentPadding: const EdgeInsets.only(left: 24, right: 8),
            leading: SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: isChecked,
                onChanged: (_) {
                  if (group.isPlan) {
                    _togglePlanItem(itemId, isChecked);
                  } else {
                    _toggleStandaloneItem(itemId, isChecked);
                  }
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                decoration:
                    isChecked ? TextDecoration.lineThrough : null,
                color: isChecked
                    ? AppColors.textSecondaryLight
                    : null,
              ),
            ),
            subtitle: quantity != null && quantity.isNotEmpty
                ? Text(quantity,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondaryLight))
                : null,
            trailing: PopupMenuButton<String>(
              iconSize: 18,
              padding: EdgeInsets.zero,
              onSelected: (action) {
                switch (action) {
                  case 'push':
                    if (group.isPlan) {
                      _pushPlanItemAsTask(itemId, title);
                    } else {
                      _pushStandaloneItemAsTask(itemId, title);
                    }
                    break;
                  case 'delete':
                    if (group.isPlan) {
                      _deletePlanItem(itemId);
                    } else {
                      _deleteStandaloneItem(itemId);
                    }
                    break;
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'push',
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_forward, size: 16),
                      const SizedBox(width: 8),
                      Text(context.l10n.checklistPushAsTask),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline, size: 16,
                          color: AppColors.error),
                      const SizedBox(width: 8),
                      Text(context.l10n.commonDelete,
                          style: const TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// Helper to group checklist items by source.
class _ChecklistGroup {
  final String id;
  final String title;
  final bool isPlan;
  final List<Map<String, dynamic>> items;

  _ChecklistGroup({
    required this.id,
    required this.title,
    required this.isPlan,
    required this.items,
  });
}
