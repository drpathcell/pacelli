import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/data_repository_provider.dart';
import '../../../core/models/models.dart';

/// All inventory items for a household.
final inventoryItemsProvider =
    FutureProvider.autoDispose.family<List<InventoryItem>, String>(
  (ref, householdId) async {
    final repo = ref.watch(dataRepositoryProvider);
    return repo.getInventoryItems(householdId: householdId);
  },
);

/// A single inventory item by ID.
final inventoryItemProvider = FutureProvider.autoDispose.family<InventoryItem, String>(
  (ref, itemId) async {
    final repo = ref.watch(dataRepositoryProvider);
    return repo.getInventoryItem(itemId);
  },
);

/// All inventory categories for a household.
final inventoryCategoriesProvider =
    FutureProvider.autoDispose.family<List<InventoryCategory>, String>(
  (ref, householdId) async {
    final repo = ref.watch(dataRepositoryProvider);
    return repo.getInventoryCategories(householdId);
  },
);

/// All inventory locations for a household.
final inventoryLocationsProvider =
    FutureProvider.autoDispose.family<List<InventoryLocation>, String>(
  (ref, householdId) async {
    final repo = ref.watch(dataRepositoryProvider);
    return repo.getInventoryLocations(householdId);
  },
);

/// Inventory logs for a specific item.
/// Key is (itemId, householdId).
final inventoryLogsProvider =
    FutureProvider.autoDispose.family<List<InventoryLog>, (String, String)>(
  (ref, args) async {
    final (itemId, householdId) = args;
    final repo = ref.watch(dataRepositoryProvider);
    return repo.getInventoryLogs(itemId: itemId, householdId: householdId);
  },
);

/// Inventory stats for the home screen summary.
final inventoryStatsProvider =
    FutureProvider.autoDispose.family<Map<String, int>, String>(
  (ref, householdId) async {
    final repo = ref.watch(dataRepositoryProvider);
    return repo.getInventoryStats(householdId);
  },
);

/// View mode for the inventory list: 'category', 'location', or 'all'.
final inventoryViewModeProvider = StateProvider<String>((ref) => 'category');

/// Inventory items grouped by the current view mode.
/// Key is (householdId, viewMode). Returns a sorted map of group name → items.
final inventoryGroupedProvider =
    Provider.family<Map<String, List<InventoryItem>>, (String, String)>(
  (ref, args) {
    final (householdId, viewMode) = args;
    final items =
        ref.watch(inventoryItemsProvider(householdId)).valueOrNull ?? [];
    if (viewMode == 'all') return {'_all': items};

    final grouped = <String, List<InventoryItem>>{};
    for (final item in items) {
      final key = viewMode == 'category'
          ? (item.category?.name ?? '\u{FFFF}') // sort uncategorised last
          : (item.location?.name ?? '\u{FFFF}');
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  },
);
