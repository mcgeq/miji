// cn_amount_parser.dart
// 端侧 ASR 输出文本的中文口语金额归一化 —— 纯 Dart，零依赖。
//
// 适用：voice_recognizer(Paraformer-zh) / sherpa_onnx(SenseVoice、Paraformer)
//       识别结果 -> 提取金额 -> 标出需要人工复核的项。
//
// 设计前提（重要）：
//   端侧短句模型对"类目/项目名"可靠（靠热词），对"金额数字"存在稳定的残留
//   错误率，这是结构性天花板，无法靠调解码参数消除。所以本模块不追求"猜对"，
//   而是把"我可能猜错了"这件事显式暴露给 UI 层，让金额字段高亮、可一键改。
//
// 用法：
//   final m = CnAmountParser.parse('午饭三十五块');
//   if (m != null && m.needsReview) { /* UI 高亮、弹确认 */ }

// 自测脚本的输出去 stdout：`print` 会触发 avoid_print（这条规则针对的是
// 会被打进生产包的 Flutter 代码），而这里的 main 只在 `dart run` 下执行。
import 'dart:io';

enum AmountConfidence {
  /// 有明确金额单位且无口语省略补全
  high,

  /// 有金额单位，但数字经过口语省略补全（如"一百一" -> 110）
  medium,

  /// 句中没有任何金额单位，取最后一个数字串兜底
  low,
}

class AmountMatch {
  final double amount;
  final AmountConfidence confidence;

  /// 命中的原文片段，便于 UI 高亮
  final String raw;

  /// 是否经过口语省略补全（"三千五" -> 3500）
  final bool elided;

  final int start;
  final int end;

  const AmountMatch({
    required this.amount,
    required this.confidence,
    required this.raw,
    required this.elided,
    required this.start,
    required this.end,
  });

  /// UI 层据此决定是否高亮 / 弹二次确认。
  /// 口语省略补全一律标为需复核：规则推断本身可能错（"一百一"也可能是 101）。
  bool get needsReview => elided || confidence != AmountConfidence.high;

  @override
  String toString() =>
      'AmountMatch($amount, ${confidence.name}, raw="$raw", elided=$elided)';
}

class CnAmountParser {
  static const Map<String, int> _digits = {
    '零': 0,
    '〇': 0,
    '一': 1,
    '幺': 1,
    '二': 2,
    '两': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
    '七': 7,
    '八': 8,
    '九': 9,
  };
  static const Map<String, int> _units = {'十': 10, '百': 100, '千': 1000};
  static const Map<String, int> _big = {'万': 10000, '亿': 100000000};

  static const List<String> _mainUnits = ['块钱', '块', '元', '圆', '人民币'];
  static const List<String> _jiaoUnits = ['毛', '角'];
  static const List<String> _fenUnits = ['分'];

  /// 主入口。解析不到返回 null。
  static AmountMatch? parse(String text) {
    final t = text.replaceAll(' ', '');
    if (t.isEmpty) return null;

    // 1) 显式主金额单位：块 / 元 / 圆 …
    for (final unit in _mainUnits) {
      final p = t.indexOf(unit);
      if (p < 0) continue;

      var start = p;
      while (start > 0 && _isNumeralChar(t.substring(start - 1, start))) {
        start--;
      }

      if (start < p) {
        final r = _scanNumeral(t, start);
        if (r.value != null && t.substring(start, start + 1) != '.') {
          final frac = _parseFraction(t.substring(p + unit.length));
          var v = r.value!;
          if (frac != null) v += frac;
          return AmountMatch(
            amount: _round2(v),
            confidence: r.elided
                ? AmountConfidence.medium
                : AmountConfidence.high,
            raw: t.substring(start, p + unit.length),
            elided: r.elided,
            start: start,
            end: p + unit.length,
          );
        }
      }

      // 主单位之前是小数（"六毛钱"）
      if (p > 0) {
        final frac = _parseFraction(t.substring(0, p));
        if (frac != null) {
          return AmountMatch(
            amount: _round2(frac),
            confidence: AmountConfidence.high,
            raw: t.substring(0, p),
            elided: false,
            start: 0,
            end: p,
          );
        }
      }
    }

    // 2) 只有 毛 / 角 / 分
    for (final m in _jiaoUnits + _fenUnits) {
      final p = t.indexOf(m);
      if (p < 0) continue;
      var start = p;
      while (start > 0 && _isNumeralChar(t.substring(start - 1, start))) {
        start--;
      }
      if (start < p) {
        final frac = _parseFraction(t.substring(start));
        if (frac != null) {
          return AmountMatch(
            amount: _round2(frac),
            confidence: AmountConfidence.high,
            raw: t.substring(start),
            elided: false,
            start: start,
            end: t.length,
          );
        }
      }
    }

    // 3) 兜底：句中最后一个数字串（"打车二十"这类完全不带单位的口语）
    _ScanResult? last;
    var lastStart = 0;
    var i = 0;
    while (i < t.length) {
      final r = _scanNumeral(t, i);
      if (r.value != null && r.end > i) {
        final next = r.end < t.length ? t.substring(r.end, r.end + 1) : '';
        if (_jiaoUnits.contains(next) || _fenUnits.contains(next)) {
          final frac = _parseFraction(t.substring(i));
          if (frac != null) {
            last = _ScanResult(frac, r.end, false);
            lastStart = i;
          }
        } else {
          last = r;
          lastStart = i;
        }
        i = r.end;
        continue;
      }
      i++;
    }
    if (last != null && last.value != null) {
      return AmountMatch(
        amount: _round2(last.value!),
        confidence: AmountConfidence.low,
        raw: t.substring(lastStart, last.end),
        elided: last.elided,
        start: lastStart,
        end: last.end,
      );
    }
    return null;
  }

