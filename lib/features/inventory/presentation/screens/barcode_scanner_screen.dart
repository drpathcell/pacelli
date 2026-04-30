import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _cameraPermissionDenied = false;

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
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final errorMsg = context.l10n.commonError('Flash not available');
              try {
                await _controller.toggleTorch();
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text(errorMsg)),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final errorMsg =
                  context.l10n.commonError('Front camera not available');
              try {
                await _controller.switchCamera();
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text(errorMsg)),
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_cameraPermissionDenied)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.no_photography, size: 64, color: Colors.grey),
                  const SizedBox(height: 24),
                  const Text(
                    'Camera access denied. Please enable it in Settings.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => _openAppSettings(),
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            )
          else
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) {
                // Detect permission denial and show permission UI
                if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() => _cameraPermissionDenied = true);
                  });
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.no_photography, size: 64, color: Colors.grey),
                        const SizedBox(height: 24),
                        const Text(
                          'Camera access denied. Please enable it in Settings.',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => _openAppSettings(),
                          child: const Text('Open Settings'),
                        ),
                      ],
                    ),
                  );
                }
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 24),
                      Text(
                        'Camera Error',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          error.errorCode.toString(),
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.tonal(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.l10n.commonCancel),
                      ),
                    ],
                  ),
                );
              },
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
        // Found — navigate to item detail with stock info
        final item = match.first;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${context.l10n.inventoryScanFoundItem(item.name)} — ${item.quantity} ${item.unit}')),
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

  void _openAppSettings() async {
    final url = Uri.parse('app-settings:');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                context.l10n.commonError('Unable to open app settings'))),
      );
    }
  }
}
