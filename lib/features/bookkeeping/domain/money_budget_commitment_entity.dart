/// 预算的「已预留」额度：未来确定要发生、但尚未入账的金额。
///
/// 预算原本的 [MoneyBudgetEntity.usedAmountMinor] 只统计**已入账**流水，
/// 于是自动记账「每月 25 日房租 3000」在 25 日之前完全不占额度，用户看到的
/// 「还剩多少」是虚高的，等自动入账那一刻预算突然从健康跳到超支。
///
/// 这里把这些未来义务提前算出来。设计上有两条硬约束：
///
/// 1. **不写回 usedAmountMinor**。已用是硬事实，统计、历史趋势、周期结转都依赖它；
///    把「还没发生」的钱混进「已发生」，历史口径会被污染，用户也没法对账。
/// 2. **每个来源单独成项**，而不是只给一个总数。用户看到「已预留 ¥4200」会怀疑，
///    看到「房租 25 日 ¥3000 + 分期第 3 期 10 日 ¥1200」才能确认没算错。
library;

/// 未来义务的来源。
enum MoneyBudgetCommitmentSource {
  autoPosting('auto_posting'),
  installment('installment'),
  pendingTransaction('pending_transaction'),
  billReminder('bill_reminder');

  const MoneyBudgetCommitmentSource(this.storageValue);

  final String storageValue;

  String get label {
    return switch (this) {
      MoneyBudgetCommitmentSource.autoPosting => '自动记账',
      MoneyBudgetCommitmentSource.installment => '分期还款',
      MoneyBudgetCommitmentSource.pendingTransaction => '待确认流水',
      MoneyBudgetCommitmentSource.billReminder => '账单提醒',
    };
  }
}

/// 一条未来义务。
class MoneyBudgetCommitmentItem {
  const MoneyBudgetCommitmentItem({
    required this.source,
    required this.sourceId,
    required this.title,
    required this.date,
    required this.amountMinor,
    this.detail,
  });

  final MoneyBudgetCommitmentSource source;

  /// 打开来源用的 id：自动记账模板 / 分期明细 / 流水 / 账单提醒。
  final String sourceId;

  /// 主标题，如「房租」「iPhone 分期」。
  final String title;

  /// 预计记账日。判定是否占用本周期额度**只看这一天**。
  final DateTime date;

  final int amountMinor;

  /// 副标题，如「第 3 期」「10 月 25 日」。
  final String? detail;
}

/// 某个预算在当前周期内被未来义务占用的额度。
class MoneyBudgetCommitment {
  const MoneyBudgetCommitment({
    required this.budgetId,
    required this.periodStart,
    required this.periodEnd,
    this.items = const <MoneyBudgetCommitmentItem>[],
  });

  final String budgetId;

  /// 判定用的周期起点（含）。
  final DateTime periodStart;

  /// 判定用的周期终点（不含），与预算已用额度的口径一致。
  final DateTime periodEnd;

  final List<MoneyBudgetCommitmentItem> items;

  /// 没有对应预算时的空壳。`DateTime` 不是常量表达式，所以这里不能用 const。
  static final MoneyBudgetCommitment empty = MoneyBudgetCommitment(
    budgetId: '',
    periodStart: DateTime.utc(1970),
    periodEnd: DateTime.utc(1970),
    items: const <MoneyBudgetCommitmentItem>[],
  );

  bool get isEmpty => items.isEmpty;

  int get totalMinor {
    var total = 0;
    for (final item in items) {
      total += item.amountMinor;
    }
    return total;
  }

  int amountForSource(MoneyBudgetCommitmentSource source) {
    var total = 0;
    for (final item in items) {
      if (item.source == source) {
        total += item.amountMinor;
      }
    }
    return total;
  }

  int get autoPostingMinor =>
      amountForSource(MoneyBudgetCommitmentSource.autoPosting);

  int get installmentMinor =>
      amountForSource(MoneyBudgetCommitmentSource.installment);

  int get pendingTransactionMinor =>
      amountForSource(MoneyBudgetCommitmentSource.pendingTransaction);

  int get billReminderMinor =>
      amountForSource(MoneyBudgetCommitmentSource.billReminder);
}

/// 哪些来源计入「已预留」。
///
/// 默认只开确定性最高的两项（自动记账、分期）：
/// - 待确认流水是用户自己记了但还没确认入账的，算进去会让预算看起来过于紧张；
/// - 账单提醒金额常常是估算值，而且与分期 / 信用卡账单可能重复，噪声大。
class MoneyBudgetCommitmentOptions {
  const MoneyBudgetCommitmentOptions({
    this.includeAutoPosting = true,
    this.includeInstallments = true,
    this.includePendingTransactions = false,
    this.includeBillReminders = false,
  });

  final bool includeAutoPosting;
  final bool includeInstallments;
  final bool includePendingTransactions;
  final bool includeBillReminders;

  /// 一个来源都不算时直接返回空，省掉整轮查询。
  bool get isEmpty {
    return !includeAutoPosting &&
        !includeInstallments &&
        !includePendingTransactions &&
        !includeBillReminders;
  }

  MoneyBudgetCommitmentOptions copyWith({
    bool? includeAutoPosting,
    bool? includeInstallments,
    bool? includePendingTransactions,
    bool? includeBillReminders,
  }) {
    return MoneyBudgetCommitmentOptions(
      includeAutoPosting: includeAutoPosting ?? this.includeAutoPosting,
      includeInstallments: includeInstallments ?? this.includeInstallments,
      includePendingTransactions:
          includePendingTransactions ?? this.includePendingTransactions,
      includeBillReminders: includeBillReminders ?? this.includeBillReminders,
    );
  }
}
