import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../utils/task_helpers.dart';

/// Collapsible "Tasks" section for the calendar bottom area.
class CalendarTasksSection extends StatelessWidget {
  const CalendarTasksSection({
    super.key,
    required this.tasks,
    required this.selectedDay,
  });

  final List<Map<String, dynamic>> tasks;
  final DateTime selectedDay;

  // Using shared priorityColor() from task_helpers.dart

  @override
  Widget build(BuildContext context) {
    final dayLabel = selectedDay.isToday
        ? context.l10n.commonToday
        : selectedDay.isTomorrow
            ? context.l10n.commonTomorrow
            : selectedDay.formatted;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: const Icon(Icons.check_circle_outline, size: 20),
        title: Text(
          context.l10n.calendarTasksSectionTitle(dayLabel, tasks.length),
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        children: tasks.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    context.l10n.calendarNoTasksOnDay,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ]
            : tasks.map((task) {
                final isCompleted = task['status'] == 'completed';
                final priority = task['priority'] as String?;
                final category =
                    task['task_categories'] as Map<String, dynamic>?;

                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: Container(
                    width: 4,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppColors.success
                          : priorityColor(priority),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  title: Text(
                    task['title'] as String,
                    style: isCompleted
                        ? const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: AppColors.textSecondaryLight,
                            fontSize: 14,
                          )
                        : const TextStyle(fontSize: 14),
                  ),
                  subtitle: category != null
                      ? Text(
                          category['name'] as String,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondaryLight,
                            fontSize: 13,
                          ),
                        )
                      : null,
                  trailing: isCompleted
                      ? const Icon(Icons.check_circle,
                          color: AppColors.success, size: 18)
                      : null,
                  onTap: () => context.push('/tasks/${task['id']}'),
                );
              }).toList(),
      ),
    );
  }
}
