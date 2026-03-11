import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../core/data/data_repository_provider.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/inventory_providers.dart';

/// Screen to create a new inventory item.
class CreateInventoryItemScreen extends ConsumerStatefulWidget {
  final String householdId;

  const CreateInventoryItemScreen({super.key, required this.householdId});

  @override
  ConsumerState<CreateInventoryItemScreen> createState() =>
      _CreateInventoryItemScreenState();
}

class _CreateInventoryItemScreenState
    extends ConsumerState<CreateInventoryItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController(text: '0');
  final _unitCtrl = TextEditingController(text: 'pieces');
  final _thresholdCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _categoryId;
  String? _locationId;
  String _barcodeType = 'none';
  DateTime? _expiryDate;
  DateTime? _purchaseDate;
  bool _saving = false;

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
    final categoriesAsync =
        ref.watch(inventoryCategoriesProvider(widget.householdId));
    final locationsAsync =
        ref.watch(inventoryLocationsProvider(widget.householdId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.inventoryAddItem)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Name.
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: l10n.inventoryItemName,
                hintText: l10n.inventoryItemNameHint,
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? l10n.inventoryItemName : null,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // Description.
            TextFormField(
              controller: _descCtrl,
              decoration: InputDecoration(labelText: l10n.inventoryDescription),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // Category dropdown.
            categoriesAsync.when(
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
                  ...cats.map((c) => DropdownMenuItem(
                      value: c.id, child: Text(c.name))),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
            ),
            const SizedBox(height: 16),

            // Location dropdown.
            locationsAsync.when(
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
                  ...locs.map((l) => DropdownMenuItem(
                      value: l.id, child: Text(l.name))),
                ],
                onChanged: (v) => setState(() => _locationId = v),
              ),
            ),
            const SizedBox(height: 16),

            // Quantity + Unit.
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

            // Low stock threshold.
            TextFormField(
              controller: _thresholdCtrl,
              decoration: InputDecoration(
                  labelText: l10n.inventoryLowStockThreshold),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Expiry date.
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.inventoryExpiryDate),
              subtitle: Text(_expiryDate != null
                  ? _expiryDate!.toLocal().toString().split(' ').first
                  : l10n.inventoryNoExpiry),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate((d) => setState(() => _expiryDate = d)),
            ),

            // Purchase date.
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

            // Barcode type selector.
            Text(l10n.inventoryBarcodeTypeLabel,
                style: context.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'none',
                  label: Text(l10n.inventoryBarcodeTypeNone),
                  icon: const Icon(Icons.block, size: 18),
                ),
                ButtonSegment(
                  value: 'real',
                  label: Text(l10n.inventoryBarcodeTypeReal),
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                ),
                ButtonSegment(
                  value: 'virtual',
                  label: Text(l10n.inventoryBarcodeTypeVirtual),
                  icon: const Icon(Icons.qr_code, size: 18),
                ),
              ],
              selected: {_barcodeType},
              onSelectionChanged: (s) {
                setState(() {
                  _barcodeType = s.first;
                  if (_barcodeType == 'virtual') {
                    _barcodeCtrl.text =
                        'PACELLI-${const Uuid().v4().substring(0, 8).toUpperCase()}';
                  } else if (_barcodeType == 'none') {
                    _barcodeCtrl.clear();
                  }
                });
              },
            ),
            const SizedBox(height: 8),
            if (_barcodeType == 'real') ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _barcodeCtrl,
                      decoration:
                          InputDecoration(labelText: l10n.inventoryBarcode),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.qr_code_scanner),
                    tooltip: l10n.inventoryTapToScan,
                    onPressed: () async {
                      final code = await context.push<String>(
                          AppRoutes.barcodeScanner,
                          extra: widget.householdId);
                      if (code != null && mounted) {
                        setState(() => _barcodeCtrl.text = code);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (_barcodeType == 'virtual') ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.qr_code, color: Colors.green),
                title: Text(l10n.inventoryVirtualBarcodeGenerated),
                subtitle: Text(_barcodeCtrl.text),
              ),
              const SizedBox(height: 16),
            ],

            // Notes.
            TextFormField(
              controller: _notesCtrl,
              decoration: InputDecoration(labelText: l10n.inventoryNotes),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),

            // Save.
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.inventorySave),
            ),
            const SizedBox(height: 12),
            // Batch create.
            OutlinedButton.icon(
              onPressed: _saving || _nameCtrl.text.trim().isEmpty
                  ? null
                  : () {
                      context.push(AppRoutes.batchCreate, extra: {
                        'householdId': widget.householdId,
                        'baseName': _nameCtrl.text.trim(),
                        'categoryId': _categoryId,
                        'locationId': _locationId,
                        'unit': _unitCtrl.text.trim().isEmpty
                            ? 'pieces'
                            : _unitCtrl.text.trim(),
                        'expiryDate': _expiryDate,
                        'purchaseDate': _purchaseDate,
                        'notes': _notesCtrl.text.trim().isEmpty
                            ? null
                            : _notesCtrl.text.trim(),
                      });
                    },
              icon: const Icon(Icons.copy_all),
              label: Text(l10n.inventoryBatchCreate),
            ),
          ],
        ),
      ),
    );
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
      await repo.createInventoryItem(
        householdId: widget.householdId,
        name: _nameCtrl.text.trim(),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        categoryId: _categoryId,
        locationId: _locationId,
        quantity: int.tryParse(_quantityCtrl.text) ?? 0,
        unit: _unitCtrl.text.trim().isEmpty ? 'pieces' : _unitCtrl.text.trim(),
        lowStockThreshold: int.tryParse(_thresholdCtrl.text),
        barcode: _barcodeCtrl.text.trim().isEmpty
            ? null
            : _barcodeCtrl.text.trim(),
        barcodeType: _barcodeType,
        expiryDate: _expiryDate,
        purchaseDate: _purchaseDate,
        notes:
            _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.inventoryCreated)));
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
