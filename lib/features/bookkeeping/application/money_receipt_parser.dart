import 'package:miji/core/ocr/ocr_line.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';

/// 从支付截图 OCR 文本里抽出来的记账草稿。
///
/// 每个字段都可能是 null——抽不出来就留空，由调用方回落到表单默认值。
/// **绝不用「猜」的方式补字段**：猜错的金额比空着的金额更有害。
class MoneyReceiptDraft {
  const MoneyReceiptDraft({
    this.amountMinor,
    this.merchant,
    this.occurredAt,
    this.paymentMethod,
    this.type = MoneyTransactionType.expense,
    this.categoryName,
    this.notes,
  });

  /// 金额（分）。
  final int? amountMinor;

  /// 商户 / 收钱方名称。
  final String? merchant;

  /// 交易时间。
  final DateTime? occurredAt;

  /// 支付方式。截图里通常只有一行「付款方式 余额宝」这类文本。
  final MoneyPaymentMethod? paymentMethod;

  /// 收支方向。金额前的正负号优先，看不出时保守取支出。
  final MoneyTransactionType type;

  /// 截图里直接写出来的分类**名称**（支付宝「账单分类」、银行 App「分类」）。
  ///
  /// 只有部分版式带这个字段：支付宝的账单详情页有，微信付款成功页没有。
  /// 它是纯文本名称而非本地分类 id——映射到本地分类由调用方完成。
  final String? categoryName;

  /// 付款方留言 / 备注。微信付款页里用户填的用途就落在这里。
  final String? notes;

  bool get isEmpty =>
      amountMinor == null &&
      merchant == null &&
      occurredAt == null &&
      paymentMethod == null;

  /// 识别到的字段数，用来给用户一句「识别到 N 项」的反馈。
  int get recognizedFieldCount => <bool>[
    amountMinor != null,
    merchant != null,
    occurredAt != null,
    paymentMethod != null,
  ].where((matched) => matched).length;
}

/// 把支付截图（支付宝 / 微信 / 银行 App 的账单详情页）的 OCR 文本解析成记账草稿。
///
/// 纯函数、不依赖平台与网络，方便单测。识别本身由 `AppTextRecognizer` 负责，
/// 这里只解决「一堆乱文本 → 结构化字段」。
MoneyReceiptDraft parsePaymentScreenshotText(String rawText, {DateTime? now}) {
  final lines = rawText
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  if (lines.isEmpty) {
    return const MoneyReceiptDraft();
  }

  final amount = _parseAmount(lines);
  return MoneyReceiptDraft(
    amountMinor: amount?.minor,
    merchant: _parseMerchant(lines, amount?.lineIndex),
    occurredAt: _parseOccurredAt(lines, now ?? DateTime.now()),
    paymentMethod: _parsePaymentMethod(lines),
    type: _parseType(lines, amount),
    categoryName: _parseCategoryName(lines),
    notes: _parseNotes(lines),
  );
}

/// 从**带版面位置**的识别结果里解析记账草稿。
///
/// 与 [parsePaymentScreenshotText] 的唯一区别，是先把同一水平行上的文字块
/// 合并成一句（[OcrPage.mergeVisualLines]）。这一步是识别准确率的关键：
/// 支付截图普遍是「左标签 + 右值」的两列布局，识别引擎给出的块顺序并不保证
/// 是阅读顺序，不合并就会出现「付款方式 / 招商银行信用卡(9892)」错位，
/// 下游「找标签取值」的规则必然取到隔壁字段。
///
/// 调用方应当优先用这个入口；[parsePaymentScreenshotText] 保留给纯文本场景
/// 与单测。
MoneyReceiptDraft parseReceiptPage(OcrPage page, {DateTime? now}) {
  return parsePaymentScreenshotText(
    page.mergeVisualLines().join('\n'),
    now: now,
  );
}