  // ---------- 内部实现 ----------

  static bool _isNumeralChar(String c) =>
      _digits.containsKey(c) ||
      _units.containsKey(c) ||
      _big.containsKey(c) ||
      (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57) ||
      c == '.';

  static double _round2(double v) => (v * 100).round() / 100;

  /// 中文整数串 -> (值, 是否口语省略补全)
  static _IntResult _parseCnInt(String s) {
    if (s.isEmpty) return const _IntResult(null, false);

    var total = 0; // 万 / 亿 以上高位累计
    var section = 0; // 当前万以内段
    var cur = 0;
    var lastUnit = 0;
    var zeroSeen = false;
    var elided = false;

    for (var i = 0; i < s.length; i++) {
      final ch = s.substring(i, i + 1);
      if (_digits.containsKey(ch)) {
        final d = _digits[ch]!;
        if (d == 0) {
          zeroSeen = true;
          cur = 0;
        } else {
          cur = d;
        }
      } else if (_units.containsKey(ch)) {
        final u = _units[ch]!;
        if (cur == 0) cur = 1; // "十五"
        section += cur * u;
        cur = 0;
        lastUnit = u;
        zeroSeen = false;
      } else if (_big.containsKey(ch)) {
        final u = _big[ch]!;
        if (cur == 0) cur = 1;
        total += (section + cur) * u;
        section = 0;
        cur = 0;
        lastUnit = u;
        zeroSeen = false;
      } else {
        return const _IntResult(null, false);
      }
    }

    if (cur > 0) {
      if (lastUnit == 0) {
        section += cur; // "五块"
      } else if (lastUnit >= 100 && !zeroSeen) {
        // 口语省略：百 / 千 / 万 后直接跟个位 -> 补到下一级
        // "一百一"=110  "三千五"=3500  "两万三"=23000
        section += cur * (lastUnit ~/ 10);
        elided = true;
      } else {
        section += cur; // "十五" / "一百零五"
      }
    }
    return _IntResult(total + section, elided);
  }

  static _ScanResult _scanNumeral(String t, int i) {
    if (i >= t.length) return _ScanResult(null, i, false);

    final c = t.substring(i, i + 1);
    // 阿拉伯数字
    if ((c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57) || c == '.') {
      var j = i;
      final buf = StringBuffer();
      while (j < t.length) {
        final cc = t.substring(j, j + 1);
        final isDigit = cc.codeUnitAt(0) >= 48 && cc.codeUnitAt(0) <= 57;
        if (isDigit || cc == '.') {
          buf.write(cc);
          j++;
        } else {
          break;
        }
      }
      final v = double.tryParse(buf.toString());
      return _ScanResult(v, j, false);
    }

    var j = i;
    while (j < t.length) {
      final cc = t.substring(j, j + 1);
      if (_digits.containsKey(cc) ||
          _units.containsKey(cc) ||
          _big.containsKey(cc)) {
        j++;
      } else {
        break;
      }
    }
    if (j == i) return _ScanResult(null, i, false);
    final r = _parseCnInt(t.substring(i, j));
    return _ScanResult(r.value?.toDouble(), j, r.elided);
  }

