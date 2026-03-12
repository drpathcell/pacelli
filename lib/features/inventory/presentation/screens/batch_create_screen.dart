import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/data_repository_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/inventory_providers.dart';

/// Screen to batch-create multiple inventory items by dividing a base item
/// into numbered portions (e.g. "Chicken breast (1/4)" ... "(4/4)").
class BatchCreateScreen extends ConsumerStatefulWidget {
  final String householdId;
  final String baseName;
  final String? categoryId;
  final String? locationId;
  final String unit;
  final DateTime? expiryDate;
  final DateTime? purchaseDate;
  final String? notes;

  const BatchCreateScreen({
    super.key,
    required this.householdId,
    required this.baseName,
    this.categoryId,
    this.locationId,
    this.unit = 'pieces',
    this.expiryDate,
    this.purchaseDate,
    this.notes,
  });

  @override
  ConsumerState<BatchCreateScreen> createState() => _BatchCreateScreenState();
}

class _BatchCreateScreenState extends ConsumerState<BatchCreateScreen> {
  final _portionsCtrl = TextEditingController(text: '2');
  bool _saving = false;

  @override
  void dispose() {
    _portionsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final portions = int.tryParse(_portionsCtrl.text) ?? 2;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.inventoryBatchTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Base name preview
          Text(widget.baseName, style: context.textTheme.headlineSmall),
          const SizedBox(height: 24),

          // Portions input
          TextFormField(
            controller: _portionsCtrl,
            decoration: InputDecoration(
              labelText: l10n.inventoryBatchPortions,
              helperText: l10n.inventoryBatchPortionsHint,
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),

          // Preview of items to be created
          Text('Preview:', style: context.textTheme.titleSmall),
          const SizedBox(height: 8),
          ...List.generate(
            portions.clamp(1, 50),
            (i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.inventory_2,
                      size: 18, color: context.colorScheme.outline),
                  const SizedBox(width: 8),
                  Text(l10n.inventoryBatchNamePattern(
                      widget.baseName, i + 1, portions)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          FilledButton(
            onPressed: _saving ? null : _create,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.inventoryBatchCreate),
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    final portions = int.tryParse(_portionsCtrl.text) ?? 2;
    if (portions < 2 || portions > 100) return;

    setState(() => _saving = true);
    final l10n = context.l10n;

    try {
      final repo = ref.read(dataRepositoryProvider);

      final notifService = ref.read(notificationServiceProvider);
      final notifFutures = <Future>[];

      for (int i = 1; i <= portions; i++) {
        final name =
            l10n.inventoryBatchNamePattern(widget.baseName, i, portions);
        final createdItem = await repo.createInventoryItem(
          householdId: widget.householdId,
          name: name,
          categoryId: widget.categoryId,
          locationId: widget.locationId,
          quantity: 1,
          unit: widget.unit,
          barcodeType: 'virtual',
          expiryDate: widget.expiryDate,
          purchaseDate: widget.purchaseDate,
          notes: widget.notes,
        );

        // Collect notification futures for parallel scheduling.
        if (widget.expiryDate != null) {
          notifFutures.add(notifService.scheduleExpiryReminder(
            itemId: createdItem.id,
            itemName: name,
            expiryDate: widget.expiryDate!,
          ));
        }
      }

      // Schedule all notifications in parallel.
      await Future.wait(notifFutures);

      if (mounted) {
        ref.invalidate(inventoryItemsProvider);
        ref.invalidate(inventoryStatsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.inventoryBatchCreated(portions))),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.commonError(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
