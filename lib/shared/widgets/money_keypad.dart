import 'package:flutter/material.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/shared/widgets/money_calculator.dart';

/// 金额输入用的自定义数字键盘。
///
/// 移动端记账时系统键盘会盖住半屏、并且没有「连算」和「再记一笔」。
/// 这里提供 4 × 4 键盘：数字 / . / 00 / ⌫ / ＋ / − / =。
class MoneyKeypad extends StatelessWidget {
  const MoneyKeypad({
    super.key,
    required this.onKey,
    this.pendingLabel,
    this.enabled = true,
  });

  final ValueChanged<String> onKey;

  /// 待完成算式，例如「38.00 ＋」。
  final String? pendingLabel;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pendingLabel != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calculate_rounded,
                  size: 15,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '等待计算：$pendingLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                Text(
                  '按 = 结算',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        for (final row in MoneyKeypadKeys.rows) ...[
          Row(
            children: [
              for (final key in row)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: _KeypadKey(
                      label: key,
                      enabled: enabled,
                      onTap: () => onKey(key),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _KeypadKey extends StatelessWidget {
  const _KeypadKey({
    required this.label,
    required this.onTap,
    required this.enabled,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isOperator =
        label == MoneyKeypadKeys.add ||
        label == MoneyKeypadKeys.subtract ||
        label == MoneyKeypadKeys.equals;
    final isBackspace = label == MoneyKeypadKeys.backspace;

    final foreground = !enabled
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
        : isOperator
        ? colorScheme.primary
        : colorScheme.onSurface;

    return Material(
      color: isOperator
          ? colorScheme.primaryContainer.withValues(alpha: 0.42)
          : colorScheme.surface,
      borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
        onTap: enabled ? onTap : null,
        child: Semantics(
          button: true,
          label: _semanticLabel(label),
          child: Container(
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: isBackspace
                ? Icon(Icons.backspace_outlined, size: 19, color: foreground)
                : Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  String _semanticLabel(String label) {
    return switch (label) {
      MoneyKeypadKeys.backspace => '退格',
      MoneyKeypadKeys.add => '加',
      MoneyKeypadKeys.subtract => '减',
      MoneyKeypadKeys.equals => '等于',
      _ => label,
    };
  }
}
