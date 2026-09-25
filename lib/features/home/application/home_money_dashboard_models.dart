class HomeMoneyMonthScope {
  const HomeMoneyMonthScope({
    required this.anchorMonth,
    required this.start,
    required this.endExclusive,
  });

  final DateTime anchorMonth;
  final DateTime start;
  final DateTime endExclusive;

  int get remainingDays {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final lastDay = endExclusive.subtract(const Duration(days: 1));
    if (normalizedToday.isAfter(lastDay)) {
      return 0;
    }
    if (normalizedToday.isBefore(start)) {
      return lastDay.difference(start).inDays + 1;
    }
    return lastDay.difference(normalizedToday).inDays + 1;
  }

  static HomeMoneyMonthScope from(DateTime value) {
    final month = DateTime(value.year, value.month);
    return HomeMoneyMonthScope(
      anchorMonth: month,
      start: month,
      endExclusive: DateTime(month.year, month.month + 1),
    );
  }
}

class HomeTodaySpendingSummary {
  const HomeTodaySpendingSummary({
    required this.currencyCode,
    required this.todayExpenseMinor,
    required this.todayIncomeMinor,
    required this.weekExpenseMinor,
    required this.monthExpenseMinor,
    required this.monthIncomeMinor,
    required this.monthExpenseTransactionCount,
    required this.todayTransactionCount,
    required this.dailyAverageExpenseMinor,
  });

  const HomeTodaySpendingSummary.empty()
    : currencyCode = 'CNY',
      todayExpenseMinor = 0,
      todayIncomeMinor = 0,
      weekExpenseMinor = 0,
      monthExpenseMinor = 0,
      monthIncomeMinor = 0,
      monthExpenseTransactionCount = 0,
      todayTransactionCount = 0,
      dailyAverageExpenseMinor = 0;

  final String currencyCode;
  final int todayExpenseMinor;
  final int todayIncomeMinor;
  final int weekExpenseMinor;
  final int monthExpenseMinor;
  final int monthIncomeMinor;
  final int monthExpenseTransactionCount;
  final int todayTransactionCount;
  final int dailyAverageExpenseMinor;

  int get todayNetMinor => todayIncomeMinor - todayExpenseMinor;

  int get monthNetMinor => monthIncomeMinor - monthExpenseMinor;

  int get todayVsAverageMinor => todayExpenseMinor - dailyAverageExpenseMinor;
}

class HomeMonthBudgetSummary {
  const HomeMonthBudgetSummary({
    required this.hasBudget,
    required this.currencyCode,
    required this.budgetId,
    required this.budgetName,
    required this.totalMinor,
    required this.usedMinor,
    required this.remainingMinor,
    required this.progress,
    required this.periodProgress,
    required this.paceRatio,
    required this.paceLabel,
    required this.remainingDays,
  });

  const HomeMonthBudgetSummary.empty({
    required this.currencyCode,
    required this.remainingDays,
  }) : hasBudget = false,
       budgetId = null,
       budgetName = null,
       totalMinor = 0,
       usedMinor = 0,
       remainingMinor = 0,
       progress = 0,
       periodProgress = 0,
       paceRatio = 0,
       paceLabel = '暂无预算';

  final bool hasBudget;
  final String currencyCode;
  final String? budgetId;
  final String? budgetName;
  final int totalMinor;
  final int usedMinor;
  final int remainingMinor;
  final double progress;
  final double periodProgress;
  final double paceRatio;
  final String paceLabel;
  final int remainingDays;

  int get dailyAllowanceMinor {
    if (!hasBudget || remainingDays <= 0 || remainingMinor <= 0) {
      return 0;
    }
    return remainingMinor ~/ remainingDays;
  }
}

/// 解析首页 Hero 实际展示的预算摘要。
///
/// 背景只有「有预算」与「无预算」两种底色，而「已超支」是周期内的终态。
/// 数据刷新期间若暂时拿不到「有预算」的摘要（但用户仍有可用预算），
/// 保留上一次的摘要，避免卡片在 danger / brand 两种底色之间闪回。
HomeMonthBudgetSummary? resolveStableBudgetSummary({
  required HomeMonthBudgetSummary? current,
  required HomeMonthBudgetSummary? previous,
  required bool isLoading,
  required bool hasEligibleBudget,
}) {
  if (current?.hasBudget ?? false) {
    return current;
  }
  if (isLoading || hasEligibleBudget) {
    return previous ?? current;
  }
  return current;
}

enum HomeCategoryStructureType {
  expense,
  income;

  String get label {
    return switch (this) {
      HomeCategoryStructureType.expense => '支出',
      HomeCategoryStructureType.income => '收入',
    };
  }

  String get emptyText {
    return switch (this) {
      HomeCategoryStructureType.expense => '本月还没有支出分类',
      HomeCategoryStructureType.income => '本月还没有收入分类',
    };
  }
}

class HomeCategorySpendingItem {
  const HomeCategorySpendingItem({
    required this.categoryId,
    required this.categoryName,
    required this.amountMinor,
    required this.currencyCode,
    required this.ratio,
  });

  final String categoryId;
  final String categoryName;
  final int amountMinor;
  final String currencyCode;
  final double ratio;
}

class HomeDailySpendingPoint {
  const HomeDailySpendingPoint({
    required this.date,
    required this.expenseMinor,
    required this.incomeMinor,
    required this.transactionCount,
    required this.isInMonth,
  });

