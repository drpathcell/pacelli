import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';

/// Collapsible "Plans" section showing draft plans not yet pushed to calendar.
class CalendarPlansSection extends StatelessWidget {
  const CalendarPlansSection({
    super.key,
    required this.plans,
    required this.householdId,
  });

  final List<Map<String, dynamic>> plans;
  final String householdId;

  @override
  Widget build(BuildContext context) {
    final draftPlans =
        plans.where((p) => p['status'] == 'draft').toList();

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: const Icon(Icons.note_alt_outlined, size: 20),
        title: Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.calendarPlansSectionTitle(draftPlans.length),
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Quick-add plan button
            GestureDetector(
              onTap: () => context.push('/plans/create', extra: householdId),
              child: const Icon(Icons.add_circle_outline,
                  size: 20, color: AppColors.primaryLight),
            ),
          ],
        ),
        children: draftPlans.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    context.l10n.calendarNoDraftPlans,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ]
            : draftPlans.map((plan) {
                final entries = List<Map<String, dynamic>>.from(
                    (plan['plan_entries'] as Iterable?) ?? []);
                final checklist = List<Map<String, dynamic>>.from(
                    (plan['plan_checklist_items'] as Iterable?) ?? []);
                final startDate = plan['start_date'] as String? ?? '';
                final endDate = plan['end_date'] as String? ?? '';

                // Format date range
                String dateRange = '';
                if (startDate.isNotEmpty && endDate.isNotEmpty) {
                  final start = DateTime.tryParse(startDate);
                  final end = DateTime.tryParse(endDate);
                  if (start != null && end != null) {
                    dateRange = '${start.shortFormatted} – ${end.shortFormatted}';
                  }
                }

                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: Container(
                    width: 4,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  title: Text(
                    plan['title'] as String,
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    [
                      if (dateRange.isNotEmpty) dateRange,
                      context.l10n.calendarPlanEntries(entries.length),
                      context.l10n.calendarChecklistItems(checklist.length),
                    ].join(' · '),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondaryLight,
                      fontSize: 13,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => context.push('/plans/${plan['id']}'),
                );
              }).toList(),
      ),
    );
  }
}
