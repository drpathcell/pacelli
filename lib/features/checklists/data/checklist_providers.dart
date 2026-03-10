import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/data_repository_provider.dart';

/// All standalone checklists (with nested items) for a household.
final householdChecklistsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, householdId) async {
    final repo = ref.watch(dataRepositoryProvider);
    final checklists = await repo.getChecklists(householdId);
    return checklists.map((c) => c.toDisplayMap()).toList();
  },
);