/// 一行文本里至少得有汉字或字母，否则不可能是商户名/分类名。
///
/// 专治 OCR 把大字号金额切块后留下的孤立符号（单独一行的 `¥`、`-`）。
final _hasWordCharacter = RegExp(r'[A-Za-z\u4e00-\u9fff]');

/// 标签是否**独立成词**。
///
/// `收款方备注  二维码收款` 里也含「备注」，但它不是备注字段——OCR 把
/// 左列标签和右列值并成一行后，这种「短标签被长标签包住」的误命中会直接
/// 取到隔壁字段的值。所以只有当标签落在行首、或前面是分隔符时才算命中。
bool _isStandaloneLabel(String line, int at) {
  if (at == 0) {
    return true;
  }
  final before = line[at - 1];
  return before == ' ' || before == '\t' || before == ':' || before == '：';
}

/// 撕掉一行结尾的箭头/展开指示符（`叮咚买菜 >`）。
const _decorationSuffixes = <String>['>', '›', '»', '→', '❯', '＞', '》'];

String _stripDecorationSuffix(String value) {
  var result = value.trim();
  var changed = true;
  while (changed && result.isNotEmpty) {
    changed = false;
    for (final suffix in _decorationSuffixes) {
      if (result.endsWith(suffix)) {
        result = result.substring(0, result.length - suffix.length).trim();
        changed = true;
      }
    }
  }
  return result;
}

// ---------------------------------------------------------------------------
// 金额
// ---------------------------------------------------------------------------

/// 金额前面挂货币符号（`¥38.50` / `- ￥ 18.40`），符号里也可能夹空格。
///
/// 这是最可信的一档，所以排在第一轮先扫。
final _amountWithSymbol = RegExp(
  r'([-−–—－+＋])?\s*[¥￥]\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
);

/// 金额带「元」字（`38.50元` / `38.50 元`）。
final _amountWithUnit = RegExp(
  r'([-−–—－+＋])?\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)\s*元',
);

/// 减号的候选字形。负号，以及各种破折号与全角横线。
///
/// OCR 出来的「减号」五花八门，只认 ASCII 的 `-` 会漏掉一大半；而支付页正是
/// 用这个符号表示流出，认不出来就会把支出记成收入。
const _minusSigns = <String>['-', '−', '–', '—', '－'];

/// 整行就是一个金额，但允许前后各挂一小段「装饰」（`- ¥ 18.40`、`18.40元`、
/// `- Y 18.40`）。
///
/// **不能把装饰限定成货币符号本身**——这正是三种真实截图里银行那张失手的原因。
/// 微信（`-5000.00`）和支付宝（`-18.40`）的金额行不带符号，靠这条就能捞回来；
/// 银行那张是 `- ¥ 18.40`，一旦 OCR 把 `¥` 认成别的东西（不是 `¥` 也不是 `￥`
/// 的某个怪字形），带符号的第一轮匹配不上，整行又因为有杂字不算纯数字，
/// 两轮全落空 → 金额识别不出来。
///
/// 所以判据改成「把前后不超过 4 个非数字字符剥掉，剩下的正好是金额」。放宽的
/// 代价由两条限制兜住：
/// 1. **必须带小数点**——页码、年份、订单号片段、角标这些裸整数一律不认，
///    抓错一个就是把金额写成 2026 元；
/// 2. **装饰里不能有数字**——`1000 18.40` 这种两串数字的行不认。
final _decoratedAmountLine = RegExp(
  r'^([^0-9]{0,4}?)([0-9][0-9,]*\.[0-9]{1,2})([^0-9]{0,4})$',
);

/// 这些行里出现的数字不是本次付款金额（优惠、抵扣、积分、账户余额…）。
const _amountNoiseKeywords = <String>[
  '优惠',
  '立减',
  '折扣',
  '红包',
  '抵扣',
  '已省',
  '积分',
  '累计',
  '余额',
  '可用额度',
  '还款',
];