  /// 金额单位之后的小数段
  /// '五'=0.5  '五毛'=0.5  '五毛六'=0.56  '二十五'=0.25  '五分'=0.05
  static double? _parseFraction(String rest) {
    if (rest.isEmpty) return null;
    var r = rest;
    while (r.isNotEmpty && r.substring(0, 1) == '零') {
      r = r.substring(1);
    }
    if (r.isEmpty) return null;

    var pj = -1;
    for (final m in _jiaoUnits) {
      final p = r.indexOf(m);
      if (p >= 0 && (pj < 0 || p < pj)) pj = p;
    }
    var pf = -1;
    for (final m in _fenUnits) {
      final p = r.indexOf(m);
      if (p >= 0 && (pf < 0 || p < pf)) pf = p;
    }

    if (pj >= 0 || pf >= 0) {
      int? jiao;
      int? fen;

      if (pj >= 0 && pj > 0) {
        final v = _scanNumeral(r.substring(0, pj), 0).value;
        if (v != null) jiao = v >= 10 ? v.toInt() % 10 : v.toInt();
      }
      if (pf >= 0) {
        final start = pj >= 0 ? pj + 1 : 0;
        final seg = r.substring(start, pf);
        if (seg.isNotEmpty) {
          final v = _scanNumeral(seg, 0).value;
          if (v != null) fen = v >= 10 ? v.toInt() % 10 : v.toInt();
        }
      } else if (pj >= 0) {
        // 口语省略"分"字：'五毛六' -> 0.56
        final tail = r.substring(pj + 1);
        if (tail.isNotEmpty) {
          final v = _scanNumeral(tail, 0).value;
          if (v != null) fen = v >= 10 ? v.toInt() % 10 : v.toInt();
        }
      }

      if (jiao == null && fen == null) return null;
      return (jiao ?? 0) * 0.1 + (fen ?? 0) * 0.01;
    }

    // 裸数字：一位 -> 角，两位 -> 角分
    final v = _scanNumeral(r, 0).value;
    if (v == null) return null;
    return v >= 10 ? v / 100.0 : v / 10.0;
  }
}

class _IntResult {
  final int? value;
  final bool elided;
  const _IntResult(this.value, this.elided);
}

class _ScanResult {
  final double? value;
  final int end;
  final bool elided;
  _ScanResult(this.value, this.end, this.elided);
}

/// 可选的二次校验：利用本地历史消费数据判断金额是否离谱。
///
/// 这是"本地优先"架构独有的优势 —— 历史数据就在设备上，云端方案反而拿不到。
/// 用法：识别到类目后，把候选金额丢进来，异常则 UI 强提示复核。
///
/// 注意：样本不足（< 3 条）时不判定，避免误报。
class AmountSanityChecker {
  final Map<String, List<double>> _history = {};

  void record(String category, double amount) {
    _history.putIfAbsent(category, () => <double>[]).add(amount);
  }

  /// 与该类目历史中位数偏离超过 3 倍视为可疑
  bool isSuspicious(String category, double amount) {
    final list = _history[category];
    if (list == null || list.length < 3) return false;
    final sorted = List<double>.from(list)..sort();
    final mid = sorted.length ~/ 2;
    final median = sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
    if (median <= 0) return false;
    return amount > median * 3 || amount < median / 3;
  }
}

// ============================================================
// 自测：dart run cn_amount_parser.dart
// 30 条用例覆盖 口语省略 / 零占位 / 角分 / 阿拉伯数字混说 / 多数字取最后一个
// ============================================================
void main() {
  final cases = <List<Object>>[
    ['午饭三十五块', 35.0],
    ['打车二十', 20.0],
    ['买菜一百一', 110.0],
    ['房租三千五', 3500.0],
    ['咖啡二十八块五', 28.5],
    ['花了两块', 2.0],
    ['花了35块', 35.0],
    ['一百零五块', 105.0],
    ['两万三', 23000.0],
    ['十块钱', 10.0],
    ['五毛', 0.5],
    ['地铁三块', 3.0],
    ['一千二百', 1200.0],
    ['打车十二块', 12.0],
    ['三十五块钱', 35.0],
    ['三块二十五', 3.25],
    ['三块五毛六', 3.56],
    ['十五块', 15.0],
    ['买了三本书花了二十块', 20.0],
    ['两百', 200.0],
    ['一万二', 12000.0],
    ['八十五元', 85.0],
    ['一百二十块', 120.0],
    ['三千零五十', 3050.0],
    ['五块钱', 5.0],
    ['六毛钱', 0.6],
    ['两万五千', 25000.0],
    ['九块九', 9.9],
    ['咖啡钱28.5', 28.5],
    ['一百块零五毛', 100.5],
  ];

  var pass = 0;
  for (final c in cases) {
    final text = c[0] as String;
    final want = c[1] as double;
    final m = CnAmountParser.parse(text);
    final ok = m != null && (m.amount - want).abs() < 0.005;
    if (ok) pass++;
    stdout.writeln(
      '${ok ? 'OK  ' : 'FAIL'} ${text.padRight(11)} '
      'want=$want\tgot=${m?.amount}\t'
      'conf=${m?.confidence.name}\treview=${m?.needsReview}',
    );
  }
  stdout.writeln('\n$pass/${cases.length} passed');

  // 复核标记演示
  stdout.writeln('\n--- needsReview 判定 ---');
  for (final s in ['午饭三十五块', '买菜一百一', '打车二十', '房租三千五']) {
    final m = CnAmountParser.parse(s);
    stdout.writeln(
      '$s -> ${m?.amount}  需复核: ${m?.needsReview}  (${m?.confidence.name})',
    );
  }
}
