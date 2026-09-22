import 'package:flutter/material.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/shared/widgets/app_amount_field.dart';
import 'package:miji/shared/widgets/money_calculator.dart';
import 'package:miji/shared/widgets/money_keypad.dart';

/// 金额输入的统一封装。
///
/// * **移动端**：把金额大字 + 数字键盘作为一个固定停靠面板
///   （交给 `AppDialogScaffold.bottomDock`），和系统键盘一样贴在底部，
///   内容区在它上方滚动；支持「38 ＋ 12 =」连算。
/// * **宽屏 / 桌面**：保持原来的 [AppAmountField]（系统键盘）。
/// * 其他文本输入框拉起系统键盘时，停靠键盘自动让位，避免两个键盘同时出现。
///
/// 内部始终把计算结果写回 [controller]，所以表单原有的
/// `parseMoneyAmountToMinor(controller.text)` 校验逻辑不用改。
class MoneyAmountInput {
  MoneyAmountInput({
    int? initialAmountMinor,
    this.currencyCode = 'CNY',
    this.labelText = '金额',
  }) {
    if (initialAmountMinor != null) {
      seed(initialAmountMinor);
    }
  }

  final String currencyCode;
  final String labelText;

  final TextEditingController controller = TextEditingController();

  MoneyCalculator _calculator = MoneyCalculator.empty;
  bool _seeded = false;

  MoneyCalculator get calculator => _calculator;

  bool get isEmpty => _calculator.isEmpty;

  /// 用已有金额初始化（编辑场景）：第一次按键会整体覆盖。
  void seed(int amountMinor) {
    _calculator = MoneyCalculator(
      input: (amountMinor / 100).toStringAsFixed(2),
    );
    _seeded = true;
    controller.text = _calculator.display;
  }

  void clear() {
    _calculator = MoneyCalculator.empty;
    _seeded = false;
    controller.clear();
  }

  /// 按下键盘上的一个键。
  void press(String key) {
    // 编辑态下第一次按数字：直接覆盖，而不是往已有金额后面拼。
    if (_seeded && key != MoneyKeypadKeys.backspace) {
      _calculator = MoneyCalculator.empty;
    }
    _seeded = false;
    _calculator = _calculator.press(key);
    controller.text = _calculator.display;
  }

  void dispose() {
    controller.dispose();
  }

  /// 移动端且系统键盘未弹出时使用自带键盘。
  bool shouldDock(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 700) {
      return false;
    }
    return MediaQuery.viewInsetsOf(context).bottom == 0;
  }

  /// 宽屏下的普通输入框。
  Widget buildField({
    bool autofocus = false,
    bool prominent = true,
    String? labelText,
    ValueChanged<String>? onChanged,
  }) {
    return AppAmountField(
      controller: controller,
      labelText: labelText ?? this.labelText,
      currencyCode: currencyCode,
      autofocus: autofocus,
      prominent: prominent,
      onChanged: onChanged,
    );
  }

  /// 移动端停靠在底部的金额显示 + 键盘。
  Widget buildDock(
    BuildContext context, {
    required VoidCallback onChanged,
    bool enabled = true,
  }) {
    return _KeypadDock(
      value: _calculator.display,
      currencyCode: currencyCode,
      pendingLabel: _calculator.pendingLabel,
      enabled: enabled,
      onKey: (key) {
        press(key);
        onChanged();
      },
    );
  }
}

class _KeypadDock extends StatelessWidget {
  const _KeypadDock({
    required this.value,
    required this.currencyCode,
    required this.pendingLabel,
    required this.enabled,
    required this.onKey,
  });

  final String value;
  final String currencyCode;
  final String? pendingLabel;
  final bool enabled;
  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.32),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.48),
                    borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    child: Text(
                      currencyCode,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      value.isEmpty ? '0.00' : value,
                      maxLines: 1,
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: value.isEmpty
                            ? colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.5,
                              )
                            : colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            MoneyKeypad(
              enabled: enabled,
              pendingLabel: pendingLabel,
              onKey: onKey,
            ),
          ],
        ),
      ),
    );
  }
}
