import 'package:flutter/foundation.dart';

/// 自定义数字键盘的按键（以「要展示的字符」为准）。
class MoneyKeypadKeys {
  const MoneyKeypadKeys._();

  static const backspace = '⌫';
  static const add = '＋';
  static const subtract = '−';
  static const equals = '=';

  /// 4 × 4 布局，与主流记账 App 一致（7-9 在顶部）。
  static const rows = <List<String>>[
    ['7', '8', '9', backspace],
    ['4', '5', '6', add],
    ['1', '2', '3', subtract],
    ['00', '0', '.', equals],
  ];
}

/// 金额输入的计算器状态（支持「38 ＋ 12 =」这种连算）。
///
/// 记账时经常要把几笔小金额先加总再录入（一单里的菜价、一次出行的几段车费），
/// 原来的实现直接用系统键盘，做不到。这里是纯函数式状态机，便于单测。
@immutable
class MoneyCalculator {
  const MoneyCalculator({
    this.accumulatorMinor,
    this.pendingOperator,
    this.input = '',
  });

  static const empty = MoneyCalculator();

  /// 已经确定的累计值（单位：分）。
  final int? accumulatorMinor;

  /// 待应用的运算符：'+' / '-'。
  final String? pendingOperator;

  /// 当前正在输入的原始串，例如 '12.5'。
  final String input;

  bool get isEmpty =>
      accumulatorMinor == null && pendingOperator == null && input.isEmpty;

  /// 当前应写回金额输入框的文本。
  String get display {
    if (input.isNotEmpty) {
      return input;
    }
    final accumulator = accumulatorMinor;
    if (accumulator == null) {
      return '';
    }
    return _minorToText(accumulator);
  }

  /// 待完成的算式提示，例如「38.00 ＋」。
  String? get pendingLabel {
    final operator = pendingOperator;
    final accumulator = accumulatorMinor;
    if (operator == null || accumulator == null) {
      return null;
    }
    return '${_minorToText(accumulator)} '
        '${operator == '+' ? MoneyKeypadKeys.add : MoneyKeypadKeys.subtract}';
  }

  /// 当前金额（分）。还没输入时返回 null。
  int? get amountMinor {
    final accumulator = accumulatorMinor;
    final current = _parseMinor(input);
    if (accumulator == null) {
      return current;
    }
    final operator = pendingOperator;
    if (operator == null) {
      return current ?? accumulator;
    }
    if (current == null) {
      return accumulator;
    }
    return switch (operator) {
      '+' => accumulator + current,
      '-' => accumulator - current,
      _ => accumulator,
    };
  }

  MoneyCalculator press(String key) {
    if (key.isEmpty) {
      return this;
    }
    if (key == MoneyKeypadKeys.backspace) {
      return _backspace();
    }
    if (key == MoneyKeypadKeys.add || key == MoneyKeypadKeys.subtract) {
      return _applyOperator(key == MoneyKeypadKeys.add ? '+' : '-');
    }
    if (key == MoneyKeypadKeys.equals) {
      return _commit();
    }
    return _append(key);
  }

  MoneyCalculator _append(String key) {
    if (key == '.') {
      if (input.contains('.')) {
        return this;
      }
      return _copyWith(input: input.isEmpty ? '0.' : '$input.');
    }
    if (key == '00') {
      if (input.isEmpty) {
        return this;
      }
      return _appendDigits('00');
    }
    return _appendDigits(key);
  }

  MoneyCalculator _appendDigits(String digits) {
    // 最多两位小数。
    final dotIndex = input.indexOf('.');
    if (dotIndex >= 0 && input.length - dotIndex - 1 >= 2) {
      return this;
    }
    final next = input == '0' && !digits.startsWith('.')
        ? digits
        : '$input$digits';
    // 防止手滑输入一长串数字。
    if (next.replaceAll('.', '').length > 12) {
      return this;
    }
    return _copyWith(input: next);
  }

  MoneyCalculator _backspace() {
    if (input.isNotEmpty) {
      return _copyWith(input: input.substring(0, input.length - 1));
    }
    if (pendingOperator != null) {
      return _copyWith(clearOperator: true);
    }
    if (accumulatorMinor != null) {
      return _copyWith(clearAccumulator: true);
    }
    return this;
  }

  MoneyCalculator _applyOperator(String operator) {
    final folded = amountMinor;
    if (folded == null) {
      return this;
    }
    return MoneyCalculator(accumulatorMinor: folded, pendingOperator: operator);
  }

  MoneyCalculator _commit() {
    if (pendingOperator == null) {
      return this;
    }
    final folded = amountMinor;
    if (folded == null) {
      return _copyWith(clearOperator: true);
    }
    return MoneyCalculator(accumulatorMinor: folded);
  }

  MoneyCalculator _copyWith({
    String? input,
    bool clearOperator = false,
    bool clearAccumulator = false,
  }) {
    return MoneyCalculator(
      accumulatorMinor: clearAccumulator ? null : accumulatorMinor,
      pendingOperator: clearOperator ? null : pendingOperator,
      input: input ?? this.input,
    );
  }

  static int? _parseMinor(String value) {
    if (value.isEmpty) {
      return null;
    }
    final parsed = double.tryParse(value);
    if (parsed == null) {
      return null;
    }
    return (parsed * 100).round();
  }

  static String _minorToText(int minor) => (minor / 100).toStringAsFixed(2);
}
