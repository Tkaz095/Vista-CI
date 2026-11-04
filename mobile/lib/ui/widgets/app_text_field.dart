import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.helperText,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.validator,
    this.prefixIcon,
    this.enabled = true,
    this.maxLength,
    this.minLines = 1,
    this.maxLines = 1,
  }) : assert(
         controller == null || initialValue == null,
         'Use either controller or initialValue, not both.',
       );

  final String label;
  final String? hint;
  final String? helperText;
  // The screen that creates a controller also disposes it.
  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final IconData? prefixIcon;
  final bool enabled;
  final int? maxLength;
  final int minLines;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    initialValue: initialValue,
    onChanged: onChanged,
    validator: validator,
    enabled: enabled,
    maxLength: maxLength,
    minLines: minLines,
    maxLines: maxLines,
    style: Theme.of(context).textTheme.bodyMedium,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helperText,
      helperMaxLines: 3,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
    ),
  );
}
