import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';

/// A small chip representing a plan entry with colour-coded label.
class EntryChip extends StatelessWidget {
  final String title;
  final String? label;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const EntryChip({
    super.key,
    required this.title,
    this.label,
    this.onTap,
    this.onDelete,
  });

  static Color labelColor(String? label) {
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
    return ActionChip(
      avatar: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: labelColor(label),
          shape: BoxShape.circle,
        ),
      ),
      label: Text(
        title.isEmpty ? (label ?? 'Untitled') : title,
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
      onPressed: onTap ?? () {},
      visualDensity: VisualDensity.compact,
    );
  }
}