/// 一次金额识别结果。带上它落在哪一行，供商户名按版式就近取值。
class _AmountReading {
  const _AmountReading({
    required this.minor,
    required this.lineIndex,
    required this.sign,
  });

  final int minor;
  final int lineIndex;

  /// -1 流出 / 0 无符号 / 1 流入。
  final int sign;
}

/// 从金额附近的一段文字里读出收支方向：`+` 流入、`-` 流出、都没有则未知。
///
/// 之所以吃「一段文字」而不只是那个符号本身——[_decoratedAmountLine] 抓下来的
/// 前缀是一整坨（`- ¥ ` / `-Y ` / 空），符号藏在里面。
int _signOf(String? raw) {
  if (raw == null || raw.isEmpty) {
    return 0;
  }
  if (raw.contains('+') || raw.contains('＋')) {
    return 1;
  }
  for (final minus in _minusSigns) {
    if (raw.contains(minus)) {
      return -1;
    }
  }
  return 0;
}

_AmountReading? _parseAmount(List<String> lines) {
  // 分三轮扫，优先级从高到低：带货币符号的最可信，其次是「N 元」，
  // 最后才是整行只有金额（前后许挂一点装饰）。OCR 经常把大字号金额里的
  // 「¥」和数字切成两行（符号小、数字大，版面分析会把它们分成两个块），
  // 那种情况只有第三轮能救。
  for (final pattern in <RegExp>[_amountWithSymbol, _amountWithUnit]) {
    final match = _scanAmount(lines, pattern);
    if (match != null) {
      return match;
    }
  }
  return _scanDecoratedAmount(lines);
}

_AmountReading? _scanAmount(List<String> lines, RegExp pattern) {
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    if (_amountNoiseKeywords.any(line.contains)) {
      continue;
    }
    final match = pattern.firstMatch(line);
    if (match == null) {
      continue;
    }
    final minor = _toMinor(match.group(2)!);
    if (minor == null) {
      // 这一行的数字不成金额（比如 ¥0.00），继续往下找。
      continue;
    }
    return _AmountReading(
      minor: minor,
      lineIndex: index,
      sign: _signOf(match.group(1)),
    );
  }
  return null;
}

/// 第三轮：整行只有金额，前后挂着一小段装饰（见 [_decoratedAmountLine]）。
///
/// 取**第一行**命中的，不是最像的——支付类页面的金额总在最上面（标题之下、
/// 明细列表之上），从上往下扫比挑「谁最像金额」稳得多。
_AmountReading? _scanDecoratedAmount(List<String> lines) {
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    if (_amountNoiseKeywords.any(line.contains)) {
      continue;
    }
    final match = _decoratedAmountLine.firstMatch(line);
    if (match == null) {
      continue;
    }
    final minor = _toMinor(match.group(2)!);
    if (minor == null) {
      continue;
    }
    return _AmountReading(
      minor: minor,
      lineIndex: index,
      sign: _signOf(match.group(1)),
    );
  }
  return null;
}

int? _toMinor(String raw) {
  try {
    final minor = parseMoneyAmountToMinor(raw);
    return minor > 0 ? minor : null;
  } on MoneyAmountParseException {
    return null;
  }
}

// ---------------------------------------------------------------------------
// 商户
// ---------------------------------------------------------------------------

/// 标签长的排前面：`商户全称`必须比 `商户`先试，`收款方全称`必须比 `收款方`
/// 先试，否则会把「全称」两个字也吃进商户名里。
const _merchantLabels = <String>[
  '收款方全称',
  '商户全称',
  '收款方名称',
  '商户名称',
  '商家名称',
  '收款方',
  '收钱方',
  '收款人',
  '付款给',
  '转账给',
  '对方名称',
];

