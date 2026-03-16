import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../config/theme/app_colors.dart';

/// A single day card in the plan grid.
/// Shows date, day name, and up to 2 entry previews.
class PlanDayCard extends StatelessWidget {
  final DateTime date;
  final List<Map<String, dynamic>> entries;
  final VoidCallback onTap;
  final bool isToday;

  const PlanDayCard({
    super.key,
    required this.date,
    required this.entries,
    required this.onTap,
    this.isToday = false,
  });

  /// Maps common labels to colours.
  static Color _labelColor(String? label) {
    switch (label?.toLowerCase()) {
      case 'dinner':
        return AppColors.accentLight;
      case 'breakfast':
        return AppColors.warning;
      case 'lunch':
        return AppColors.primaryLight;
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

  @override
  Widget build(BuildContext context) {
    final dayName = DateFormat('EEE').format(date);
    final dayNum = date.day.toString();

    return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: isToday
                  ? AppColors.primaryLight.withValues(alpha: 0.08)
                  : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isToday
                    ? AppColors.primaryLight.withValues(alpha: 0.4)
                    : Theme.of(context).dividerColor.withValues(alpha: 0.3),
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day header
                Row(
                  children: [
                    Text(
                      dayNum,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isToday ? AppColors.primaryLight : null,
                          ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dayName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondaryLight,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Entry previews (up to 2)
                if (entries.isEmpty)
                  Expanded(
                    child: Center(
                      child: Icon(
                        Icons.add_rounded,
                        size: 20,
                        color: AppColors.textSecondaryLight.withValues(alpha: 0.3),
                      ),
                    ),
                  )
                else
                  ...entries.take(2).map((entry) {
                    final label = entry['label'] as String?;
                    final title = entry['title'] as String? ?? '';
                    final displayText =
                        title.isEmpty ? (label ?? 'Untitled') : title;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 14,
                            decoration: BoxDecoration(
                              color: _labelColor(label),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              displayText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                // "More" indicator
                if (entries.length > 2)
                  Text(
                    '+${entries.length - 2} more',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: AppColors.textSecondaryLight,
                        ),
                  ),
              ],
            ),
          ),
        ),
    );
  }
}
