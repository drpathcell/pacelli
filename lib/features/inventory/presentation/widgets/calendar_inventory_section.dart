import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/models.dart';
import '../../../../core/utils/extensions.dart';

/// Collapsible "Expiring Items" section for the calendar bottom area.
///
/// Shows inventory items whose [expiryDate] falls on the selected day.
class CalendarInventorySection extends StatelessWidget {
  const CalendarInventorySection({
    super.key,
    required this.items,
    required this.householdId,
  });

  final List<InventoryItem> items;
  final String householdId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: items.isNotEmpty,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: const Icon(Icons.warning_amber, size: 20, color: Colors.orange),
        title: Text(
          '${l10n.inventoryCalendarExpiring} · ${items.length}',
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        children: items.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    '—',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ]
            : items.map((item) {
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: Container(
                    width: 4,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  title: Text(item.name, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    [
                      '${item.quantity} ${item.unit}',
                      if (item.location != null) item.location!.name,
                      if (item.category != null) item.category!.name,
                    ].join(' · '),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondaryLight,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Chip(
                    label: Text(
                      l10n.inventoryExpiringSoon,
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: Colors.orange.shade50,
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  onTap: () => context.push(AppRoutes.inventoryItem, extra: {
                    'householdId': householdId,
                    'itemId': item.id,
                  }),
                );
              }).toList(),
      ),
    );
  }
}
