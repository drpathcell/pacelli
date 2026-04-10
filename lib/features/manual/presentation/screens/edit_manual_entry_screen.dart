import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/data_repository_provider.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/manual_providers.dart';

/// Screen for editing an existing manual entry.
class EditManualEntryScreen extends ConsumerStatefulWidget {
  final String entryId;
  const EditManualEntryScreen({super.key, required this.entryId});

  @override
  ConsumerState<EditManualEntryScreen> createState() =>
      _EditManualEntryScreenState();
}

class _EditManualEntryScreenState
    extends ConsumerState<EditManualEntryScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagController = TextEditingController();
  String? _selectedCategoryId;
  List<String> _tags = [];
  bool _isPinned = false;
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      context.showSnackBar(context.l10n.manualTitleRequired, isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(dataRepositoryProvider);
      await repo.updateManualEntry(
        entryId: widget.entryId,
        title: title,
        content: _contentController.text,
        categoryId: _selectedCategoryId,
        tags: _tags,
        isPinned: _isPinned,
      );

      ref.invalidate(manualEntryProvider(widget.entryId));
      // Also invalidate the list since title/content may have changed.
      final entry = await ref.read(manualEntryProvider(widget.entryId).future);
      ref.invalidate(manualEntriesProvider(entry.householdId));

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        context.showSnackBar(context.l10n.commonError(e.toString()), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final entryAsync = ref.watch(manualEntryProvider(widget.entryId));

    return entryAsync.when(
      data: (entry) {
        // Initialize controllers once.
        if (!_initialized) {
          _titleController.text = entry.title;
          _contentController.text = entry.content;
          _selectedCategoryId = entry.categoryId;
          _tags = List.from(entry.tags);
          _isPinned = entry.isPinned;
          _initialized = true;
        }

        final categoriesAsync =
            ref.watch(manualCategoriesProvider(entry.householdId));

        return Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.manualEditTitle),
            actions: [
              TextButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(context.l10n.commonSave),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: context.l10n.manualEntryTitle,
                  border: const OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),

              // Category selector
              categoriesAsync.when(
                data: (categories) {
                  if (categories.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return DropdownButtonFormField<String?>(
                    initialValue: _selectedCategoryId,
                    decoration: InputDecoration(
                      labelText: context.l10n.manualCategory,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(context.l10n.manualNoCategory),
                      ),
                      ...categories.map(
                          (cat) => DropdownMenuItem<String?>(
                                value: cat.id,
                                child: Text(cat.name),
                              )),
                    ],
                    onChanged: (v) =>
                        setState(() => _selectedCategoryId = v),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_outlined,
                          size: 16,
                          color: context.colorScheme.error),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.manualCategoryLoadError,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tags
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagController,
                      decoration: InputDecoration(
                        labelText: context.l10n.manualAddTag,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addTag,
                        ),
                      ),
                      onSubmitted: (_) => _addTag(),
                    ),
                  ),
                ],
              ),
              if (_tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _tags
                      .map((tag) => Chip(
                            label: Text(tag),
                            onDeleted: () =>
                                setState(() => _tags.remove(tag)),
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 16),

              // Pin toggle
              SwitchListTile(
                title: Text(context.l10n.manualPinEntry),
                value: _isPinned,
                onChanged: (v) => setState(() => _isPinned = v),
                secondary: const Icon(Icons.push_pin_outlined),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),

              // Content
              TextField(
                controller: _contentController,
                decoration: InputDecoration(
                  labelText: context.l10n.manualContent,
                  hintText: context.l10n.manualContentHint,
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: null,
                minLines: 12,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
              ),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.l10n.commonError(e.toString()))),
      ),
    );
  }
}
