import 'package:flutter/material.dart';

/// A small outlined tag/chip, matching the reference app's `Tag.kt`
/// (32dp height, 8dp radius, 1dp `outlineVariant` border, `labelLarge`
/// text, 8dp horizontal padding).
class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(width: 1, color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}
