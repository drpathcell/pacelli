import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../core/data/data_repository_provider.dart';
import '../../../../core/utils/extensions.dart';

/// Camera-based barcode/QR scanner for inventory items.
class BarcodeScannerScreen extends ConsumerStatefulWidget {
  final String householdId;

  const BarcodeScannerScreen({super.key, required this.householdId});

  @override
  ConsumerState<BarcodeScannerScreen> createState() =>
      _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;
  String? _lastScanned;
  DateTime? _lastScannedAt;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.inventoryScanBarcode),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (_, state, __) {
                return Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
                );
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Overlay prompt
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  l10n.inventoryScanPrompt,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    // Debounce: ignore duplicate detections within 2 seconds.
    final now = DateTime.now();
    if (code == _lastScanned &&
        _lastScannedAt != null &&
        now.difference(_lastScannedAt!).inSeconds < 2) {
      return;
    }

    setState(() {
      _processing = true;
      _lastScanned = code;
      _lastScannedAt = now;
    });

    try {
      // Show confirmation before acting on the scan.
      final confirmed = await _showConfirmationSheet(code);
      if (confirmed != true) {
        // User chose to rescan — reset and allow new detections.
        if (mounted) {
          setState(() {
            _processing = false;
            _lastScanned = null;
            _lastScannedAt = null;
          });
        }
        return;
      }

      final repo = ref.read(dataRepositoryProvider);
      final items =
          await repo.getInventoryItems(householdId: widget.householdId);
      final match = items.where((item) => item.barcode == code).toList();

      if (!mounted) return;

      if (match.isNotEmpty) {
        // Found — navigate to item detail
        final item = match.first;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(context.l10n.inventoryScanFoundItem(item.name))),
        );
        context.pop(); // Close scanner
        context.push(AppRoutes.inventoryItem, extra: {
          'householdId': widget.householdId,
          'itemId': item.id,
        });
      } else {
        // Not found — offer to create with this barcode
        final create = await _showNotFoundDialog(code);
        if (create == true && mounted) {
          context.pop(code); // Return barcode to caller
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.commonError(e.toString()))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<bool?> _showConfirmationSheet(String code) {
    final l10n = context.l10n;
    return showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.qr_code_scanner, size: 48),
              const SizedBox(height: 16),
              Text(l10n.inventoryScanConfirmTitle,
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(code,
                  style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      )),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => ctx.pop(false),
                      child: Text(l10n.inventoryScanRescan),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => ctx.pop(true),
                      child: Text(l10n.inventoryScanConfirm),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showNotFoundDialog(String code) {
    final l10n = context.l10n;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.inventoryScanNotFound),
        content: Text(code),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => ctx.pop(true),
            child: Text(l10n.inventoryAddItem),
          ),
        ],
      ),
    );
  }
}
