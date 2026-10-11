import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/application/money_amount_expression.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_currency_codes.dart';

/// 金额计算器面板：合计小票这类现场运算不用再切出去按系统计算器。
///
/// 返回结算结果的十进制字符串（如 `56.50`），取消返回 null。
/// 面板自己只负责拼表达式，求值统一走 [MoneyAmountExpression]，
/// 与金额框直接输入 `12.5+38+6` 走的是同一套规则。
Future<String?> showAmountCalculatorSheet(
  BuildContext context, {
  String? initialText,
  String currencyCode = defaultMoneyCurrencyCode,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _AmountCalculatorSheet(
      initialText: initialText,
      currencyCode: currencyCode,
    ),
  );
}

class _AmountCalculatorSheet extends StatefulWidget {
  const _AmountCalculatorSheet({this.initialText, required this.currencyCode});

  final String? initialText;
  final String currencyCode;

  @override
  State<_AmountCalculatorSheet> createState() => _AmountCalculatorSheetState();
}

class _AmountCalculatorSheetState extends State<_AmountCalculatorSheet> {
  late String _expression;
  double? _result;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final initial = MoneyAmountExpression.normalize(
      widget.initialText ?? '',
    ).trim();
    _expression = initial;
    _recompute();
  }

  void _recompute() {
    if (_expression.isEmpty) {
      _result = null;
      return;
    }
    _result = MoneyAmountExpression.tryEvaluate(_expression);
  }

  void _append(String token) {
    setState(() {
      _errorText = null;
      // 上一步刚算出结果、用户又按了数字/左括号：视为开始一个新的算式。
      if (_isBareResult) {
        if (token == '(' || _isDigitOrDot(token)) {
          _expression = '';
        }
      }
      _expression += token;
      _recompute();
    });
  }

  void _backspace() {
    if (_expression.isEmpty) {
      return;
    }
    setState(() {
      _errorText = null;
      _expression = _expression.substring(0, _expression.length - 1);
      _recompute();
    });
  }

  void _clear() {
    setState(() {
      _errorText = null;
      _expression = '';
      _result = null;
    });
  }

  /// 等号：把当前表达式折叠成一个纯数字，方便继续往下算。
  void _equals() {
    final value = MoneyAmountExpression.tryEvaluate(_expression);
    setState(() {
      if (value == null) {
        _errorText = '算式无法计算，请检查';
        return;
      }
      _errorText = null;
      _expression = value.toStringAsFixed(2);
      _result = value;
    });
  }

  void _confirm() {
    final value = MoneyAmountExpression.tryEvaluate(_expression);
    if (value == null || value.isNaN || value.isInfinite) {
      setState(() => _errorText = '算式无法计算，请检查');
      return;
    }
    if (value <= 0) {
      setState(() => _errorText = '金额必须大于 0');
      return;
    }
    Navigator.of(context).pop(value.toStringAsFixed(2));
  }

  /// 当前显示的是不是一个「刚算完的裸数字」（后续按键的行为需要区分）。
  bool get _isBareResult {
    final text = _expression;
    if (text.isEmpty) {
      return false;
    }
    return !MoneyAmountExpression.isExpression(text) &&
        double.tryParse(text) != null;
  }

  static bool _isDigitOrDot(String token) {
    if (token.length != 1) {
      return false;
    }
    final code = token.codeUnitAt(0);
    return (code >= 48 && code <= 57) || code == 46;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = theme.spacingTokens;

    final resultText = _result == null
        ? '—'
        : formatMoneyMinor((_result! * 100).round(), widget.currencyCode);

    return Padding(
      padding: EdgeInsets.only(
        left: spacing.cardPadding,
        right: spacing.cardPadding,
        bottom: spacing.cardPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '金额计算器',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          AppSurface(
            tone: AppSurfaceTone.subtle,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 24,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _expression.isEmpty ? '0' : _expression,
                        maxLines: 1,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  resultText,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: _result == null
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
                letterSpacing: 0,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _keyRow([
            _KeySpec('AC', _clear, tone: _KeyTone.neutral),
            _KeySpec('⌫', _backspace, tone: _KeyTone.neutral),
            _KeySpec('(', () => _append('('), tone: _KeyTone.neutral),
            _KeySpec(')', () => _append(')'), tone: _KeyTone.neutral),
          ]),
          const SizedBox(height: 8),
          _keyRow([
            _KeySpec('7', () => _append('7')),
            _KeySpec('8', () => _append('8')),
            _KeySpec('9', () => _append('9')),
            _KeySpec('÷', () => _append('/'), tone: _KeyTone.operator),
          ]),
          const SizedBox(height: 8),
          _keyRow([
            _KeySpec('4', () => _append('4')),
            _KeySpec('5', () => _append('5')),
            _KeySpec('6', () => _append('6')),
            _KeySpec('×', () => _append('*'), tone: _KeyTone.operator),
          ]),
          const SizedBox(height: 8),
          _keyRow([
            _KeySpec('1', () => _append('1')),
            _KeySpec('2', () => _append('2')),
            _KeySpec('3', () => _append('3')),
            _KeySpec('−', () => _append('-'), tone: _KeyTone.operator),
          ]),
          const SizedBox(height: 8),
          _keyRow([
            _KeySpec('0', () => _append('0'), flex: 2),
            _KeySpec('.', () => _append('.')),
            _KeySpec('+', () => _append('+'), tone: _KeyTone.operator),
          ]),
          const SizedBox(height: 12),
          Row(
            children: [
              _KeyButton(
                spec: _KeySpec('=', _equals, tone: _KeyTone.operator),
                height: 48,
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  onPressed: _confirm,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('使用此金额'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _keyRow(List<_KeySpec> specs) {
    return Row(
      children: [
        for (var i = 0; i < specs.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _KeyButton(spec: specs[i]),
        ],
      ],
    );
  }
}

enum _KeyTone { digit, neutral, operator }

class _KeySpec {
  const _KeySpec(
    this.label,
    this.onTap, {
    this.tone = _KeyTone.digit,
    this.flex = 1,
  });

  final String label;
  final VoidCallback onTap;
  final _KeyTone tone;
  final int flex;
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.spec, this.height = 52});

  final _KeySpec spec;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = theme.radiusTokens;

    final isOperator = spec.tone == _KeyTone.operator;
    final background = switch (spec.tone) {
      _KeyTone.operator => colorScheme.primaryContainer,
      _KeyTone.neutral => colorScheme.surfaceContainerHighest,
      _KeyTone.digit => colorScheme.surfaceContainerHigh,
    };
    final foreground = isOperator
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;

    return Expanded(
      flex: spec.flex,
      child: SizedBox(
        height: height,
        child: Material(
          color: background,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius.md),
          ),
          child: InkWell(
            onTap: spec.onTap,
            child: Center(
              child: Text(
                spec.label,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
