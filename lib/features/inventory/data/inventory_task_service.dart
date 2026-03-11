import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/data/data_repository.dart';
import '../../../core/data/data_repository_provider.dart';
import '../../../core/models/models.dart';

/// Service that creates tasks automatically based on inventory events
/// (low stock, expiring items).
class InventoryTaskService {
  final DataRepository _repo;
  final String _householdId;

  InventoryTaskService(this._repo, this._householdId);

  /// Creates a restock task when an item's stock is low.
  ///
  /// Returns the created [Task], or `null` if a matching pending task
  /// already exists (avoids duplicates).
  Future<Task?> createLowStockTask({
    required InventoryItem item,
  }) async {
    final existingTasks = await _repo.getTasks(
      householdId: _householdId,
      status: 'pending',
    );
    final alreadyExists = existingTasks.any(
      (t) =>
          t.title.contains(item.name) &&
          t.title.toLowerCase().contains('restock'),
    );
    if (alreadyExists) return null;

    return await _repo.createTask(
      householdId: _householdId,
      title: 'Restock: ${item.name}',
      description:
          '${item.name} is running low (${item.quantity} ${item.unit} remaining, threshold: ${item.lowStockThreshold}).',
      priority: 'medium',
    );
  }

  /// Creates an expiry task when an item is about to expire.
  ///
  /// Returns the created [Task], or `null` if a matching pending task
  /// already exists.
  Future<Task?> createExpiryTask({
    required InventoryItem item,
  }) async {
    final existingTasks = await _repo.getTasks(
      householdId: _householdId,
      status: 'pending',
    );
    final alreadyExists = existingTasks.any(
      (t) =>
          t.title.contains(item.name) &&
          t.title.toLowerCase().contains('expir'),
    );
    if (alreadyExists) return null;

    final expiryStr = item.expiryDate != null
        ? DateFormat.yMMMd().format(item.expiryDate!)
        : 'soon';

    return await _repo.createTask(
      householdId: _householdId,
      title: 'Use before expiry: ${item.name}',
      description:
          '${item.name} expires on $expiryStr. Consider using it soon.',
      priority: 'high',
      dueDate: item.expiryDate,
    );
  }
}

/// Riverpod provider for [InventoryTaskService].
final inventoryTaskServiceProvider =
    Provider.family<InventoryTaskService, String>(
  (ref, householdId) {
    final repo = ref.watch(dataRepositoryProvider);
    return InventoryTaskService(repo, householdId);
  },
);
