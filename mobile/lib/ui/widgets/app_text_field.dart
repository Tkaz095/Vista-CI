import 'package:flutter/material.dart';

class AppTextField extends StatefulWidget {
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
    this.suffixIcon,
    this.enabled = true,
    this.maxLength,
    this.minLines = 1,
    this.maxLines = 1,
    this.isSearch = false,
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
  final Widget? suffixIcon;
  final bool enabled;
  final int? maxLength;
  final int minLines;
  final int? maxLines;
  final bool isSearch;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted && _isFocused != _focusNode.hasFocus) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final borderRadius = BorderRadius.circular(widget.isSearch ? 24 : 14);

    final effectivePrefixIcon = widget.prefixIcon != null
        ? Icon(widget.prefixIcon, size: 20)
        : (widget.isSearch ? const Icon(Icons.search_rounded, size: 20) : null);

    // Search capsule border overrides
    final searchBorder = widget.isSearch
        ? OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: BorderSide(
              color: colors.outlineVariant.withValues(
                alpha: isDark ? 0.5 : 0.8,
              ),
              width: 1.0,
            ),
          )
        : null;

    final searchFocusedBorder = widget.isSearch
        ? OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: BorderSide(color: colors.primary, width: 1.8),
          )
        : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: colors.primary.withValues(alpha: isDark ? 0.3 : 0.14),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: TextFormField(
        focusNode: _focusNode,
        controller: widget.controller,
        initialValue: widget.initialValue,
        onChanged: widget.onChanged,
        validator: widget.validator,
        enabled: widget.enabled,
        maxLength: widget.maxLength,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colors.onSurface,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          helperText: widget.helperText,
          helperMaxLines: 3,
          prefixIcon: effectivePrefixIcon,
          suffixIcon: widget.suffixIcon,
          border: searchBorder,
          enabledBorder: searchBorder,
          focusedBorder: searchFocusedBorder,
        ),
      ),
    );
  }
}
