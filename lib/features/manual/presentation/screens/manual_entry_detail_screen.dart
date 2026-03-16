import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../core/data/data_repository_provider.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/manual_providers.dart';

/// Displays a single manual entry with its full Markdown content.
class ManualEntryDetailScreen extends ConsumerWidget {
  final String entryId;
  const ManualEntryDetailScreen({super.key, required this.entryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryAsync = ref.watch(manualEntryProvider(entryId));

    return entryAsync.when(
      data: (entry) => Scaffold(
        appBar: AppBar(
          title: Text(entry.title),
          actions: [
            IconButton(
              icon: Icon(
                entry.isPinned
                    ? Icons.push_pin_rounded
                    : Icons.push_pin_outlined,
                color:
                    entry.isPinned ? context.colorScheme.primary : null,
              ),
              onPressed: () async {
                final repo = ref.read(dataRepositoryProvider);
                await repo.updateManualEntry(
                  entryId: entry.id,
                  isPinned: !entry.isPinned,
                );
                ref.invalidate(manualEntryProvider(entryId));
                ref.invalidate(
                    manualEntriesProvider(entry.householdId));
              },
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  context.push(
                    '${AppRoutes.manual}/${entry.id}/edit',
                  );
                } else if (value == 'delete') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(context.l10n.manualDeleteTitle),
                      content:
                          Text(context.l10n.manualDeleteConfirm),
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
                  if (confirmed == true && context.mounted) {
                    final repo = ref.read(dataRepositoryProvider);
                    await repo.deleteManualEntry(entry.id);
                    ref.invalidate(
                        manualEntriesProvider(entry.householdId));
                    if (context.mounted) context.pop();
                  }
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined, size: 20),
                      const SizedBox(width: 12),
                      Text(context.l10n.commonEdit),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline,
                          size: 20,
                          color: context.colorScheme.error),
                      const SizedBox(width: 12),
                      Text(
                        context.l10n.commonDelete,
                        style: TextStyle(
                            color: context.colorScheme.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Category + tags
            if (entry.category != null || entry.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (entry.category != null)
                      Chip(
                        label: Text(entry.category!.name),
                        avatar: const Icon(Icons.folder_outlined,
                            size: 16),
                        visualDensity: VisualDensity.compact,
                      ),
                    ...entry.tags.map((tag) => Chip(
                          label: Text(tag),
                          visualDensity: VisualDensity.compact,
                        )),
                  ],
                ),
              ),

            // Content — render as simple rich text
            // (Using a basic text display; a full Markdown renderer
            // can be swapped in later via flutter_markdown.)
            SelectableText(
              entry.content.isNotEmpty
                  ? entry.content
                  : context.l10n.manualNoContent,
              style: context.textTheme.bodyLarge?.copyWith(
                height: 1.6,
                color: entry.content.isNotEmpty
                    ? null
                    : context.colorScheme.outline,
              ),
            ),

            const SizedBox(height: 24),

            // Metadata footer
            Divider(color: context.colorScheme.outlineVariant),
            const SizedBox(height: 8),
            Text(
              '${context.l10n.manualLastEdited}: '
              '${_formatDateTime(entry.updatedAt)}',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