/// 这些词说明取到的这行是别的字段，不是商户名。
///
/// 两处用它：整行以它开头 → 这行是标签行，放弃；出现在行中间 → 在它之前截断
/// （`支付宝~某公司 未入账`，「未入账」是角标，不该算进商户名）。
const _merchantNoiseKeywords = <String>[
  '支付成功',
  '付款成功',
  '收款成功',
  '交易成功',
  '支付失败',
  '交易失败',
  '当前状态',
  '交易时间',
  '付款时间',
  '支付时间',
  '转账时间',
  '付款方式',
  '支付方式',
  '支付渠道',
  '付款账户',
  '交易单号',
  '商户单号',
  '订单号',
  '转账单号',
  '账单',
  '交易详情',
  '未入账',
  '已入账',
  '交易卡号',
  '银行卡号',
  '国家或地区',
  '银行交易类型',
  '金额',
  '收款方备注',
  '服务详情',
  '账单服务',
  '收款方服务',
  '账单管理',
  '计入收支',
  '标签',
  '分类',
  '备注',
  '商品说明',
  '支付奖励',
  '二维码收款',
  '请选择',
  '收付款',
];

/// 付款页标题/抬头里的渠道前缀，撕掉它才是收款方本身。
///
/// 银行 App 的抬头写作 `支付宝-上海壹佰米网络科技有限公司`（OCR 会把图上的
/// `~` 读成 `-`），微信写作 `扫二维码付款-给张三`。
const _merchantPrefixes = <String>[
  '扫二维码付款-给',
  '扫二维码付款-',
  '二维码付款-给',
  '微信支付-给',
  '支付宝-给',
  '转账-给',
  '付款给',
  '转账给',
  '转给',
  '支付宝-',
  '微信支付-',
  '支付宝~',
  '微信支付~',
];

String? _parseMerchant(List<String> lines, int? amountLineIndex) {
  // 1) 金额行**正上方**那一行。
  //
  // 微信 / 支付宝 / 银行 App 三种完全不同版式的账单详情页，都把收款方摆在
  // 金额正上方——这是支付类页面的通用版式，比找标签可靠得多：真实截图里
  // 微信和支付宝根本不带「收钱方」这类标签，只有大标题。
  if (amountLineIndex != null) {
    for (var offset = 1; offset <= 3; offset++) {
      final index = amountLineIndex - offset;
      if (index < 0) {
        break;
      }
      final cleaned = _cleanMerchant(lines[index]);
      if (cleaned != null) {
        return cleaned;
      }
    }
  }

  // 2) 标签兜底（带「收钱方」「商户全称」这类字段名的版式）。
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    for (final label in _merchantLabels) {
      final at = line.indexOf(label);
      if (at < 0 || !_isStandaloneLabel(line, at)) {
        continue;
      }
      final inline = line.substring(at + label.length).trim();
      // 值可能在标签同一行，也可能换到下一行（微信「商户全称」常这样排）。
      final value = inline.isNotEmpty
          ? inline
          : (index + 1 < lines.length ? lines[index + 1] : '');
      final cleaned = _cleanMerchant(value);
      if (cleaned != null) {
        return cleaned;
      }
    }
  }
  return null;
}

String? _cleanMerchant(String raw) {
  var value = raw.trim();
  while (value.startsWith('：') || value.startsWith(':')) {
    value = value.substring(1).trim();
  }
  value = _stripDecorationSuffix(value);
  for (final prefix in _merchantPrefixes) {
    if (value.startsWith(prefix)) {
      value = value.substring(prefix.length).trim();
      break;
    }
  }
  if (value.isEmpty) {
    return null;
  }

  var end = value.length;
  for (final keyword in _merchantNoiseKeywords) {
    final at = value.indexOf(keyword);
    if (at < 0) {
      continue;
    }
    if (at == 0) {
      // 整行就是别的字段（`当前状态 支付成功`），不是商户名。
      return null;
    }
    if (at < end) {
      end = at;
    }
  }
  value = value.substring(0, end).trim();

  if (value.isEmpty || value.length > 40) {
    return null;
  }
  if (!_hasWordCharacter.hasMatch(value)) {
    return null;
  }
  return value;
}

