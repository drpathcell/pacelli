import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/plan_providers.dart';
import '../../../../core/data/data_repository_provider.dart';
import '../widgets/plan_day_card.dart';

/// Main plan workspace — day grid + pull-up checklist drawer.
class PlanViewScreen extends ConsumerStatefulWidget {
  final String planId;
  const PlanViewScreen({super.key, required this.planId});

  @override
  ConsumerState<PlanViewScreen> createState() => _PlanViewScreenState();
}

class _PlanViewScreenState extends ConsumerState<PlanViewScreen> {
  dynamic _entriesChannel;
  dynamic _checklistChannel;
  final _checklistItemController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _setupRealtime();
  }

  void _setupRealtime() {
    final repo = ref.read(dataRepositoryProvider);
    _entriesChannel = repo.subscribeToEntries(
      widget.planId,
      onEvent: (_) {
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ref.invalidate(planDetailProvider(widget.planId));
        });
      },
    );
    _checklistChannel = repo.subscribeToChecklist(
      widget.planId,
      onEvent: (_) {
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ref.invalidate(planDetailProvider(widget.planId));
        });
      },
    );
  }

  @override
  void dispose() {
    // Cancel stream subscriptions (Firebase StreamSubscription).
    if (_entriesChannel is StreamSubscription) {
      (_entriesChannel as StreamSubscription).cancel();
    }
    if (_checklistChannel is StreamSubscription) {
      (_checklistChannel as StreamSubscription).cancel();
    }
    _checklistItemController.dispose();
    super.dispose();
  }

  /// Generates a list of dates from start to end inclusive.
  List<DateTime> _dateRange(DateTime start, DateTime end) {
    final dates = <DateTime>[];
    var d = start;
    while (!d.isAfter(end)) {
      dates.add(d);
      d = d.add(const Duration(days: 1));
    }
    return dates;
  }

  /// Groups entries by date string (YYYY-MM-DD).
  Map<String, List<Map<String, dynamic>>> _groupEntries(
      List<Map<String, dynamic>> entries) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final e in entries) {
      final raw = e['entry_date'] as String?;
      if (raw == null || raw.length < 10) continue;
      final dateStr = raw.substring(0, 10);
      map.putIfAbsent(dateStr, () => []).add(e);
    }
    // Sort each day's entries by sort_order
    for (final list in map.values) {
      list.sort((a, b) =>
          ((a['sort_order'] as int?) ?? 0).compareTo((b['sort_order'] as int?) ?? 0));
    }
    return map;
  }

  Future<void> _saveAsTemplate() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.planSaveAsTemplate),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            hintText: context.l10n.planTemplateName,
            prefixIcon: const Icon(Icons.bookmark_add_rounded),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: Text(context.l10n.commonSave),
          ),
        ],
      ),
    );
    nameController.dispose();

    if (name == null || name.isEmpty) return;

    try {
      final repo = ref.read(dataRepositoryProvider);
      final plan = await repo.getPlan(widget.planId);
      await repo.savePlanAsTemplate(
        planId: widget.planId,
        templateName: name,
        householdId: plan.householdId,
      );
      if (!mounted) return;
      context.showSnackBar(context.l10n.planTemplateSaved(name));
    } catch (e) {
      if (!mounted) return;
      context.showSnackBar(context.l10n.planFailedToSaveTemplate(e.toString()), isError: true);
    }
  }

  Future<void> _addChecklistItem(String planId) async {
    final title = _checklistItemController.text.trim();
    if (title.isEmpty) return;

    _checklistItemController.clear();
    try {
      final plan = ref.read(planDetailProvider(widget.planId)).valueOrNull;
      final householdId = plan?['household_id'] as String? ?? '';
      await ref.read(dataRepositoryProvider).addPlanChecklistItem(planId: planId, householdId: householdId, title: title);
      ref.invalidate(planDetailProvider(widget.planId));
    } catch (e) {
      if (!mounted) return;
      context.showSnackBar(context.l10n.planFailedToAddItem(e.toString()), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(planDetailProvider(widget.planId));

    return planAsync.when(
      loading: () =>
          Scaffold(body: LoadingView(message: context.l10n.planLoadingPlan)),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          message: context.l10n.planCouldNotLoad,
          onRetry: () => ref.invalidate(planDetailProvider(widget.planId)),
        ),
      ),
      data: (plan) {
        final startDateStr = plan['start_date'] as String?;
        final endDateStr = plan['end_date'] as String?;
        if (startDateStr == null || endDateStr == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(context.l10n.planInvalidMissingDates)),
          );
        }
        final startDate = DateTime.tryParse(startDateStr);
        final endDate = DateTime.tryParse(endDateStr);
        if (startDate == null || endDate == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(context.l10n.planInvalidUnreadableDates)),
          );
        }
        final entries =
            List<Map<String, dynamic>>.from(plan['plan_entries'] ?? []);
        final checklist = List<Map<String, dynamic>>.from(
            plan['plan_checklist_items'] ?? []);
        final entryMap = _groupEntries(entries);
        final dates = _dateRange(startDate, endDate);
        final isFinalised = plan['status'] == 'finalised';
        final totalChecklist = checklist.length;
        final checkedCount =
            checklist.where((c) => c['is_checked'] == true).length;

        return Scaffold(
          appBar: AppBar(
            title: Text(plan['title'] as String),
            actions: [
              if (!isFinalised)
                IconButton(
                  icon: const Icon(Icons.bookmark_add_outlined),
                  tooltip: context.l10n.planSaveAsTemplate,
                  onPressed: _saveAsTemplate,
                ),
              if (!isFinalised)
                FilledButton.tonal(
                  onPressed: () =>
                      context.push('/plans/${widget.planId}/finalise'),
                  child: Text(context.l10n.planFinalise),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: Stack(
            children: [
              // ── Day grid ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date range label
                    Text(
                      '${DateFormat('d MMM').format(startDate)} – ${DateFormat('d MMM yyyy').format(endDate)}',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    if (isFinalised)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Chip(
                          label: Text(context.l10n.planFinalisedChip),
                          backgroundColor: AppColors.success.withValues(alpha: 0.15),
                          labelStyle: const TextStyle(
                              color: AppColors.success, fontSize: 12),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    const SizedBox(height: 12),

                    // Hint text for empty plans
                    if (entries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          context.l10n.planTapToAdd,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondaryLight.withValues(alpha: 0.6),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),

                    // Grid of day cards
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(planDetailProvider(widget.planId));
                        },
                        child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: dates.length,
                        itemBuilder: (context, index) {
                          final date = dates[index];
                          final dateKey =
                              date.toIso8601String().substring(0, 10);
                          final dayEntries = entryMap[dateKey] ?? [];

                          return PlanDayCard(
                            date: date,
                            entries: dayEntries,
                            isToday: date.isToday,
                            onTap: isFinalised
                                ? () {}
                                : () => context.push(
                                      '/plans/${widget.planId}/day/$dateKey',
                                    ),
                          );
                        },
                      ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Checklist drawer ──────────────────────────
              _ChecklistDrawer(
                checklist: checklist,
                totalCount: totalChecklist,
                checkedCount: checkedCount,
                controller: _checklistItemController,
                onAdd: () => _addChecklistItem(plan['id'] as String),
                onToggle: (itemId, isChecked) async {
                  await ref.read(dataRepositoryProvider).togglePlanChecklistItem(itemId, isChecked);
                  ref.invalidate(planDetailProvider(widget.planId));
                },
                onDelete: (itemId) async {
                  await ref.read(dataRepositoryProvider).deletePlanChecklistItem(itemId);
                  ref.invalidate(planDetailProvider(widget.planId));
                },
                isFinalised: isFinalised,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Pull-up checklist drawer at the bottom of the plan view.
class _ChecklistDrawer extends StatelessWidget {
  final List<Map<String, dynamic>> checklist;
  final int totalCount;
  final int checkedCount;
  final TextEditingController controller;
  final VoidCallback onAdd;
  final Future<void> Function(String itemId, bool isChecked) onToggle;
  final Future<void> Function(String itemId) onDelete;
  final bool isFinalised;

  const _ChecklistDrawer({
    required this.checklist,
    required this.totalCount,
    required this.checkedCount,
    required this.controller,
    required this.onAdd,
    required this.onToggle,
    required this.onDelete,
    required this.isFinalised,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.08,
      minChildSize: 0.08,
      maxChildSize: 0.7,
      snap: true,
      snapSizes: const [0.08, 0.4, 0.7],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              // Pull handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondaryLight.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.checklist_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.planChecklist,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: 8),
                    if (totalCount > 0)
                      Text(
                        '$checkedCount / $totalCount',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondaryLight,
                                ),
                      ),
                    const Spacer(),
                    if (totalCount > 0)
                      SizedBox(
                        width: 60,
                        child: LinearProgressIndicator(
                          value: totalCount > 0
                              ? checkedCount / totalCount
                              : 0,
                          backgroundColor:
                              AppColors.textSecondaryLight.withValues(alpha: 0.15),
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
              ),

              const Divider(height: 16),

              // Add item input
              if (!isFinalised)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          decoration: InputDecoration(
                            hintText: context.l10n.planAddItemHint,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          onSubmitted: (_) => onAdd(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: onAdd,
                        icon: const Icon(Icons.add_rounded, size: 20),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(36, 36),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 8),

              // Checklist items
              ...checklist.map((item) {
                final isChecked = item['is_checked'] == true;
                return ListTile(
                  dense: true,
                  leading: Checkbox(
                    value: isChecked,
                    onChanged: isFinalised
                        ? null
                        : (v) => onToggle(
                            item['id'] as String, v ?? false),
                  ),
                  title: Text(
                    item['title'] as String,
                    style: isChecked
                        ? const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: AppColors.textSecondaryLight,
                          )
                        : null,
                  ),
                  subtitle: item['quantity'] != null
                      ? Text(item['quantity'] as String,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: AppColors.textSecondaryLight))
                      : null,
                  trailing: isFinalised
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () =>
                              onDelete(item['id'] as String),
                        ),
                );
              }),

              if (checklist.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    context.l10n.planNoItemsYet,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              AppColors.textSecondaryLight.withValues(alpha: 0.6),
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ),

              // Extra padding so list isn't clipped
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }
}
