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
    this.prominent = false,
    this.previewText,
    this.onCalculatorTap,
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
  final bool prominent;

  /// 输入框下方的一行计算结果预览（如 `= ¥56.50`）。
  ///
  /// 由调用方算好再传进来：金额表达式的求值规则属于业务层，
  /// 共享组件不该反向依赖某个 feature。
  /// 非空时优先于 [helperText] 展示。
  final String? previewText;

  /// 传入后在输入框尾部出现计算器入口。
  final VoidCallback? onCalculatorTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = theme.radiusTokens;
    final resolvedHelperText = previewText ?? helperText;
    final suffix = onCalculatorTap == null
        ? null
        : IconButton(
            tooltip: '计算器',
            onPressed: onCalculatorTap,
            icon: const Icon(Icons.calculate_outlined, size: 20),
          );

    final prefix = Padding(
      padding: EdgeInsets.only(left: prominent ? 14 : 10, right: 6),
      child: Align(
        widthFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(radius.sm),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: prominent ? 9 : 7,
              vertical: prominent ? 5 : 3,
            ),
            child: Text(
              currencyCode,
              style:
                  (prominent
                          ? theme.textTheme.labelLarge
                          : theme.textTheme.labelSmall)
                      ?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
            ),
          ),
        ),
      ),
    );

    if (prominent) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: (validator != null
            ? _buildProminentFormField
            : _buildProminentField)(context, theme, prefix),
      );
    }

    if (validator != null) {
      return AppTextFormField(
        controller: controller,
        labelText: labelText,
        helperText: resolvedHelperText,
        errorText: errorText,
        enabled: enabled,
        autofocus: autofocus,
        textInputAction: textInputAction,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
        validator: validator,
        prefixIcon: prefix,
        suffixIcon: suffix,
      );
    }

    return AppTextField(
      controller: controller,
      labelText: labelText,
      helperText: resolvedHelperText,
      errorText: errorText,
      enabled: enabled,
      autofocus: autofocus,
      textInputAction: textInputAction,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      prefixIcon: prefix,
      suffixIcon: suffix,
    );
  }

  Widget _buildProminentFormField(
    BuildContext context,
    ThemeData theme,
    Widget prefix,
  ) {
    return TextFormField(
      controller: controller,
      validator: validator,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      textInputAction: textInputAction,
      style: _prominentStyle(theme),
      decoration: appInputDecoration(
        context,
        labelText: labelText,
        helperText: previewText ?? helperText,
        errorText: errorText,
        prefixIcon: prefix,
        suffixIcon: _prominentSuffix(),
        enabled: enabled,
        borderRadius: BorderRadius.circular(theme.radiusTokens.md),
      ).copyWith(prefixIconConstraints: const BoxConstraints(minWidth: 76)),
    );
  }

  Widget _buildProminentField(
    BuildContext context,
    ThemeData theme,
    Widget prefix,
  ) {
    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      textInputAction: textInputAction,
      style: _prominentStyle(theme),
      decoration: appInputDecoration(
        context,
        labelText: labelText,
        helperText: previewText ?? helperText,
        errorText: errorText,
        prefixIcon: prefix,
        suffixIcon: _prominentSuffix(),
        enabled: enabled,
        borderRadius: BorderRadius.circular(theme.radiusTokens.md),
      ).copyWith(prefixIconConstraints: const BoxConstraints(minWidth: 76)),
    );
  }

  Widget? _prominentSuffix() {
    final onTap = onCalculatorTap;
    if (onTap == null) {
      return null;
    }
    return IconButton(
      tooltip: '计算器',
      onPressed: onTap,
      icon: const Icon(Icons.calculate_outlined, size: 20),
    );
  }

  TextStyle _prominentStyle(ThemeData theme) {
    return theme.textTheme.headlineMedium!.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
    );
  }
}
