import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../core/data/data_repository_provider.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/inventory_providers.dart';
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
    final logsAsync = ref.watch(inventoryLogsProvider(itemId));

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
                        _adjustQuantity(context, ref, item.quantity, newQty),
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
                          Chip(
                            label: Text(l10n.inventoryExpired),
                            backgroundColor: Colors.red.shade50,
                            side: BorderSide.none,
                          ),
                        if (item.isExpiringSoon && !item.isExpired)
                          Chip(
                            label: Text(l10n.inventoryExpiringSoon),
                            backgroundColor: Colors.orange.shade50,
                            side: BorderSide.none,
                          ),
                        if (item.isLowStock)
                          Chip(
                            label: Text(l10n.inventoryLowStock),
                            backgroundColor: Colors.amber.shade50,
                            side: BorderSide.none,
                          ),
                      ],
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
                          child: Text(l10n.inventoryNoLocation,
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

  Future<void> _adjustQuantity(
    BuildContext context,
    WidgetRef ref,
    int oldQty,
    int newQty,
  ) async {
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
