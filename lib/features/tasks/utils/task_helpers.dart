import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';

/// Shared helper functions for task-related UI.

Color priorityColor(String? priority) {
  switch (priority) {
    case 'urgent':
      return AppColors.error;
    case 'high':
      return const Color(0xFFE88B5A);
    case 'medium':
      return AppColors.warning;
    case 'low':
      return AppColors.info;
    default:
      return AppColors.textSecondaryLight;
  }
}

String priorityLabel(BuildContext context, String? priority) {
  switch (priority) {
    case 'urgent':
      return context.l10n.priorityUrgent;
    case 'high':
      return context.l10n.priorityHigh;
    case 'medium':
      return context.l10n.priorityMedium;
    case 'low':
      return context.l10n.priorityLow;
    default:
      return context.l10n.priorityNone;
  }
}

String recurrenceLabel(BuildContext context, String? recurrence) {
  switch (recurrence) {
    case 'daily':
      return context.l10n.recurrenceDaily;
    case 'weekly':
      return context.l10n.recurrenceWeekly;
    case 'biweekly':
      return context.l10n.recurrenceEveryTwoWeeks;
    case 'monthly':
      return context.l10n.recurrenceMonthly;
    default:
      return context.l10n.recurrenceNever;
  }
}

IconData categoryIcon(String? iconName) {
  switch (iconName) {
    case 'cleaning_services':
      return Icons.cleaning_services;
    case 'restaurant':
      return Icons.restaurant;
    case 'shopping_cart':
      return Icons.shopping_cart;
    case 'local_laundry_service':
      return Icons.local_laundry_service;
    case 'receipt_long':
      return Icons.receipt_long;
    case 'build':
      return Icons.build;
    case 'directions_run':
      return Icons.directions_run;
    case 'more_horiz':
      return Icons.more_horiz;
    default:
      return Icons.category;
  }
}
