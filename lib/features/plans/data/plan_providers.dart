import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/data_repository_provider.dart';
import '../../../core/models/attachment.dart';

/// Provider for all scratch plans in the household (non-template).
final householdPlansProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, householdId) async {
    final repo = ref.watch(dataRepositoryProvider);
    final plans = await repo.getPlans(householdId);
    return plans.map((p) => p.toDisplayMap()).toList();
  },
);

/// Provider for a single plan by ID (with entries + checklist).
final planDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
  (ref, planId) async {
    final repo = ref.watch(dataRepositoryProvider);
    final plan = await repo.getPlan(planId);
    return plan.toDisplayMap();
  },
);

/// Provider for user-created templates in a household.
final planTemplatesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, householdId) async {
    final repo = ref.watch(dataRepositoryProvider);
    final templates = await repo.getTemplates(householdId);
    return templates.map((t) => t.toDisplayMap()).toList();
  },
);

/// Provider for attachments on a specific plan entry.
final planEntryAttachmentsProvider =
    FutureProvider.family<List<PlanAttachment>, String>(
  (ref, entryId) async {
    final repo = ref.watch(dataRepositoryProvider);
    return repo.getPlanEntryAttachments(entryId);
  },
);
