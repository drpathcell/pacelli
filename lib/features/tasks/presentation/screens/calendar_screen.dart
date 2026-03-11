import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/models.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../household/data/household_providers.dart';
import '../../../plans/data/plan_providers.dart';
import '../../data/task_providers.dart';
import '../../../inventory/data/inventory_providers.dart';
import '../../../inventory/presentation/widgets/calendar_inventory_section.dart';
import '../widgets/calendar_checklists_section.dart';
import '../widgets/calendar_plans_section.dart';
import '../widgets/calendar_tasks_section.dart';

/// Calendar view showing tasks plotted on a monthly calendar,
/// with stacked sections for Tasks, Plans, and Checklists below.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  /// Get the date key (year-month-day) for grouping tasks.
  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// Build a map of date → list of tasks for that date.
  Map<DateTime, List<Map<String, dynamic>>> _buildEventMap(
      List<Map<String, dynamic>> tasks) {
    final map = <DateTime, List<Map<String, dynamic>>>{};

    for (final task in tasks) {
      DateTime? eventDate;

      final dueDateStr = task['due_date'] as String?;
      final startDateStr = task['start_date'] as String?;

      if (dueDateStr != null) {
        eventDate = DateTime.tryParse(dueDateStr);
      } else if (startDateStr != null) {
        eventDate = DateTime.tryParse(startDateStr);
      }

      if (eventDate != null) {
        final key = _dateOnly(eventDate);
        map.putIfAbsent(key, () => []).add(task);
      }
    }

    return map;
  }

  /// Get tasks for a specific day from the event map.
  List<Map<String, dynamic>> _getTasksForDay(
      DateTime day, Map<DateTime, List<Map<String, dynamic>>> eventMap) {
    return eventMap[_dateOnly(day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final householdAsync = ref.watch(currentHouseholdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.calendarTitle),
        actions: [
          // Active plans shortcut (top-right icon — kept as requested)
          householdAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (data) {
              if (data == null) return const SizedBox.shrink();
              final hh = data['household'] as Map<String, dynamic>;
              final hhId = hh['id'] as String;
              final plansAsync = ref.watch(householdPlansProvider(hhId));
              return plansAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (plans) {
                  final active =
                      plans.where((p) => p['status'] == 'draft').toList();
                  if (active.isEmpty) return const SizedBox.shrink();
                  return PopupMenuButton<String>(
                    icon: Badge(
                      label: Text('${active.length}'),
                      child: const Icon(Icons.note_alt_outlined),
                    ),
                    tooltip: context.l10n.calendarActivePlans,
                    onSelected: (planId) => context.push('/plans/$planId'),
                    itemBuilder: (ctx) => active.map((p) {
                      return PopupMenuItem<String>(
                        value: p['id'] as String,
                        child: Text(p['title'] as String),
                      );
                    }).toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
      floatingActionButton: householdAsync.when(
        loading: () => null,
        error: (_, __) => null,
        data: (data) {
          if (data == null) return null;
          final hh = data['household'] as Map<String, dynamic>;
          final hhId = hh['id'] as String;
          return FloatingActionButton.extended(
            onPressed: () => context.push('/plans/create', extra: hhId),
            icon: const Icon(Icons.add_rounded),
            label: Text(context.l10n.calendarNewPlan),
          );
        },
      ),
      body: householdAsync.when(
        loading: () => LoadingView(message: context.l10n.calendarLoading),
        error: (e, _) => ErrorView(
          message: context.l10n.calendarCouldNotLoad,
          onRetry: () => ref.invalidate(currentHouseholdProvider),
        ),
        data: (data) {
          if (data == null) {
            return Center(child: Text(context.l10n.calendarNoHousehold));
          }

          final household = data['household'] as Map<String, dynamic>;
          final householdId = household['id'] as String;
          final tasksAsync = ref.watch(householdTasksProvider(householdId));
          final plansAsync = ref.watch(householdPlansProvider(householdId));
          final inventoryAsync =
              ref.watch(inventoryItemsProvider(householdId));

          return tasksAsync.when(
            loading: () => LoadingView(message: context.l10n.calendarLoadingTasks),
            error: (e, _) => ErrorView(
              message: context.l10n.calendarCouldNotLoadTasks,
              onRetry: () => ref.invalidate(householdTasksProvider(householdId)),
            ),
            data: (tasks) {
              final eventMap = _buildEventMap(tasks);
              final selectedTasks = _getTasksForDay(_selectedDay, eventMap);

              // Build a map of date → expiring inventory items.
              final allItems = inventoryAsync.valueOrNull ?? [];
              final expiryMap = <DateTime, List<InventoryItem>>{};
              for (final item in allItems) {
                if (item.expiryDate != null) {
                  final key = _dateOnly(item.expiryDate!);
                  expiryMap.putIfAbsent(key, () => []).add(item);
                }
              }
              final selectedExpiring =
                  expiryMap[_dateOnly(_selectedDay)] ?? [];

              return Column(
                children: [
                  // ── Calendar widget ────────────────────────
                  TableCalendar<Map<String, dynamic>>(
                    firstDay:
                        DateTime.now().subtract(const Duration(days: 365)),
                    lastDay:
                        DateTime.now().add(const Duration(days: 365 * 2)),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    selectedDayPredicate: (day) =>
                        isSameDay(_selectedDay, day),
                    eventLoader: (day) {
                      final dayTasks = _getTasksForDay(day, eventMap);
                      final dayExpiring = expiryMap[_dateOnly(day)] ?? [];
                      // Combine so markers show for both types.
                      return [
                        ...dayTasks,
                        ...List.generate(
                            dayExpiring.length, (_) => <String, dynamic>{}),
                      ];
                    },
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onFormatChanged: (format) {
                      setState(() => _calendarFormat = format);
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle: const TextStyle(
                        color: AppColors.textPrimaryLight,
                        fontWeight: FontWeight.bold,
                      ),
                      selectedDecoration: const BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      selectedTextStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      markersMaxCount: 0, // We use custom markers below
                      outsideDaysVisible: false,
                    ),
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (ctx, day, events) {
                        final taskCount =
                            _getTasksForDay(day, eventMap).length;
                        final expiryCount =
                            (expiryMap[_dateOnly(day)] ?? []).length;
                        if (taskCount == 0 && expiryCount == 0) return null;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (taskCount > 0)
                              Container(
                                width: 6,
                                height: 6,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 1),
                                decoration: const BoxDecoration(
                                  color: AppColors.accentLight,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            if (expiryCount > 0)
                              Container(
                                width: 6,
                                height: 6,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 1),
                                decoration: const BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    headerStyle: HeaderStyle(
                      formatButtonVisible: true,
                      titleCentered: true,
                      formatButtonDecoration: BoxDecoration(
                        border: Border.all(color: AppColors.primaryLight),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      formatButtonTextStyle: const TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  const Divider(height: 1),

                  // ── Stacked sections ───────────────────────
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 80),
                      children: [
                        // Tasks section
                        CalendarTasksSection(
                          tasks: selectedTasks,
                          selectedDay: _selectedDay,
                        ),

                        const Divider(
                            height: 1, indent: 16, endIndent: 16),

                        // Expiring inventory items section
                        if (selectedExpiring.isNotEmpty ||
                            allItems.any((i) => i.expiryDate != null))
                          CalendarInventorySection(
                            items: selectedExpiring,
                            householdId: householdId,
                          ),

                        if (selectedExpiring.isNotEmpty ||
                            allItems.any((i) => i.expiryDate != null))
                          const Divider(
                              height: 1, indent: 16, endIndent: 16),

                        // Plans section
                        plansAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (plans) => CalendarPlansSection(
                            plans: plans,
                            householdId: householdId,
                          ),
                        ),

                        const Divider(
                            height: 1, indent: 16, endIndent: 16),

                        // Checklists section
                        CalendarChecklistsSection(
                          householdId: householdId,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
