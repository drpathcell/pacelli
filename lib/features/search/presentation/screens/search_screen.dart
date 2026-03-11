import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/search_providers.dart';
import '../widgets/search_result_tile.dart';

/// Full-screen search across all household entities.
class SearchScreen extends ConsumerStatefulWidget {
  final String householdId;

  const SearchScreen({super.key, required this.householdId});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(searchFilterProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
      ),
      body: Column(
        children: [
          // ── Filter chips ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label: l10n.searchFilterTasks,
                  type: 'task',
                  selected: filters.contains('task'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.searchFilterChecklists,
                  type: 'checklist',
                  selected: filters.contains('checklist'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.searchFilterPlans,
                  type: 'plan',
                  selected: filters.contains('plan'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.searchFilterAttachments,
                  type: 'attachment',
                  selected: filters.contains('attachment'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.searchResultInventory,
                  type: 'inventory',
                  selected: filters.contains('inventory'),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Results ──
          Expanded(child: _buildResults(context, filters)),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context, Set<String> filters) {
    final l10n = context.l10n;

    if (_query.trim().length < 2) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: context.colorScheme.outline),
            const SizedBox(height: 16),
            Text(l10n.searchEmptyState, style: context.textTheme.bodyLarge),
          ],
        ),
      );
    }

    final params = SearchParams(
      householdId: widget.householdId,
      query: _query,
      entityTypes: filters,
    );

    final resultsAsync = ref.watch(searchProvider(params));

    return resultsAsync.when(
      loading: () => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.searchLoading),
          ],
        ),
      ),
      error: (e, _) => Center(
        child: Text(l10n.commonError(e.toString())),
      ),
      data: (results) {
        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off, size: 64, color: context.colorScheme.outline),
                const SizedBox(height: 16),
                Text(l10n.searchNoResults, style: context.textTheme.bodyLarge),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: results.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final result = results[index];
            return SearchResultTile(
              result: result,
              query: _query,
              onTap: () => _navigateToResult(result),
            );
          },
        );
      },
    );
  }

  void _navigateToResult(result) {
    switch (result.entityType) {
      case 'task':
        context.push('${AppRoutes.tasks}/${result.id}');
      case 'plan':
        final id = result.parentId ?? result.id;
        context.push('/plans/$id');
      case 'checklist':
        // Navigate to calendar screen where checklists live.
        context.go(AppRoutes.calendar);
      case 'attachment':
        final source = result.metadata['source'] as String?;
        if (source == 'task' && result.parentId != null) {
          context.push('${AppRoutes.tasks}/${result.parentId}');
        } else if (source == 'plan' && result.parentId != null) {
          context.push('/plans/${result.parentId}');
        }
      case 'inventory':
        context.push(
          AppRoutes.inventoryItem,
          extra: {
            'householdId': result.householdId,
            'itemId': result.id,
          },
        );
    }
  }
}

/// Individual filter chip that toggles an entity type.
class _FilterChip extends ConsumerWidget {
  final String label;
  final String type;
  final bool selected;

  const _FilterChip({
    required this.label,
    required this.type,
    required this.selected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (value) {
        final current = Set<String>.from(ref.read(searchFilterProvider));
        if (value) {
          current.add(type);
        } else {
          current.remove(type);
        }
        ref.read(searchFilterProvider.notifier).state = current;
      },
    );
  }
}
