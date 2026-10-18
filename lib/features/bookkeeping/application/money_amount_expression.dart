/// 金额输入框的四则运算支持。
///
/// 记账时经常要现场合计小票（`12.5+38+6`），而金额框原本只吃纯数字。
/// 这里提供一个**受限**的表达式求值器：只认数字、`+ - * /`（也接受 `× ÷`）、
/// 括号和一元负号，没有任何函数调用、变量或隐式语法——手写分词 + 递归下降，
/// 不走 `dart:mirrors` 之类的动态求值，输入再离谱也只是解析失败。
class MoneyAmountExpression {
  const MoneyAmountExpression._();

  static final RegExp _operatorChar = RegExp(r'[+\-*/×÷]');

  /// 把中文/全角输入法常见的符号归一化成 ASCII。
  ///
  /// 手机输入法在中文状态下敲出来的往往是 `＋ － ＊ ／ （ ）`，
  /// 不归一化的话用户会以为「计算器坏了」。
  static String normalize(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final replacement = switch (rune) {
        0xFF0B => '+', // ＋
        0xFF0D || 0x2212 => '-', // － −
        0xFF0A || 0x00D7 => '*', // ＊ ×
        0xFF0F || 0x00F7 => '/', // ／ ÷
        0xFF08 => '(', // （
        0xFF09 => ')', // ）
        0x3002 => '.', // 。
        // 千分位、空格、货币符号：直接丢掉，不影响求值。
        0x002C ||
        0xFF0C ||
        0x0020 ||
        0x00A0 ||
        0xFFE5 ||
        0x00A5 ||
        0x0024 => '',
        // 全角数字 ０-９。
        >= 0xFF10 && <= 0xFF19 => String.fromCharCode(rune - 0xFF10 + 0x30),
        _ => null,
      };
      if (replacement != null) {
        buffer.write(replacement);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  /// 输入是否「看起来像」表达式（而不是一个普通数字）。
  ///
  /// 只用来决定要不要在输入框下方显示 `= ¥56.50` 预览：
  /// 单个 `-5` 这类只有一个数字的输入不算表达式，避免把负数也标成算式。
  static bool isExpression(String input) {
    final normalized = normalize(input);
    if (!_operatorChar.hasMatch(normalized)) {
      return false;
    }
    try {
      return _Parser(normalized).countNumbers() >= 2;
    } on _ExpressionError {
      return false;
    }
  }

  /// 求值，返回「元」为单位的 double；不是合法表达式时返回 null。
  static double? tryEvaluate(String input) {
    final normalized = normalize(input).trim();
    if (normalized.isEmpty) {
      return null;
    }
    try {
      final parser = _Parser(normalized);
      final value = parser.parseExpression();
      parser.expectEnd();
      if (value.isNaN || value.isInfinite) {
        return null;
      }
      return value;
    } on _ExpressionError {
      return null;
    }
  }

  /// 求值并换算成「分」；不是合法表达式时返回 null。
  static int? tryEvaluateToMinor(String input) {
    final value = tryEvaluate(input);
    if (value == null) {
      return null;
    }
    return (value * 100).round();
  }
}

class _ExpressionError implements Exception {
  const _ExpressionError();
}

enum _TokenType { number, plus, minus, star, slash, openParen, closeParen, end }

class _Token {
  const _Token(this.type, [this.value = 0]);

  final _TokenType type;
  final double value;
}

/// 手写分词 + 递归下降解析器。
///
/// 文法：
/// ```
/// expr   := term (('+' | '-') term)*
/// term   := unary (('*' | '/') unary)*
/// unary  := ('-' | '+') unary | primary
/// primary:= number | '(' expr ')'
/// ```
class _Parser {
  _Parser(this._source) {
    _tokenize();
  }

  final String _source;
  final List<_Token> _tokens = <_Token>[];
  int _index = 0;

  void _tokenize() {
    var i = 0;
    while (i < _source.length) {
      final char = _source[i];
      if (char == ' ' || char == '\t') {
        i++;
        continue;
      }
      switch (char) {
        case '+':
          _tokens.add(const _Token(_TokenType.plus));
          i++;
          continue;
        case '-':
          _tokens.add(const _Token(_TokenType.minus));
          i++;
          continue;
        case '*':
          _tokens.add(const _Token(_TokenType.star));
          i++;
          continue;
        case '/':
          _tokens.add(const _Token(_TokenType.slash));
          i++;
          continue;
        case '(':
          _tokens.add(const _Token(_TokenType.openParen));
          i++;
          continue;
        case ')':
          _tokens.add(const _Token(_TokenType.closeParen));
          i++;
          continue;
      }

      final start = i;
      while (i < _source.length && _isDigitOrDot(_source[i])) {
        i++;
      }
      if (i == start) {
        throw const _ExpressionError();
      }
      final text = _source.substring(start, i);
      if ('.'.allMatches(text).length > 1) {
        throw const _ExpressionError();
      }
      final value = double.tryParse(text);
      if (value == null) {
        throw const _ExpressionError();
      }
      _tokens.add(_Token(_TokenType.number, value));
    }
    _tokens.add(const _Token(_TokenType.end));
  }

  static bool _isDigitOrDot(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 48 && code <= 57) || code == 46;
  }

  /// 供 [MoneyAmountExpression.isExpression] 使用：只数数字，不做完整解析。
  int countNumbers() {
    try {
      var count = 0;
      for (final token in _tokens) {
        if (token.type == _TokenType.number) {
          count++;
        }
      }
      return count;
    } on _ExpressionError {
      return 0;
    }
  }

  double parseExpression() {
    var value = parseTerm();
    while (true) {
      final type = _peek().type;
      if (type == _TokenType.plus) {
        _advance();
        value += parseTerm();
      } else if (type == _TokenType.minus) {
        _advance();
        value -= parseTerm();
      } else {
        return value;
      }
    }
  }

  double parseTerm() {
    var value = parseUnary();
    while (true) {
      final type = _peek().type;
      if (type == _TokenType.star) {
        _advance();
        value *= parseUnary();
      } else if (type == _TokenType.slash) {
        _advance();
        final divisor = parseUnary();
        if (divisor == 0) {
          throw const _ExpressionError();
        }
        value /= divisor;
      } else {
        return value;
      }
    }
  }

  double parseUnary() {
    final type = _peek().type;
    if (type == _TokenType.minus) {
      _advance();
      return -parseUnary();
    }
    if (type == _TokenType.plus) {
      _advance();
      return parseUnary();
    }
    return parsePrimary();
  }

  double parsePrimary() {
    final token = _peek();
    if (token.type == _TokenType.number) {
      _advance();
      return token.value;
    }
    if (token.type == _TokenType.openParen) {
      _advance();
      final value = parseExpression();
      if (_peek().type != _TokenType.closeParen) {
        throw const _ExpressionError();
      }
      _advance();
      return value;
    }
    throw const _ExpressionError();
  }

  void expectEnd() {
    if (_peek().type != _TokenType.end) {
      throw const _ExpressionError();
    }
  }

  _Token _peek() => _tokens[_index];

  void _advance() {
    _index++;
  }
}
