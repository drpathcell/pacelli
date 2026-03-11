import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/utils/extensions.dart';

/// Full-screen view of a virtual barcode as a QR code.
class VirtualBarcodeViewScreen extends StatelessWidget {
  final String itemName;
  final String barcode;

  const VirtualBarcodeViewScreen({
    super.key,
    required this.itemName,
    required this.barcode,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.inventoryQrCodeTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(itemName, style: context.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                l10n.inventoryQrCodeSubtitle,
                style: context.textTheme.bodyMedium
                    ?.copyWith(color: context.colorScheme.outline),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: barcode,
                  version: QrVersions.auto,
                  size: 240,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                barcode,
                style: context.textTheme.bodySmall
                    ?.copyWith(color: context.colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