  final DateTime date;
  final int expenseMinor;
  final int incomeMinor;
  final int transactionCount;

  /// Whether this date belongs to the currently selected month.
  final bool isInMonth;

  int get netMinor => incomeMinor - expenseMinor;
}

class HomeRecentTransactionItem {
  const HomeRecentTransactionItem({
    required this.id,
    required this.title,
    required this.categoryName,
    required this.accountName,
    required this.amountMinor,
    required this.currencyCode,
    required this.transactionAt,
    required this.type,
    this.isUnusual = false,
  });

  final String id;
  final String title;
  final String categoryName;
  final String accountName;
  final int amountMinor;
  final String currencyCode;
  final DateTime transactionAt;
  final HomeRecentTransactionType type;

  /// 金额明显高于同分类当月均值时为 true，用于列表内的小标记。
  final bool isUnusual;
}

enum HomeRecentTransactionType {
  expense,
  income,
  transfer;

  String get label {
    return switch (this) {
      HomeRecentTransactionType.expense => '支出',
      HomeRecentTransactionType.income => '收入',
      HomeRecentTransactionType.transfer => '转账',
    };
  }
}

/// 净资产概览：只展示账本基准币种的资产 / 负债。
class HomeNetAssetSummary {
  const HomeNetAssetSummary({
    required this.currencyCode,
    required this.assetMinor,
    required this.liabilityMinor,
  });

  const HomeNetAssetSummary.empty({this.currencyCode = 'CNY'})
    : assetMinor = 0,
      liabilityMinor = 0;

  final String currencyCode;
  final int assetMinor;
  final int liabilityMinor;

  int get netAssetMinor => assetMinor - liabilityMinor;

  bool get hasAccounts => assetMinor != 0 || liabilityMinor != 0;
}

/// 单条分类预算的当月进度。
class HomeCategoryBudgetProgress {
  const HomeCategoryBudgetProgress({
    required this.budgetId,
    required this.name,
    required this.amountMinor,
    required this.usedMinor,
    required this.currencyCode,
  });

  final String budgetId;
  final String name;
  final int amountMinor;
  final int usedMinor;
  final String currencyCode;

  double get progress {
    if (amountMinor <= 0) {
      return usedMinor > 0 ? 1 : 0;
    }
    return usedMinor / amountMinor;
  }

  int get remainingMinor => amountMinor - usedMinor;

  bool get isExceeded => amountMinor > 0 && usedMinor >= amountMinor;

  bool get isNearLimit => isExceeded || (amountMinor > 0 && progress >= 0.8);
}

/// 首页 Hero 内嵌的分类预算摘要。
class HomeCategoryBudgetSummary {
  const HomeCategoryBudgetSummary({
    required this.items,
    required this.nearLimitCount,
    required this.totalCount,
  });

  const HomeCategoryBudgetSummary.empty()
    : items = const <HomeCategoryBudgetProgress>[],
      nearLimitCount = 0,
      totalCount = 0;

  /// 展示用的前几条（按预算金额降序）。
  final List<HomeCategoryBudgetProgress> items;

  /// 全部本月分类预算中接近或超过上限的条数。
  final int nearLimitCount;

  final int totalCount;

  bool get isEmpty => items.isEmpty;
}

/// 洞察文案的一段，[emphasis] 为 true 时用该条洞察的强调色高亮。
class HomeInsightSegment {
  const HomeInsightSegment(this.text, {this.emphasis = false});

  final String text;
  final bool emphasis;
}

/// 洞察的语义类别，决定图标。
enum HomeInsightKind {
  spendingVsAverage,
  noSpendingToday,
  topCategory,
  budgetPace,
  budgetExceeded,
}

/// 洞察的语气，决定颜色与排序权重。
enum HomeInsightTone { positive, neutral, warning, danger }

/// 点击洞察后跳转的去处。
enum HomeInsightTarget { transactions, categories, budgets }

/// 一条洞察。
///
/// 每条只讲一件事：把三件不相关的事挤进一句话，用户既读不完也记不住。
class HomeInsightItem {
  const HomeInsightItem({
    required this.kind,
    required this.tone,
    required this.segments,
    this.target,
    this.actionLabel,
  });

  final HomeInsightKind kind;
  final HomeInsightTone tone;
  final List<HomeInsightSegment> segments;

  /// 可跳转的去处；为空表示这条只是提示，不可点击。
  final HomeInsightTarget? target;
  final String? actionLabel;

  String get plainText => segments.map((segment) => segment.text).join();

  /// 排序权重，越大越靠前。
  int get severity {
    return switch (tone) {
      HomeInsightTone.danger => 3,
      HomeInsightTone.warning => 2,
      HomeInsightTone.positive => 1,
      HomeInsightTone.neutral => 0,
    };
  }
}

/// 首页洞察列表：已按严重程度排序、并截断到展示上限。
class HomeInsight {
  const HomeInsight({required this.items});

  final List<HomeInsightItem> items;

  bool get isEmpty => items.isEmpty;
}

/// 连续记账天数。
class HomeStreak {
  const HomeStreak({
    required this.days,
    required this.hasRecordedToday,
    required this.cappedAt,
  });

  const HomeStreak.empty() : days = 0, hasRecordedToday = false, cappedAt = 0;

  final int days;
  final bool hasRecordedToday;

  /// 统计窗口上限；[days] 达到该值说明实际天数可能更多。
  final int cappedAt;

  bool get isCapped => cappedAt > 0 && days >= cappedAt;
}
