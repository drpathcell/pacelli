import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/data_repository_provider.dart';
import '../../../core/models/models.dart';

/// All inventory items for a household.
final inventoryItemsProvider =
    FutureProvider.family<List<InventoryItem>, String>(
  (ref, householdId) async {
    final repo = ref.watch(dataRepositoryProvider);
    return repo.getInventoryItems(householdId: householdId);
  },
);

/// A single inventory item by ID.
final inventoryItemProvider = FutureProvider.family<InventoryItem, String>(
  (ref, itemId) async {
    final repo = ref.watch(dataRepositoryProvider);
    return repo.getInventoryItem(itemId);
  },
);

/// All inventory categories for a household.
final inventoryCategoriesProvider =
    FutureProvider.family<List<InventoryCategory>, String>(
  (ref, householdId) async {
    final repo = ref.watch(dataRepositoryProvider);
    return repo.getInventoryCategories(householdId);
  },
);

/// All inventory locations for a household.
final inventoryLocationsProvider =
    FutureProvider.family<List<InventoryLocation>, String>(
  (ref, householdId) async {
    final repo = ref.watch(dataRepositoryProvider);
    return repo.getInventoryLocations(householdId);
  },
);

/// Inventory logs for a specific item.
final inventoryLogsProvider = FutureProvider.family<List<InventoryLog>, String>(
  (ref, itemId) async {
    final repo = ref.watch(dataRepositoryProvider);
    return repo.getInventoryLogs(itemId: itemId);
  },
);

/// Inventory stats for the home screen summary.
final inventoryStatsProvider =
    FutureProvider.family<Map<String, int>, String>(
  (ref, householdId) async {
    final repo = ref.watch(dataRepositoryProvider);
    return repo.getInventoryStats(householdId);
  },
);

/// View mode for the inventory list: 'category', 'location', or 'all'.
final inventoryViewModeProvider = StateProvider<String>((ref) => 'category');
