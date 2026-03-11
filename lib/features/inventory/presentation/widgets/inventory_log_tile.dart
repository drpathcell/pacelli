import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/models.dart';

/// A compact row showing a quantity change log entry.
class InventoryLogTile extends StatelessWidget {
  final InventoryLog log;

  const InventoryLogTile({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = _iconAndColor(log.action);
    final sign = log.quantityChange >= 0 ? '+' : '';

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, size: 16, color: color),
      ),
      title: Text(
        '$sign${log.quantityChange} (now ${log.quantityAfter})',
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          if (log.note != null && log.note!.isNotEmpty) log.note!,
          if (log.performerProfile?.fullName != null) log.performerProfile!.fullName!,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        DateFormat.MMMd().add_Hm().format(log.performedAt),
        style: theme.textTheme.bodySmall,
      ),
    );
  }

  static (IconData, Color) _iconAndColor(String action) => switch (action) {
        'added' => (Icons.add_circle_outline, Colors.green),
        'removed' => (Icons.remove_circle_outline, Colors.red),
        'adjusted' => (Icons.tune, Colors.blue),
        'expired' => (Icons.warning_amber, Colors.orange),
        _ => (Icons.history, Colors.grey),
      };
}
