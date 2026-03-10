import 'package:flutter/material.dart';

import '../utils/extensions.dart';

/// A friendly, reusable error view with icon, message, and retry button.
class ErrorView extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const ErrorView({
    super.key,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.error.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message ?? context.l10n.errorDefault,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(context.l10n.commonRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
