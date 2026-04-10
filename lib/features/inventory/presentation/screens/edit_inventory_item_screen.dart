import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/data_repository_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/inventory_providers.dart';

/// Screen to edit an existing inventory item.
class EditInventoryItemScreen extends ConsumerStatefulWidget {
  final String householdId;
  final String itemId;

  const EditInventoryItemScreen({
    super.key,
    required this.householdId,
    required this.itemId,
  });

  @override
  ConsumerState<EditInventoryItemScreen> createState() =>
      _EditInventoryItemScreenState();
}

class _EditInventoryItemScreenState
    extends ConsumerState<EditInventoryItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _quantityCtrl;
  late TextEditingController _unitCtrl;
  late TextEditingController _thresholdCtrl;
  late TextEditingController _barcodeCtrl;
  late TextEditingController _notesCtrl;

  String? _categoryId;
  String? _locationId;
  DateTime? _expiryDate;
  DateTime? _purchaseDate;
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _quantityCtrl = TextEditingController();
    _unitCtrl = TextEditingController();
    _thresholdCtrl = TextEditingController();
    _barcodeCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _quantityCtrl.dispose();
    _unitCtrl.dispose();
    _thresholdCtrl.dispose();
    _barcodeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final itemAsync = ref.watch(inventoryItemProvider(widget.itemId));
    final categoriesAsync =
        ref.watch(inventoryCategoriesProvider(widget.householdId));
    final locationsAsync =
        ref.watch(inventoryLocationsProvider(widget.householdId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.inventoryEditItem)),
      body: itemAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.inventoryCouldNotLoad)),
        data: (item) {
          if (!_loaded) {
            _loaded = true;
            _nameCtrl.text = item.name;
            _descCtrl.text = item.description ?? '';
            _quantityCtrl.text = item.quantity.toString();
            _unitCtrl.text = item.unit;
            _thresholdCtrl.text =
                item.lowStockThreshold?.toString() ?? '';
            _barcodeCtrl.text = item.barcode ?? '';
            _notesCtrl.text = item.notes ?? '';
            _categoryId = item.categoryId;
            _locationId = item.locationId;
            _expiryDate = item.expiryDate;
            _purchaseDate = item.purchaseDate;
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(labelText: l10n.inventoryItemName),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? l10n.inventoryItemName
                      : null,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descCtrl,
                  decoration:
                      InputDecoration(labelText: l10n.inventoryDescription),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: categoriesAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (cats) => DropdownButtonFormField<String>(
                          initialValue: _categoryId,
                          decoration:
                              InputDecoration(labelText: l10n.inventoryCategory),
                          items: [
                            DropdownMenuItem<String>(
                                value: null,
                                child: Text(l10n.inventoryUncategorised)),
                            ...cats.map((c) =>
                                DropdownMenuItem(value: c.id, child: Text(c.name))),
                          ],
                          onChanged: (v) => setState(() => _categoryId = v),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: l10n.inventoryAddCategory,
                      onPressed: () => _showAddCategoryDialog(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: locationsAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (locs) => DropdownButtonFormField<String>(
                          initialValue: _locationId,
                          decoration:
                              InputDecoration(labelText: l10n.inventoryLocation),
                          items: [
                            DropdownMenuItem<String>(
                                value: null,
                                child: Text(l10n.inventoryNoLocation)),
                            ...locs.map((l) =>
                                DropdownMenuItem(value: l.id, child: Text(l.name))),
                          ],
                          onChanged: (v) => setState(() => _locationId = v),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: l10n.inventoryAddLocation,
                      onPressed: () => _showAddLocationDialog(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityCtrl,
                        decoration:
                            InputDecoration(labelText: l10n.inventoryQuantity),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _unitCtrl,
                        decoration:
                            InputDecoration(labelText: l10n.inventoryUnit),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _thresholdCtrl,
                  decoration: InputDecoration(
                      labelText: l10n.inventoryLowStockThreshold),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.inventoryExpiryDate),
                  subtitle: Text(_expiryDate != null
                      ? _expiryDate!.toLocal().toString().split(' ').first
                      : l10n.inventoryNoExpiry),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () =>
                      _pickDate((d) => setState(() => _expiryDate = d)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.inventoryPurchaseDate),
                  subtitle: Text(_purchaseDate != null
                      ? _purchaseDate!.toLocal().toString().split(' ').first
                      : '—'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () =>
                      _pickDate((d) => setState(() => _purchaseDate = d)),
                ),
                TextFormField(
                  controller: _barcodeCtrl,
                  decoration:
                      InputDecoration(labelText: l10n.inventoryBarcode),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesCtrl,
                  decoration: InputDecoration(labelText: l10n.inventoryNotes),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child:
                              CircularProgressIndicator(strokeWidth: 2))
                      : Text(l10n.inventorySave),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddCategoryDialog() async {
    final l10n = context.l10n;
    final nameCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.inventoryAddCategory),
        content: TextField(
          controller: nameCtrl,
          decoration: InputDecoration(labelText: l10n.inventoryCategoryName),
          textCapitalization: TextCapitalization.sentences,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      try {
        final cat = await ref.read(dataRepositoryProvider).createInventoryCategory(
          householdId: widget.householdId,
          name: nameCtrl.text.trim(),
          icon: 'inventory_2',
          color: '#A5B4A5',
        );
        ref.invalidate(inventoryCategoriesProvider);
        setState(() => _categoryId = cat.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.commonError(e.toString()))),
          );
        }
      }
    }
  }

  Future<void> _showAddLocationDialog() async {
    final l10n = context.l10n;
    final nameCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.inventoryAddLocation),
        content: TextField(
          controller: nameCtrl,
          decoration: InputDecoration(labelText: l10n.inventoryLocation),
          textCapitalization: TextCapitalization.sentences,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      try {
        final loc = await ref.read(dataRepositoryProvider).createInventoryLocation(
          householdId: widget.householdId,
          name: nameCtrl.text.trim(),
          icon: 'place',
        );
        ref.invalidate(inventoryLocationsProvider);
        setState(() => _locationId = loc.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.commonError(e.toString()))),
          );
        }
      }
    }
  }

  Future<void> _pickDate(ValueChanged<DateTime> onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final repo = ref.read(dataRepositoryProvider);
      final desc = _descCtrl.text.trim();
      final barcode = _barcodeCtrl.text.trim();
      final notes = _notesCtrl.text.trim();

      await repo.updateInventoryItem(
        itemId: widget.itemId,
        name: _nameCtrl.text.trim(),
        description: desc.isEmpty ? null : desc,
        categoryId: _categoryId,
        locationId: _locationId,
        quantity: int.tryParse(_quantityCtrl.text) ?? 0,
        unit: _unitCtrl.text.trim().isEmpty ? 'pieces' : _unitCtrl.text.trim(),
        lowStockThreshold: int.tryParse(_thresholdCtrl.text),
        barcode: barcode.isEmpty ? null : barcode,
        expiryDate: _expiryDate,
        purchaseDate: _purchaseDate,
        notes: notes.isEmpty ? null : notes,
      );

      // Reschedule expiry notification.
      final notifService = ref.read(notificationServiceProvider);
      await notifService.cancelExpiryReminder(widget.itemId);
      if (_expiryDate != null) {
        notifService.scheduleExpiryReminder(
          itemId: widget.itemId,
          itemName: _nameCtrl.text.trim(),
          expiryDate: _expiryDate!,
        );
      }

      if (mounted) {
        ref.invalidate(inventoryItemProvider);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.inventoryUpdated)));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.commonError(e.toString()))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
