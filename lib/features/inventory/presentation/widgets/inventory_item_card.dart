import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../../../core/utils/extensions.dart';
import 'inventory_category_chip.dart';

/// A card widget for displaying an inventory item in a list.
class InventoryItemCard extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback? onTap;

  const InventoryItemCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ListTile(
      onTap: onTap,
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('${item.quantity} ${item.unit}',
                  style: context.textTheme.bodySmall),
              if (item.location != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.place, size: 12, color: context.colorScheme.outline),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(item.location!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodySmall),
                ),
              ],
            ],
          ),
          if (item.category != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: InventoryCategoryChip(category: item.category!),
            ),
        ],
      ),
      trailing: _buildTrailingBadges(context, l10n),
    );
  }

  Widget? _buildTrailingBadges(BuildContext context, dynamic l10n) {
    if (item.isExpired) {
      return _Badge(
        label: l10n.inventoryExpired,
        color: Colors.red,
      );
    }
    if (item.isExpiringSoon) {
      return _Badge(
        label: l10n.inventoryExpiringSoon,
        color: Colors.orange,
      );
    }
    if (item.isLowStock) {
      return _Badge(
        label: l10n.inventoryLowStock,
        color: Colors.amber.shade700,
      );
    }
    return null;
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