// ---------------------------------------------------------------------------
// 分类（只有部分版式带）
// ---------------------------------------------------------------------------

const _categoryLabels = <String>['账单分类', '交易分类', '消费分类', '商品分类', '分类'];

/// 这些词说明取到的不是分类名（占位符或紧接着的下一个字段标签）。
const _categoryNoiseKeywords = <String>[
  '请选择',
  '选择',
  '未分类',
  '暂无',
  '添加',
  '账本',
  '标签',
  '备注',
  '留言',
  '金额',
];

String? _parseCategoryName(List<String> lines) {
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    for (final label in _categoryLabels) {
      final at = line.indexOf(label);
      if (at < 0 || !_isStandaloneLabel(line, at)) {
        continue;
      }
      final inline = line.substring(at + label.length).trim();
      final candidate = _stripDecorationSuffix(
        inline.isNotEmpty
            ? inline
            : (index + 1 < lines.length ? lines[index + 1] : ''),
      );
      final cleaned = _cleanCategory(candidate);
      if (cleaned != null) {
        return cleaned;
      }
    }
  }
  return null;
}

String? _cleanCategory(String raw) {
  final value = raw.trim();
  if (value.isEmpty || value.length > 12) {
    return null;
  }
  if (_categoryNoiseKeywords.any(value.contains)) {
    return null;
  }
  if (!_hasWordCharacter.hasMatch(value)) {
    return null;
  }
  return value;
}

// ---------------------------------------------------------------------------
// 备注
// ---------------------------------------------------------------------------

const _noteLabels = <String>['付款方留言', '转账备注', '付款备注', '备注'];

/// 输入框的占位提示，不是用户真的填了内容。
const _notePlaceholderKeywords = <String>[
  '记录点什么',
  '写点什么',
  '请输入',
  '点击输入',
  '请选择',
  '添加',
  '暂无',
];

/// 判断「下一行是不是新字段」用的字段名总表。
///
/// 备注是唯一会**折行**的字段（微信付款页的长用途说明经常占两行），所以要
/// 把后续行并回来；但必须在撞上下一个字段名时立刻收手，否则会把
/// 「支付方式 零钱通」也吃进备注。
final _fieldLabelKeywords = <String>[
  ..._merchantLabels,
  ..._paymentLabels,
  ..._categoryLabels,
  ..._noteLabels,
  '当前状态',
  '交易时间',
  '付款时间',
  '支付时间',
  '转账时间',
  '交易单号',
  '商户单号',
  '订单号',
  '转账单号',
  '交易卡号',
  '银行卡号',
  '国家或地区',
  '银行交易类型',
  '商品说明',
  '支付奖励',
  '服务详情',
  '账单服务',
  '收款方服务',
  '账单管理',
  '收款方备注',
  '所属账本',
  '计入收支',
  '标签',
];

/// 备注最多并回两行——再多就不是折行，而是把别人的内容拽进来了。
const _maxNoteContinuationLines = 2;

String? _parseNotes(List<String> lines) {
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    for (final label in _noteLabels) {
      final at = line.indexOf(label);
      if (at < 0 || !_isStandaloneLabel(line, at)) {
        continue;
      }
      final inline = line.substring(at + label.length).trim();
      if (inline.isEmpty) {
        // 值在下一行。但下一行可能已经是别的字段（`备注` 后面跟着
        // `记录点什么…` 占位符），交给 _cleanNotes 去挡。
        final next = index + 1 < lines.length ? lines[index + 1] : '';
        final cleaned = _cleanNotes(next);
        if (cleaned != null) {
          return _joinNoteContinuation(lines, index + 1, cleaned);
        }
        continue;
      }
      final cleaned = _cleanNotes(inline);
      if (cleaned != null) {
        return _joinNoteContinuation(lines, index, cleaned);
      }
    }
  }
  return null;
}

