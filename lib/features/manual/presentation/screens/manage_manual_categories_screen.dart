import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/data_repository_provider.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/manual_providers.dart';

/// Screen for managing manual categories (add / delete).
class ManageManualCategoriesScreen extends ConsumerWidget {
  final String householdId;
  const ManageManualCategoriesScreen({
    super.key,
    required this.householdId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(manualCategoriesProvider(householdId));

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.manualManageCategories),
      ),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.category_outlined,
                      size: 64, color: context.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.manualNoCategoriesYet,
                    style: context.textTheme.bodyLarge?.copyWith(
                      color: context.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return Card(
                child: ListTile(
                  leading: Icon(Icons.folder_outlined,
                      color: context.colorScheme.primary),
                  title: Text(cat.name),
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: context.colorScheme.error),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(context.l10n.manualDeleteCategoryTitle),
                          content: Text(
                              context.l10n.manualDeleteCategoryConfirm),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(ctx).pop(false),
                              child: Text(context.l10n.commonCancel),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.of(ctx).pop(true),
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    context.colorScheme.error,
                              ),
                              child: Text(context.l10n.commonDelete),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        final repo = ref.read(dataRepositoryProvider);
                        await repo.deleteManualCategory(cat.id);
                        ref.invalidate(
                            manualCategoriesProvider(householdId));
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.manualAddCategory),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.l10n.manualCategoryName,
            border: const OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) async {
            final name = controller.text.trim();
            if (name.isNotEmpty) {
              final repo = ref.read(dataRepositoryProvider);
              await repo.createManualCategory(
                householdId: householdId,
                name: name,
              );
              ref.invalidate(manualCategoriesProvider(householdId));
              if (ctx.mounted) Navigator.of(ctx).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final repo = ref.read(dataRepositoryProvider);
                await repo.createManualCategory(
                  householdId: householdId,
                  name: name,
                );
                ref.invalidate(manualCategoriesProvider(householdId));
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
            child: Text(context.l10n.commonSave),
          ),
        ],
      ),
    );
  }
}
