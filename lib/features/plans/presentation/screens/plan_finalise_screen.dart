import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../tasks/data/task_providers.dart';
import '../../data/plan_providers.dart';
import '../../../../core/data/data_repository_provider.dart';

/// Finalise screen — lets user toggle each entry as "task" or "note"
/// before pushing to the calendar.
class PlanFinaliseScreen extends ConsumerStatefulWidget {
  final String planId;
  const PlanFinaliseScreen({super.key, required this.planId});

  @override
  ConsumerState<PlanFinaliseScreen> createState() =>
      _PlanFinaliseScreenState();
}

class _PlanFinaliseScreenState extends ConsumerState<PlanFinaliseScreen> {
  /// Maps entry ID → 'task' | 'note' | 'skip'
  final _actions = <String, String>{};
  bool _isLoading = false;

  /// Group entries by date for display.
  Map<String, List<Map<String, dynamic>>> _groupByDate(
      List<Map<String, dynamic>> entries) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final e in entries) {
      final key = (e['entry_date'] as String).substring(0, 10);
      map.putIfAbsent(key, () => []).add(e);
    }
    // Sort days
    final sorted = Map.fromEntries(
        map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    return sorted;
  }

  Future<void> _finalise(String householdId) async {
    // Confirm
    final taskCount = _actions.values.where((v) => v == 'task').length;
    final noteCount = _actions.values.where((v) => v == 'note').length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.planPushToCalendar),
        content: Text(
          context.l10n.planPushSummary(taskCount, noteCount),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.planPushToCalendarButton),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      // Filter out 'skip' entries
      final filtered = Map.fromEntries(
          _actions.entries.where((e) => e.value != 'skip'));

      await ref.read(dataRepositoryProvider).finalisePlan(
        planId: widget.planId,
        householdId: householdId,
        entryActions: filtered,
      );

      if (!mounted) return;

      // Invalidate caches
      ref.invalidate(planDetailProvider(widget.planId));
      ref.invalidate(householdPlansProvider(householdId));
      ref.invalidate(householdTasksProvider(householdId));

      // Show success
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 48),
          title: Text(context.l10n.planFinalisedSuccess),
          content: Text(context.l10n.planEntriesPushed),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/calendar');
              },
              child: Text(context.l10n.planViewCalendar),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      context.showSnackBar(context.l10n.planFailedToFinalise(e.toString()), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(planDetailProvider(widget.planId));

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.planFinalisePlan)),
      body: planAsync.when(
        loading: () =>
            LoadingView(message: context.l10n.planLoadingEntries),
        error: (e, _) => ErrorView(
          message: context.l10n.planCouldNotLoad,
          onRetry: () => ref.invalidate(planDetailProvider(widget.planId)),
        ),
        data: (plan) {
          final entries = List<Map<String, dynamic>>.from(
              plan['plan_entries'] ?? []);
          final grouped = _groupByDate(entries);
          final householdId = plan['household_id'] as String;

          // Initialize defaults: all entries → 'task'
          for (final entry in entries) {
            _actions.putIfAbsent(entry['id'] as String, () => 'task');
          }

          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_busy_rounded,
                      size: 48,
                      color: AppColors.textSecondaryLight.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  Text(context.l10n.planNoEntriesToFinalise),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.planGoBack),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Info banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: AppColors.info.withValues(alpha: 0.08),
                child: Text(
                  context.l10n.planInfoBanner,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: AppColors.info,
                  ),
                ),
              ),

              // Entry list grouped by day
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: grouped.entries.map((dayGroup) {
                          final date = DateTime.parse(dayGroup.key);
                          return Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              // Day header
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: 12, bottom: 8),
                                child: Text(
                                  DateFormat('EEEE, d MMM')
                                      .format(date),
                                  style: context.textTheme.titleSmall
                                      ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              // Entries for this day
                              ...dayGroup.value.map((entry) {
                                final id = entry['id'] as String;
                                final label =
                                    entry['label'] as String?;
                                final title =
                                    entry['title'] as String? ?? '';
                                final displayTitle = title.isEmpty
                                    ? (label ?? 'Untitled')
                                    : (label != null
                                        ? '$label: $title'
                                        : title);
                                final action =
                                    _actions[id] ?? 'task';

                                return Card(
                                  margin: const EdgeInsets.only(
                                      bottom: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            displayTitle,
                                            style: action == 'skip'
                                                ? TextStyle(
                                                    color: AppColors
                                                        .textSecondaryLight
                                                        .withValues(alpha:
                                                            0.5),
                                                    decoration:
                                                        TextDecoration
                                                            .lineThrough,
                                                  )
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SegmentedButton<String>(
                                          segments: [
                                            ButtonSegment(
                                              value: 'task',
                                              icon: const Icon(
                                                  Icons
                                                      .task_alt_rounded,
                                                  size: 16),
                                              label: Text(context.l10n.planActionTask,
                                                  style: const TextStyle(
                                                      fontSize: 11)),
                                            ),
                                            ButtonSegment(
                                              value: 'note',
                                              icon: const Icon(
                                                  Icons
                                                      .sticky_note_2_outlined,
                                                  size: 16),
                                              label: Text(context.l10n.planActionNote,
                                                  style: const TextStyle(
                                                      fontSize: 11)),
                                            ),
                                            ButtonSegment(
                                              value: 'skip',
                                              icon: const Icon(
                                                  Icons
                                                      .do_not_disturb_rounded,
                                                  size: 16),
                                              label: Text(context.l10n.planActionSkip,
                                                  style: const TextStyle(
                                                      fontSize: 11)),
                                            ),
                                          ],
                                          selected: {action},
                                          onSelectionChanged: (v) {
                                            setState(() =>
                                                _actions[id] =
                                                    v.first);
                                          },
                                          style: const ButtonStyle(
                                            visualDensity:
                                                VisualDensity
                                                    .compact,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        }).toList(),
                      ),
              ),

              // Bottom action bar
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => _finalise(householdId),
                      icon: const Icon(Icons.send_rounded),
                      label: Text(context.l10n.planPushToCalendarButton),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
