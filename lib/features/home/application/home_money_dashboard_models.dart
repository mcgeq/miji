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
  });

  final String id;
  final String title;
  final String categoryName;
  final String accountName;
  final int amountMinor;
  final String currencyCode;
  final DateTime transactionAt;
  final HomeRecentTransactionType type;
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
