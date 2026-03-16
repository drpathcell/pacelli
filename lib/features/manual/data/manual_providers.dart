import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/data_repository_provider.dart';
import '../../../core/models/models.dart';

/// All manual entries for a household.
final manualEntriesProvider =
    FutureProvider.autoDispose.family<List<ManualEntry>, String>(
  (ref, householdId) async {
    final repo = ref.watch(dataRepositoryProvider);
    return repo.getManualEntries(householdId: householdId);
  },
);

/// Manual entries filtered by category.
/// Key is (householdId, categoryId).
final manualEntriesByCategoryProvider =
    FutureProvider.autoDispose.family<List<ManualEntry>, (String, String?)>(
  (ref, args) async {
    final (householdId, categoryId) = args;
    final repo = ref.watch(dataRepositoryProvider);
    return repo.getManualEntries(
      householdId: householdId,
      categoryId: categoryId,
    );
  },
);

/// A single manual entry by ID.
final manualEntryProvider =
    FutureProvider.autoDispose.family<ManualEntry, String>(
  (ref, entryId) async {
    final repo = ref.watch(dataRepositoryProvider);
    return repo.getManualEntry(entryId);
  },
);

/// All manual categories for a household.
final manualCategoriesProvider =
    FutureProvider.autoDispose.family<List<ManualCategory>, String>(
  (ref, householdId) async {
    final repo = ref.watch(dataRepositoryProvider);
    return repo.getManualCategories(householdId);
  },
);

/// Search manual entries.
/// Key is (householdId, searchQuery).
final manualSearchProvider =
    FutureProvider.autoDispose.family<List<ManualEntry>, (String, String)>(
  (ref, args) async {
    final (householdId, query) = args;
    final repo = ref.watch(dataRepositoryProvider);
    return repo.getManualEntries(
      householdId: householdId,
      searchQuery: query,
    );
  },
);
