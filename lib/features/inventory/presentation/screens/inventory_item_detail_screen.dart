import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../core/data/data_repository_provider.dart';
import '../../../../core/models/models.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/inventory_providers.dart';
import '../../data/inventory_task_service.dart';
import '../widgets/inventory_category_chip.dart';
import '../widgets/inventory_log_tile.dart';
import '../widgets/quantity_adjuster.dart';

/// Detail view for a single inventory item.
class InventoryItemDetailScreen extends ConsumerWidget {
  final String householdId;
  final String itemId;

  const InventoryItemDetailScreen({
    super.key,
    required this.householdId,
    required this.itemId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final itemAsync = ref.watch(inventoryItemProvider(itemId));
    final logsAsync = ref.watch(inventoryLogsProvider((itemId, householdId)));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.inventoryDetails),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await context.push(AppRoutes.editInventoryItem, extra: {
                'householdId': householdId,
                'itemId': itemId,
              });
              ref.invalidate(inventoryItemProvider);
              ref.invalidate(inventoryLogsProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: itemAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.inventoryCouldNotLoad)),
        data: (item) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(inventoryItemProvider);
              ref.invalidate(inventoryLogsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Name.
                Text(item.name, style: context.textTheme.headlineSmall),
                const SizedBox(height: 8),

                // Category & Location.
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (item.category != null)
                      InventoryCategoryChip(category: item.category!),
                    if (item.location != null)
                      Chip(
                        avatar: const Icon(Icons.place, size: 16),
                        label: Text(item.location!.name),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Quantity adjuster.
                Center(
                  child: QuantityAdjuster(
                    quantity: item.quantity,
                    unit: item.unit,
                    onChanged: (newQty) =>
                        _adjustQuantity(context, ref, item, newQty),
                  ),
                ),

                // Status badges.
                if (item.isLowStock || item.isExpiringSoon || item.isExpired)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        if (item.isExpired)
                          _statusChip(context, l10n.inventoryExpired, Colors.red),
                        if (item.isExpiringSoon && !item.isExpired)
                          _statusChip(context, l10n.inventoryExpiringSoon, Colors.orange),
                        if (item.isLowStock)
                          _statusChip(context, l10n.inventoryLowStock, Colors.amber),
                      ],
                    ),
                  ),

                // Quick-action: create task for expiring / low stock items.
                if (item.isExpiringSoon || item.isExpired || item.isLowStock)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      onPressed: () => _offerAutoTask(context, ref, item),
                      icon: const Icon(Icons.add_task, size: 18),
                      label: Text(l10n.inventoryAutoCreateTask),
                    ),
                  ),
                const SizedBox(height: 16),

                // Description.
                if (item.description != null &&
                    item.description!.isNotEmpty) ...[
                  Text(l10n.inventoryDescription,
                      style: context.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(item.description!),
                  const SizedBox(height: 16),
                ],

                // Details section.
                _DetailRow(
                    label: l10n.inventoryUnit, value: item.unit),
                if (item.lowStockThreshold != null)
                  _DetailRow(
                      label: l10n.inventoryLowStockThreshold,
                      value: '${item.lowStockThreshold}'),
                if (item.barcode != null && item.barcode!.isNotEmpty) ...[
                  _DetailRow(
                      label: l10n.inventoryBarcode,
                      value: item.barcode!),
                  if (item.barcodeType == 'virtual')
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: OutlinedButton.icon(
                        onPressed: () => context.push(
                          AppRoutes.virtualBarcodeView,
                          extra: {
                            'itemName': item.name,
                            'barcode': item.barcode!,
                          },
                        ),
                        icon: const Icon(Icons.qr_code, size: 18),
                        label: Text(l10n.inventoryViewQrCode),
                      ),
                    ),
                ],
                if (item.expiryDate != null)
                  _DetailRow(
                      label: l10n.inventoryExpiryDate,
                      value: DateFormat.yMMMd().format(item.expiryDate!)),
                if (item.purchaseDate != null)
                  _DetailRow(
                      label: l10n.inventoryPurchaseDate,
                      value: DateFormat.yMMMd().format(item.purchaseDate!)),
                if (item.notes != null && item.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(l10n.inventoryNotes,
                      style: context.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(item.notes!),
                ],

                const SizedBox(height: 24),
                const Divider(),

                // Activity log.
                Text(l10n.inventoryActivityLog,
                    style: context.textTheme.titleMedium),
                const SizedBox(height: 8),
                logsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text(l10n.commonError(e.toString())),
                  data: (logs) {
                    if (logs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(l10n.inventoryActivityLogEmpty,
                              style: context.textTheme.bodyMedium),
                        ),
                      );
                    }
                    return Column(
                      children:
                          logs.map((log) => InventoryLogTile(log: log)).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget _statusChip(BuildContext context, String label, MaterialColor color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Chip(
      label: Text(
        label,
        style: TextStyle(color: isDark ? color.shade100 : color.shade900),
      ),
      backgroundColor: isDark ? color.shade900 : color.shade50,
      side: BorderSide.none,
    );
  }

  Future<void> _adjustQuantity(
    BuildContext context,
    WidgetRef ref,
    InventoryItem item,
    int newQty,
  ) async {
    final oldQty = item.quantity;
    final repo = ref.read(dataRepositoryProvider);
    final change = newQty - oldQty;
    final action = change > 0 ? 'added' : 'removed';

    await repo.updateInventoryItem(itemId: itemId, quantity: newQty);
    await repo.logInventoryAction(
      itemId: itemId,
      householdId: householdId,
      action: action,
      quantityChange: change,
      quantityAfter: newQty,
    );

    ref.invalidate(inventoryItemProvider);
    ref.invalidate(inventoryLogsProvider);
    ref.invalidate(inventoryStatsProvider);

    // Detect low stock threshold crossing (only on decrease).
    final threshold = item.lowStockThreshold;
    if (threshold != null &&
        oldQty > threshold &&
        newQty <= threshold &&
        context.mounted) {
      // Send notification
      ref.read(notificationServiceProvider).sendLowStockNotification(
            itemId: itemId,
            itemName: item.name,
            currentQuantity: newQty,
            threshold: threshold,
          );

      // Log notification
      await repo.logInventoryAction(
        itemId: itemId,
        householdId: householdId,
        action: 'notification_sent',
        quantityChange: 0,
        quantityAfter: newQty,
        note: 'Low stock alert',
      );

      // Offer to create restock task
      if (context.mounted) {
        final l10n = context.l10n;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.inventoryLowStockAlert),
            action: SnackBarAction(
              label: l10n.inventoryAutoCreateTask,
              onPressed: () => _createLowStockTask(context, ref, item, newQty),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _createLowStockTask(
    BuildContext context,
    WidgetRef ref,
    InventoryItem item,
    int currentQty,
  ) async {
    final service = ref.read(inventoryTaskServiceProvider(householdId));
    final task = await service.createLowStockTask(
      item: item.copyWith(quantity: currentQty),
    );
    if (task != null) {
      final repo = ref.read(dataRepositoryProvider);
      await repo.logInventoryAction(
        itemId: itemId,
        householdId: householdId,
        action: 'task_created',
        quantityChange: 0,
        quantityAfter: currentQty,
        note: 'Restock task created',
      );
      ref.invalidate(inventoryLogsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.inventoryRestockTaskCreated)),
        );
      }
    }
  }

  Future<void> _offerAutoTask(
    BuildContext context,
    WidgetRef ref,
    InventoryItem item,
  ) async {
    final service = ref.read(inventoryTaskServiceProvider(householdId));
    final repo = ref.read(dataRepositoryProvider);
    final l10n = context.l10n;

    Task? task;
    String logNote;
    String successMsg;

    if (item.isExpiringSoon || item.isExpired) {
      task = await service.createExpiryTask(item: item);
      logNote = 'Expiry task created';
      successMsg = l10n.inventoryExpiryTaskCreated;
    } else {
      task = await service.createLowStockTask(item: item);
      logNote = 'Restock task created';
      successMsg = l10n.inventoryRestockTaskCreated;
    }

    if (task != null) {
      await repo.logInventoryAction(
        itemId: itemId,
        householdId: householdId,
        action: 'task_created',
        quantityChange: 0,
        quantityAfter: item.quantity,
        note: logNote,
      );
      ref.invalidate(inventoryLogsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(successMsg)));
      }
    } else if (context.mounted) {
      // Task already exists
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.commonOk)),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.inventoryDelete),
        content: Text(l10n.inventoryDeleteConfirm),
        actions: [
          TextButton(
              onPressed: () => ctx.pop(false), child: Text(l10n.commonCancel)),
          TextButton(
              onPressed: () => ctx.pop(true), child: Text(l10n.commonDelete)),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(notificationServiceProvider).cancelExpiryReminder(itemId);
      await ref.read(dataRepositoryProvider).deleteInventoryItem(itemId);
      ref.invalidate(inventoryItemsProvider);
      ref.invalidate(inventoryStatsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.inventoryDeleted)));
        context.pop();
      }
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.outline)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
