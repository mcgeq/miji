/// 自动记账模板与分期计划的「重复登记」冲突。
///
/// 分期本身就带自动入账（到期自动把期次记成一笔支出流水），用户如果又为同一笔
/// 还款建了一个自动记账模板，到期当天两个引擎会各建一笔流水：账户余额扣两次、
/// 预算已用翻倍、流水列表出现两笔重复账。预算「已预留」里也会把同一笔算两遍。
///
/// 这个实体只描述冲突本身，**不代表任何处置**。是否停用模板由用户决定——
/// 自动猜测并静默跳过执行是危险的：判定条件是启发式的（同账户 + 同日 + 同金额），
/// 误判会直接导致「该记的账没记」，比多记一次严重得多。
library;

/// 冲突是怎么被认出来的。
enum MoneyAutoPostingConflictKind {
  /// 金额也相等：等额平摊分期，判定最可靠。
  exactAmount('exact_amount'),

  /// 只有日期和账户吻合，金额不等。
  ///
  /// 等额本息 / 等额本金的每期金额递减，与固定金额的模板对不上，但同日同账户
  /// 已经足够可疑，值得提示用户看一眼。
  sameDayOnly('same_day_only');

  const MoneyAutoPostingConflictKind(this.storageValue);

  final String storageValue;

  String get label {
    return switch (this) {
      MoneyAutoPostingConflictKind.exactAmount => '金额一致',
      MoneyAutoPostingConflictKind.sameDayOnly => '日期一致，金额不同',
    };
  }
}

class MoneyAutoPostingInstallmentConflict {
  const MoneyAutoPostingInstallmentConflict({
    required this.templateId,
    required this.templateName,
    required this.templateAmountMinor,
    required this.currencyCode,
    required this.planId,
    required this.planName,
    required this.periodNumber,
    required this.dueDate,
    required this.detailAmountMinor,
    required this.kind,
    required this.isTakenOver,
    required this.ledgerId,
  });

  /// 冲突所在账本。模板与分期必须同账本才算冲突，取哪个都一样。
  final String ledgerId;

  final String templateId;
  final String templateName;
  final int templateAmountMinor;
  final String currencyCode;

  final String planId;
  final String planName;

  /// 冲突命中的期次（第几期）与它的到期日。
  final int periodNumber;
  final DateTime dueDate;
  final int detailAmountMinor;

  final MoneyAutoPostingConflictKind kind;

  /// 该模板是否已被这个分期计划接管（接管后就不再是「待处理」的冲突）。
  final bool isTakenOver;

  /// 冲突的唯一键，用于「标记为两笔不同支出」的忽略名单。
  String get conflictKey => '$templateId::$planId';

  /// 展示用的一句话说明。
  String get summary {
    return '${_dateLabel(dueDate)} 模板「$templateName」'
        '${_money(templateAmountMinor)}'
        ' 与分期「$planName」第 $periodNumber 期'
        '${_money(detailAmountMinor)}';
  }

  String _dateLabel(DateTime date) {
    return '${date.month}月${date.day}日';
  }

  String _money(int minor) {
    final value = minor / 100;
    return '¥${value.toStringAsFixed(2)}';
  }
}
