import 'package:flutter/material.dart';

class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.label, this.onDeleted});

  final String label;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) => InputChip(
    label: Text(label),
    tooltip: label,
    onDeleted: onDeleted,
    deleteButtonTooltipMessage: 'Bỏ $label',
  );
}
