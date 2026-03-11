import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';

/// Small coloured chip showing an inventory category name with icon.
class InventoryCategoryChip extends StatelessWidget {
  final InventoryCategory category;

  const InventoryCategoryChip({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(category.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconForName(category.icon), size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            category.name,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  static Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  static IconData _iconForName(String name) => switch (name) {
        'kitchen' => Icons.kitchen,
        'ac_unit' => Icons.ac_unit,
        'cleaning_services' => Icons.cleaning_services,
        'face' => Icons.face,
        'inventory_2' => Icons.inventory_2,
        'place' => Icons.place,
        'bathroom' => Icons.bathroom,
        'garage' => Icons.garage,
        'yard' => Icons.yard,
        'warehouse' => Icons.warehouse,
        _ => Icons.label,
      };
}
