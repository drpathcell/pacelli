import 'package:flutter/material.dart';

/// A +/- quantity adjustment widget.
class QuantityAdjuster extends StatelessWidget {
  final int quantity;
  final String unit;
  final ValueChanged<int> onChanged;

  const QuantityAdjuster({
    super.key,
    required this.quantity,
    required this.unit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          onPressed: quantity > 0 ? () => onChanged(quantity - 1) : null,
          icon: const Icon(Icons.remove),
          style: IconButton.styleFrom(
            minimumSize: const Size(36, 36),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '$quantity $unit',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        IconButton.filled(
          onPressed: () => onChanged(quantity + 1),
          icon: const Icon(Icons.add),
          style: IconButton.styleFrom(
            minimumSize: const Size(36, 36),
          ),
        ),
      ],
    );
  }
}
