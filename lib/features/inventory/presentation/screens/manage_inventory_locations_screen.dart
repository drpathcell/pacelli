import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/data_repository_provider.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/inventory_providers.dart';

/// CRUD screen for inventory locations.
class ManageInventoryLocationsScreen extends ConsumerWidget {
  final String householdId;

  const ManageInventoryLocationsScreen({
    super.key,
    required this.householdId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locationsAsync = ref.watch(inventoryLocationsProvider(householdId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.inventoryLocations)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: locationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.commonError(e.toString()))),
        data: (locations) {
          if (locations.isEmpty) {
            return Center(child: Text(l10n.inventoryLocations));
          }
          return ListView.separated(
            itemCount: locations.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final loc = locations[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      context.colorScheme.primaryContainer,
                  child: Icon(_iconForName(loc.icon), size: 20),
                ),
                title: Text(loc.name),
                subtitle: loc.isDefault
                    ? Text(l10n.inventoryDefaultLabel,
                        style: context.textTheme.bodySmall
                            ?.copyWith(color: context.colorScheme.outline))
                    : null,
                trailing: loc.isDefault
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            _confirmDelete(context, ref, loc.id, loc.name),
                      ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final nameCtrl = TextEditingController();
    final iconCtrl = TextEditingController(text: 'place');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.inventoryAddLocation),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: l10n.inventoryLocation),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: iconCtrl,
              decoration: InputDecoration(labelText: l10n.inventoryIconLabel),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => ctx.pop(false), child: Text(l10n.commonCancel)),
          FilledButton(
              onPressed: () => ctx.pop(true), child: Text(l10n.commonSave)),
        ],
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      await ref.read(dataRepositoryProvider).createInventoryLocation(
            householdId: householdId,
            name: nameCtrl.text.trim(),
            icon: iconCtrl.text.trim(),
          );
      ref.invalidate(inventoryLocationsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.inventoryLocationCreated)));
      }
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String id, String name) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.commonDelete),
        content: Text('Delete "$name"?'),
        actions: [
          TextButton(
              onPressed: () => ctx.pop(false), child: Text(l10n.commonCancel)),
          TextButton(
              onPressed: () => ctx.pop(true), child: Text(l10n.commonDelete)),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(dataRepositoryProvider).deleteInventoryLocation(id);
        ref.invalidate(inventoryLocationsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.inventoryLocationDeleted)));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.inventoryCouldNotDelete)));
        }
      }
    }
  }

  static IconData _iconForName(String name) => switch (name) {
        'kitchen' => Icons.kitchen,
        'bathroom' => Icons.bathroom,
        'garage' => Icons.garage,
        'yard' => Icons.yard,
        'warehouse' => Icons.warehouse,
        'place' => Icons.place,
        _ => Icons.place,
      };
}
