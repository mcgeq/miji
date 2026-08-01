import 'package:flutter/material.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

import 'package:miji/shared/widgets/app_text_field.dart';

class AppAmountField extends StatelessWidget {
  const AppAmountField({
    super.key,
    this.controller,
    this.labelText = '金额',
    this.currencyCode = 'CNY',
    this.errorText,
    this.helperText,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.autofocus = false,
    this.textInputAction,
  });

  final TextEditingController? controller;
  final String labelText;
  final String currencyCode;
  final String? errorText;
  final String? helperText;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final bool autofocus;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = theme.radiusTokens;

    final prefix = Padding(
      padding: const EdgeInsets.only(left: 10, right: 6),
      child: Align(
        widthFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(radius.sm),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            child: Text(
              currencyCode,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );

    if (validator != null) {
      return AppTextFormField(
        controller: controller,
        labelText: labelText,
        helperText: helperText,
        errorText: errorText,
        enabled: enabled,
        autofocus: autofocus,
        textInputAction: textInputAction,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
        validator: validator,
        prefixIcon: prefix,
      );
    }

    return AppTextField(
      controller: controller,
      labelText: labelText,
      helperText: helperText,
      errorText: errorText,
      enabled: enabled,
      autofocus: autofocus,
      textInputAction: textInputAction,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      prefixIcon: prefix,
    );
  }
}
