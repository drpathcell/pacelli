import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../core/data/data_repository_provider.dart';
import '../../../../core/models/models.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/inventory_providers.dart';
import '../widgets/inventory_item_card.dart';

/// Main inventory list screen.
class InventoryScreen extends ConsumerStatefulWidget {
  final String householdId;

  const InventoryScreen({super.key, required this.householdId});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  bool _seeded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final viewMode = ref.watch(inventoryViewModeProvider);
    final itemsAsync = ref.watch(inventoryItemsProvider(widget.householdId));
    final categoriesAsync =
        ref.watch(inventoryCategoriesProvider(widget.householdId));
    // Seed defaults on first load when categories are empty.
    categoriesAsync.whenData((cats) {
      if (!_seeded && cats.isEmpty) {
        _seeded = true;
        _seedDefaults();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.inventoryTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: l10n.inventoryScanBarcode,
            onPressed: () async {
              final nav = GoRouter.of(context);
              final code = await nav.push<String>(
                  AppRoutes.barcodeScanner,
                  extra: widget.householdId);
              if (code != null && mounted) {
                // Barcode returned from scanner — navigate to create with it
                await nav.push(AppRoutes.createInventoryItem,
                    extra: {
                      'householdId': widget.householdId,
                      'barcode': code,
                    });
                ref.invalidate(inventoryItemsProvider);
                ref.invalidate(inventoryStatsProvider);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () =>
                context.push(AppRoutes.search, extra: widget.householdId),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'categories') {
                context.push(AppRoutes.inventoryCategories,
                    extra: widget.householdId);
              } else if (v == 'locations') {
                context.push(AppRoutes.inventoryLocations,
                    extra: widget.householdId);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'categories',
                  child: Text(l10n.inventoryManageCategories)),
              PopupMenuItem(
                  value: 'locations',
                  child: Text(l10n.inventoryManageLocations)),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push(AppRoutes.createInventoryItem,
              extra: widget.householdId);
          ref.invalidate(inventoryItemsProvider);
          ref.invalidate(inventoryStatsProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // View mode toggle.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(
                    value: 'category', label: Text(l10n.inventoryViewByCategory)),
                ButtonSegment(
                    value: 'location', label: Text(l10n.inventoryViewByLocation)),
                ButtonSegment(
                    value: 'all', label: Text(l10n.inventoryViewAll)),
              ],
              selected: {viewMode},
              onSelectionChanged: (s) =>
                  ref.read(inventoryViewModeProvider.notifier).state = s.first,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(inventoryItemsProvider);
                ref.invalidate(inventoryCategoriesProvider);
                ref.invalidate(inventoryLocationsProvider);
                ref.invalidate(inventoryStatsProvider);
              },
              child: itemsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text(l10n.inventoryCouldNotLoad)),
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2,
                              size: 64,
                              color: context.colorScheme.outline),
                          const SizedBox(height: 16),
                          Text(l10n.inventoryEmpty,
                              style: context.textTheme.bodyLarge,
                              textAlign: TextAlign.center),
                        ],
                      ),
                    );
                  }

                  final grouped = ref.watch(
                      inventoryGroupedProvider((widget.householdId, viewMode)));
                  return _buildFromGrouped(context, grouped, viewMode);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFromGrouped(
    BuildContext context,
    Map<String, List<InventoryItem>> grouped,
    String viewMode,
  ) {
    if (viewMode == 'all') {
      final items = grouped['_all'] ?? [];
      return ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) => InventoryItemCard(
          item: items[i],
          onTap: () => _openItem(items[i]),
        ),
      );
    }

    final l10n = context.l10n;
    final sortedKeys = grouped.keys.toList();

    return ListView.builder(
      itemCount: sortedKeys.length,
      itemBuilder: (_, gi) {
        final group = sortedKeys[gi];
        final groupItems = grouped[group]!;
        // Replace sentinel key with localised fallback.
        final displayName = group == '\u{FFFF}'
            ? (viewMode == 'category'
                ? l10n.inventoryUncategorised
                : l10n.inventoryNoLocation)
            : group;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(displayName,
                  style: context.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            ...groupItems.map((item) => InventoryItemCard(
                  item: item,
                  onTap: () => _openItem(item),
                )),
            const Divider(height: 1),
          ],
        );
      },
    );
  }

  void _openItem(InventoryItem item) async {
    await context.push(AppRoutes.inventoryItem, extra: {
      'householdId': widget.householdId,
      'itemId': item.id,
    });
    ref.invalidate(inventoryItemsProvider);
    ref.invalidate(inventoryStatsProvider);
  }

  Future<void> _seedDefaults() async {
    final repo = ref.read(dataRepositoryProvider);
    final hid = widget.householdId;

    // Default categories.
    const defaultCategories = [
      ('Food & Drinks', 'restaurant', '#A5B4A5'),
      ('Cleaning', 'cleaning_services', '#81D4FA'),
      ('Personal Care', 'face', '#F48FB1'),
      ('Medicine', 'medical_services', '#EF9A9A'),
      ('Pet Supplies', 'pets', '#FFD54F'),
      ('Other', 'inventory_2', '#B0BEC5'),
    ];
    for (final (name, icon, color) in defaultCategories) {
      await repo.createInventoryCategory(
          householdId: hid, name: name, icon: icon, color: color);
    }

    // Default locations.
    const defaultLocations = [
      ('Kitchen', 'kitchen'),
      ('Pantry', 'shelves'),
      ('Fridge', 'kitchen'),
      ('Freezer', 'ac_unit'),
      ('Bathroom', 'bathroom'),
      ('Garage', 'garage'),
      ('Storage Room', 'warehouse'),
    ];
    for (final (name, icon) in defaultLocations) {
      await repo.createInventoryLocation(
          householdId: hid, name: name, icon: icon);
    }

    ref.invalidate(inventoryCategoriesProvider);
    ref.invalidate(inventoryLocationsProvider);
  }
}
