import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:miji/core/presentation/components/app_field_style.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.suffixText,
    this.keyboardType,
    this.obscureText = false,
    this.minLines,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.textInputAction,
    this.inputFormatters,
    this.autofillHints,
    this.enableSuggestions,
    this.autocorrect = true,
    this.compact = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? suffixText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? minLines;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final bool? enableSuggestions;
  final bool autocorrect;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = theme.radiusTokens;
    final controls = theme.controlTokens;
    final borderRadius = BorderRadius.circular(radius.md);

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: compact ? controls.compactFieldHeight : controls.fieldHeight,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        autofocus: autofocus,
        keyboardType: keyboardType,
        obscureText: obscureText,
        minLines: minLines,
        maxLines: maxLines,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: textInputAction,
        inputFormatters: inputFormatters,
        autofillHints: autofillHints,
        enableSuggestions: enableSuggestions ?? !obscureText,
        autocorrect: obscureText ? false : autocorrect,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        decoration: appInputDecoration(
          context,
          labelText: labelText,
          hintText: hintText,
          helperText: helperText,
          errorText: errorText,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          suffixText: suffixText,
          enabled: enabled,
          borderRadius: borderRadius,
          compact: compact,
        ),
      ),
    );
  }
}

class AppTextFormField extends StatelessWidget {
  const AppTextFormField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.suffixText,
    this.keyboardType,
    this.obscureText = false,
    this.minLines,
    this.maxLines = 1,
    this.onChanged,
    this.onFieldSubmitted,
    this.validator,
    this.enabled = true,
    this.autofocus = false,
    this.textInputAction,
    this.inputFormatters,
    this.autofillHints,
    this.enableSuggestions,
    this.autocorrect = true,
    this.compact = false,
  });

  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? suffixText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? minLines;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final bool? enableSuggestions;
  final bool autocorrect;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = theme.radiusTokens;
    final controls = theme.controlTokens;
    final borderRadius = BorderRadius.circular(radius.md);

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: compact ? controls.compactFieldHeight : controls.fieldHeight,
      ),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        autofocus: autofocus,
        keyboardType: keyboardType,
        obscureText: obscureText,
        minLines: minLines,
        maxLines: maxLines,
        onChanged: onChanged,
        onFieldSubmitted: onFieldSubmitted,
        validator: validator,
        textInputAction: textInputAction,
        inputFormatters: inputFormatters,
        autofillHints: autofillHints,
        enableSuggestions: enableSuggestions ?? !obscureText,
        autocorrect: obscureText ? false : autocorrect,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        decoration: appInputDecoration(
          context,
          labelText: labelText,
          hintText: hintText,
          helperText: helperText,
          errorText: errorText,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          suffixText: suffixText,
          enabled: enabled,
          borderRadius: borderRadius,
          compact: compact,
        ),
      ),
    );
  }
}

InputDecoration appInputDecoration(
  BuildContext context, {
  String? labelText,
  String? hintText,
  String? helperText,
  String? errorText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? suffixText,
  required bool enabled,
  BorderRadius? borderRadius,
  bool compact = false,
}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final radius = theme.radiusTokens;
  final resolvedBorderRadius = borderRadius ?? BorderRadius.circular(radius.md);

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    helperText: helperText,
    errorText: errorText,
    prefixIcon: prefixIcon == null
        ? null
        : IconTheme(
            data: IconThemeData(
              size: compact ? 18 : 20,
              color: colorScheme.onSurfaceVariant,
            ),
            child: prefixIcon,
          ),
    prefixIconConstraints: compact
        ? const BoxConstraints(minWidth: 38, minHeight: 40)
        : null,
    suffixIcon: suffixIcon,
    suffixIconConstraints: compact
        ? const BoxConstraints(minWidth: 38, minHeight: 40)
        : null,
    suffixText: suffixText,
    suffixStyle: theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    ),
    filled: true,
    fillColor: appFieldFillColor(colorScheme, enabled: enabled),
    contentPadding: EdgeInsets.symmetric(
      horizontal: compact ? 10 : 12,
      vertical: compact ? 8 : 11,
    ),
    isDense: compact,
    border: OutlineInputBorder(
      borderRadius: resolvedBorderRadius,
      borderSide: BorderSide(
        color: appFieldBorderColor(colorScheme, enabled: enabled),
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: resolvedBorderRadius,
      borderSide: BorderSide(
        color: appFieldBorderColor(colorScheme, enabled: enabled),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: resolvedBorderRadius,
      borderSide: BorderSide(
        color: appFieldBorderColor(
          colorScheme,
          enabled: enabled,
          focused: true,
        ),
        width: 1.4,
      ),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: resolvedBorderRadius,
      borderSide: BorderSide(
        color: appFieldBorderColor(colorScheme, enabled: false),
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: resolvedBorderRadius,
      borderSide: BorderSide(color: colorScheme.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: resolvedBorderRadius,
      borderSide: BorderSide(color: colorScheme.error, width: 1.4),
    ),
  );
}
