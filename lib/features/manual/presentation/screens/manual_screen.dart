import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/manual_providers.dart';
import '../widgets/manual_entry_card.dart';

/// Main House Manual screen — lists all entries grouped or filtered by category.
class ManualScreen extends ConsumerStatefulWidget {
  final String householdId;
  const ManualScreen({super.key, required this.householdId});

  @override
  ConsumerState<ManualScreen> createState() => _ManualScreenState();
}

class _ManualScreenState extends ConsumerState<ManualScreen> {
  String? _selectedCategoryId;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = _searchQuery.isNotEmpty
        ? ref.watch(manualSearchProvider((widget.householdId, _searchQuery)))
        : _selectedCategoryId != null
            ? ref.watch(manualEntriesByCategoryProvider(
                (widget.householdId, _selectedCategoryId)))
            : ref.watch(manualEntriesProvider(widget.householdId));

    final categoriesAsync =
        ref.watch(manualCategoriesProvider(widget.householdId));

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: context.l10n.manualSearchHint,
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : Text(context.l10n.manualTitle),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'categories') {
                context.push(AppRoutes.manualCategories,
                    extra: widget.householdId);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'categories',
                child: Row(
                  children: [
                    const Icon(Icons.category_outlined, size: 20),
                    const SizedBox(width: 12),
                    Text(context.l10n.manualManageCategories),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Category chips
          categoriesAsync.when(
            data: (categories) {
              if (categories.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: FilterChip(
                        label: Text(context.l10n.commonAll),
                        selected: _selectedCategoryId == null,
                        onSelected: (_) =>
                            setState(() => _selectedCategoryId = null),
                      ),
                    ),
                    ...categories.map((cat) => Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 6),
                          child: FilterChip(
                            label: Text(cat.name),
                            selected: _selectedCategoryId == cat.id,
                            onSelected: (_) => setState(() =>
                                _selectedCategoryId =
                                    _selectedCategoryId == cat.id
                                        ? null
                                        : cat.id),
                          ),
                        )),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Entries list
          Expanded(
            child: entriesAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.menu_book_outlined,
                          size: 64,
                          color: context.colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.l10n.manualEmpty,
                          style: context.textTheme.bodyLarge?.copyWith(
                            color: context.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.manualEmptyHint,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.outline,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // Pinned first, then by updated date.
                final pinned =
                    entries.where((e) => e.isPinned).toList();
                final unpinned =
                    entries.where((e) => !e.isPinned).toList();

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(
                        manualEntriesProvider(widget.householdId));
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (pinned.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 4, bottom: 8, top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.push_pin_rounded,
                                  size: 16,
                                  color: context.colorScheme.primary),
                              const SizedBox(width: 6),
                              Text(
                                context.l10n.manualPinned,
                                style:
                                    context.textTheme.labelMedium?.copyWith(
                                  color: context.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...pinned.map((entry) => ManualEntryCard(
                              entry: entry,
                              onTap: () => context.push(
                                '${AppRoutes.manual}/${entry.id}',
                              ),
                            )),
                        const SizedBox(height: 12),
                      ],
                      ...unpinned.map((entry) => ManualEntryCard(
                            entry: entry,
                            onTap: () => context.push(
                              '${AppRoutes.manual}/${entry.id}',
                            ),
                          )),
                    ],
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Error: $e'),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(
          '${AppRoutes.manual}/create',
          extra: widget.householdId,
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