/// 把折行续写的部分并回备注（见 [_fieldLabelKeywords] 的说明）。
String _joinNoteContinuation(List<String> lines, int from, String first) {
  final buffer = StringBuffer(first);
  for (var offset = 1; offset <= _maxNoteContinuationLines; offset++) {
    final index = from + offset;
    if (index >= lines.length) {
      break;
    }
    final next = lines[index].trim();
    if (next.isEmpty || _looksLikeFieldLine(next)) {
      break;
    }
    if (buffer.length + next.length > 80) {
      break;
    }
    buffer.write(next);
  }
  return buffer.toString();
}

bool _looksLikeFieldLine(String line) {
  return _fieldLabelKeywords.any(line.contains);
}

String? _cleanNotes(String raw) {
  final value = _stripDecorationSuffix(raw);
  if (value.isEmpty || value.length > 80) {
    return null;
  }
  if (_notePlaceholderKeywords.any(value.contains)) {
    return null;
  }
  if (!_hasWordCharacter.hasMatch(value)) {
    return null;
  }
  return value;
}

// ---------------------------------------------------------------------------
// 时间
// ---------------------------------------------------------------------------

final _fullDateTime = RegExp(
  r'(\d{4})\s*[-/年]\s*(\d{1,2})\s*[-/月]\s*(\d{1,2})\s*日?\s*'
  r'(\d{1,2})\s*[:：]\s*(\d{2})(?:\s*[:：]\s*(\d{2}))?',
);
final _timeOnly = RegExp(r'(\d{1,2})\s*[:：]\s*(\d{2})(?:\s*[:：]\s*(\d{2}))?');

DateTime? _parseOccurredAt(List<String> lines, DateTime now) {
  final joined = lines.join(' ');
  final full = _fullDateTime.firstMatch(joined);
  if (full != null) {
    final parsed = _buildDateTime(
      year: _toInt(full.group(1)),
      month: _toInt(full.group(2)),
      day: _toInt(full.group(3)),
      hour: _toInt(full.group(4)),
      minute: _toInt(full.group(5)),
      second: _toInt(full.group(6)) ?? 0,
    );
    if (parsed != null && !parsed.isAfter(now)) {
      return parsed;
    }
  }

  // 没有日期就只认时间，挂到今天。识别不出时间就不要猜——交给调用方取当前时间。
  for (final line in lines) {
    final match = _timeOnly.firstMatch(line);
    if (match == null) {
      continue;
    }
    final parsed = _buildDateTime(
      year: now.year,
      month: now.month,
      day: now.day,
      hour: _toInt(match.group(1)),
      minute: _toInt(match.group(2)),
      second: _toInt(match.group(3)) ?? 0,
    );
    if (parsed != null && !parsed.isAfter(now)) {
      return parsed;
    }
  }
  return null;
}

int? _toInt(String? raw) => raw == null ? null : int.tryParse(raw);

DateTime? _buildDateTime({
  required int? year,
  required int? month,
  required int? day,
  required int? hour,
  required int? minute,
  required int second,
}) {
  if (year == null ||
      month == null ||
      day == null ||
      hour == null ||
      minute == null) {
    return null;
  }
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59 || second > 59) {
    return null;
  }
  final result = DateTime(year, month, day, hour, minute, second);
  // DateTime 会把 2 月 30 日这类非法日期顺延到下个月，这里拦掉。
  if (result.month != month || result.day != day) {
    return null;
  }
  return result;
}

// ---------------------------------------------------------------------------
// 支付方式
// ---------------------------------------------------------------------------

/// 银行 App 那类版式没有「付款方式」，只有一行卡号；`交易卡号` 一起收进来。
const _paymentLabels = <String>['付款方式', '支付方式', '支付渠道', '付款账户', '交易卡号', '银行卡号'];

MoneyPaymentMethod? _parsePaymentMethod(List<String> lines) {
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    for (final label in _paymentLabels) {
      final at = line.indexOf(label);
      if (at < 0 || !_isStandaloneLabel(line, at)) {
        continue;
      }
      final inline = line.substring(at + label.length).trim();
      final value = inline.isNotEmpty
          ? inline
          : (index + 1 < lines.length ? lines[index + 1] : '');
      final method = _paymentMethodFromText(value);
      if (method != null) {
        return method;
      }
    }
  }
  return null;
}

