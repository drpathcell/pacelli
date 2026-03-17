import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/data/data_repository_provider.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/inventory_providers.dart';

/// CRUD screen for inventory categories.
class ManageInventoryCategoriesScreen extends ConsumerWidget {
  final String householdId;

  const ManageInventoryCategoriesScreen({
    super.key,
    required this.householdId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final categoriesAsync = ref.watch(inventoryCategoriesProvider(householdId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.inventoryCategories)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.commonError(e.toString()))),
        data: (categories) {
          if (categories.isEmpty) {
            return Center(child: Text(l10n.inventoryCategories));
          }
          return ListView.separated(
            itemCount: categories.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final cat = categories[i];
              final color = _parseColor(cat.color);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(_iconForName(cat.icon), color: color, size: 20),
                ),
                title: Text(cat.name),
                subtitle: cat.isDefault
                    ? Text(l10n.inventoryDefaultLabel,
                        style: context.textTheme.bodySmall
                            ?.copyWith(color: context.colorScheme.outline))
                    : null,
                trailing: cat.isDefault
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            _confirmDelete(context, ref, cat.id, cat.name),
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
    final iconCtrl = TextEditingController(text: 'inventory_2');
    final colorCtrl = TextEditingController(text: '#A5B4A5');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.inventoryAddCategory),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: l10n.inventoryCategoryName),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: iconCtrl,
              decoration: InputDecoration(labelText: l10n.inventoryIconLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: colorCtrl,
              decoration: InputDecoration(labelText: l10n.inventoryColorLabel),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true), child: Text(l10n.commonSave)),
        ],
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      await ref.read(dataRepositoryProvider).createInventoryCategory(
            householdId: householdId,
            name: nameCtrl.text.trim(),
            icon: iconCtrl.text.trim(),
            color: colorCtrl.text.trim(),
          );
      ref.invalidate(inventoryCategoriesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.inventoryCategoryCreated)));
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
              onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.commonCancel)),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true), child: Text(l10n.commonDelete)),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(dataRepositoryProvider).deleteInventoryCategory(id);
        ref.invalidate(inventoryCategoriesProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.inventoryCategoryDeleted)));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.inventoryCouldNotDelete)));
        }
      }
    }
  }

  static Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  static IconData _iconForName(String name) => switch (name) {
        'kitchen' => Icons.kitchen,
        'ac_unit' => Icons.ac_unit,
        'cleaning_services' => Icons.cleaning_services,
        'face' => Icons.face,
        'inventory_2' => Icons.inventory_2,
        _ => Icons.label,
      };
}