MoneyPaymentMethod? _paymentMethodFromText(String value) {
  if (value.contains('花呗')) {
    return MoneyPaymentMethod.huabei;
  }
  if (value.contains('白条')) {
    return MoneyPaymentMethod.baitiao;
  }
  if (value.contains('数字人民币')) {
    return MoneyPaymentMethod.digitalRmb;
  }
  if (value.contains('云闪付') || value.contains('银联')) {
    return MoneyPaymentMethod.unionPay;
  }
  if (value.contains('余额宝') || value.contains('支付宝') || value.contains('借呗')) {
    return MoneyPaymentMethod.alipay;
  }
  // 「零钱通」也要命中：它是微信的货币基金账户，付款方式和零钱同类。
  if (value.contains('零钱') || value.contains('微信')) {
    return MoneyPaymentMethod.wechatPay;
  }
  if (value.contains('信用卡')) {
    return MoneyPaymentMethod.creditCard;
  }
  if (value.contains('借记卡') ||
      value.contains('储蓄卡') ||
      value.contains('银行卡') ||
      value.contains('银行')) {
    return MoneyPaymentMethod.bankCard;
  }
  if (value.contains('转账')) {
    return MoneyPaymentMethod.bankTransfer;
  }
  if (value.contains('现金')) {
    return MoneyPaymentMethod.cash;
  }
  return null;
}

// ---------------------------------------------------------------------------
// 收支方向
// ---------------------------------------------------------------------------

/// 收款类关键词。只在金额不带符号时才需要用到。
const _incomeKeywords = <String>[
  '收款成功',
  '收款到账',
  '收款方已收钱',
  '已到账',
  '已存入零钱',
  '转账收款',
];

MoneyTransactionType _parseType(List<String> lines, _AmountReading? amount) {
  // 金额前的正负号是最可靠的信号：支付页用「-」表示流出、「+」表示流入，
  // 比在整页文字里找「收款成功」准得多。
  if (amount != null) {
    if (amount.sign > 0) {
      return MoneyTransactionType.income;
    }
    if (amount.sign < 0) {
      return MoneyTransactionType.expense;
    }
  }

  final joined = lines.join('\n');
  for (final keyword in _incomeKeywords) {
    if (joined.contains(keyword)) {
      return MoneyTransactionType.income;
    }
  }
  return MoneyTransactionType.expense;
}

// ---------------------------------------------------------------------------
// 分类名 → 本地分类 id
// ---------------------------------------------------------------------------

/// 把截图里的分类名匹配到本地分类目录，匹配不上返回 null。
///
/// 两轮，从严到松：
/// 1. **全等** —— 银行 App 写「餐饮」，本地也叫「餐饮」，直接命中；
/// 2. **互相包含** —— 支付宝写「餐饮美食」，本地叫「餐饮」。
///
/// 匹配不上就老实地返回 null 让用户自己选。**不要硬塞一个近似分类**：
/// 分类错了会连带污染统计占比和预算，比空着更糟。
///
/// 第二轮的包含判断要求目标名至少两个字——单字（「餐」「行」）会命中一大片
/// 无关分类，宁可放弃。
String? matchCategoryIdByName(MoneyCategoryCatalog catalog, String? name) {
  final target = name?.trim();
  if (target == null || target.isEmpty) {
    return null;
  }

  for (final category in catalog.categories) {
    if (category.name == target) {
      return category.id;
    }
  }
  if (target.length < 2) {
    return null;
  }
  for (final category in catalog.categories) {
    if (category.name.length < 2) {
      continue;
    }
    if (target.contains(category.name) || category.name.contains(target)) {
      return category.id;
    }
  }
  return null;
}
