import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';

enum MoneyStatisticsPeriodPreset {
  thisMonth,
  thisWeek,
  lastWeek,
  recentThreeMonths,
  thisYear,
  custom;

  String get label {
    return switch (this) {
      MoneyStatisticsPeriodPreset.thisMonth => '本月',
      MoneyStatisticsPeriodPreset.thisWeek => '本周',
      MoneyStatisticsPeriodPreset.lastWeek => '上周',
      MoneyStatisticsPeriodPreset.recentThreeMonths => '近3个月',
      MoneyStatisticsPeriodPreset.thisYear => '今年',
      MoneyStatisticsPeriodPreset.custom => '自定义',
    };
  }
}

enum MoneyStatisticsGroupBy { day, month }

enum MoneyStatisticsTypeFocus {
  balance,
  expense,
  income;

  String get label {
    return switch (this) {
      MoneyStatisticsTypeFocus.balance => '收支',
      MoneyStatisticsTypeFocus.expense => '支出',
      MoneyStatisticsTypeFocus.income => '收入',
    };
  }
}

class MoneyStatisticsDateRange {
  const MoneyStatisticsDateRange({
    required this.start,
    required this.endExclusive,
    required this.groupBy,
  });

  final DateTime start;
  final DateTime endExclusive;
  final MoneyStatisticsGroupBy groupBy;

  static MoneyStatisticsDateRange resolve(
    MoneyStatisticsPeriodPreset preset,
    DateTime anchor, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final local = DateTime(anchor.year, anchor.month, anchor.day);
    final monday = local.subtract(Duration(days: local.weekday - 1));
    return switch (preset) {
      MoneyStatisticsPeriodPreset.thisMonth => MoneyStatisticsDateRange(
        start: DateTime(local.year, local.month),
        endExclusive: DateTime(local.year, local.month + 1),
        groupBy: MoneyStatisticsGroupBy.day,
      ),
      MoneyStatisticsPeriodPreset.thisWeek => MoneyStatisticsDateRange(
        start: monday,
        endExclusive: monday.add(const Duration(days: 7)),
        groupBy: MoneyStatisticsGroupBy.day,
      ),
      MoneyStatisticsPeriodPreset.lastWeek => MoneyStatisticsDateRange(
        start: monday.subtract(const Duration(days: 7)),
        endExclusive: monday,
        groupBy: MoneyStatisticsGroupBy.day,
      ),
      MoneyStatisticsPeriodPreset.recentThreeMonths => MoneyStatisticsDateRange(
        start: DateTime(local.year, local.month - 2),
        endExclusive: DateTime(local.year, local.month + 1),
        groupBy: MoneyStatisticsGroupBy.month,
      ),
      MoneyStatisticsPeriodPreset.thisYear => MoneyStatisticsDateRange(
        start: DateTime(local.year),
        endExclusive: DateTime(local.year + 1),
        groupBy: MoneyStatisticsGroupBy.month,
      ),
      MoneyStatisticsPeriodPreset.custom => _buildCustomRange(
        customStart,
        customEnd,
      ),
    };
  }

  static MoneyStatisticsDateRange _buildCustomRange(DateTime? s, DateTime? e) {
    final start = s!;
    final end = e!;
    return MoneyStatisticsDateRange(
      start: start,
      endExclusive: end,
      groupBy: _inferGroupBy(start, end),
    );
  }

  static MoneyStatisticsGroupBy _inferGroupBy(DateTime start, DateTime end) {
    final days = end.difference(start).inDays;
    return days <= 93
        ? MoneyStatisticsGroupBy.day
        : MoneyStatisticsGroupBy.month;
  }
}

class MoneyStatisticsQuery {
  const MoneyStatisticsQuery({
    required this.dateStart,
    required this.dateEndExclusive,
    required this.groupBy,
    required this.ledgerId,
    this.accountId,
    this.accountType,
    this.paymentMethod,
    this.typeFocus = MoneyStatisticsTypeFocus.balance,
  });

  final DateTime dateStart;
  final DateTime dateEndExclusive;
  final MoneyStatisticsGroupBy groupBy;
  final String ledgerId;
  final String? accountId;
  final MoneyAccountType? accountType;
  final MoneyPaymentMethod? paymentMethod;
  final MoneyStatisticsTypeFocus typeFocus;
}

class MoneyStatisticsTrendPoint {
  const MoneyStatisticsTrendPoint({
    required this.bucketStart,
    required this.incomeMinor,
    required this.expenseMinor,
  });

  final DateTime bucketStart;
  final int incomeMinor;
  final int expenseMinor;

  int get netMinor => incomeMinor - expenseMinor;
}

class MoneyStatisticsCategorySlice {
  const MoneyStatisticsCategorySlice({
    required this.categoryId,
    required this.categoryName,
    required this.amountMinor,
    required this.percentage,
  });

  final String categoryId;
  final String categoryName;
  final int amountMinor;
  final double percentage;
}

class MoneyStatisticsAccountSlice {
  const MoneyStatisticsAccountSlice({
    required this.accountId,
    required this.accountName,
    required this.currencyCode,
    required this.assetMinor,
    required this.liabilityMinor,
  });

  final String accountId;
  final String accountName;
  final String currencyCode;
  final int assetMinor;
  final int liabilityMinor;

  int get totalMinor => assetMinor + liabilityMinor;
}

class MoneyStatisticsAccountTypeSlice {
  const MoneyStatisticsAccountTypeSlice({
    required this.accountType,
    required this.label,
    required this.currencyCode,
    required this.assetMinor,
    required this.liabilityMinor,
    required this.accountCount,
    required this.percentage,
  });

  final MoneyAccountType accountType;
  final String label;
  final String currencyCode;
  final int assetMinor;
  final int liabilityMinor;
  final int accountCount;
  final double percentage;

  int get totalMinor => assetMinor + liabilityMinor;
}

class MoneyStatisticsPaymentMethodSlice {
  const MoneyStatisticsPaymentMethodSlice({
    required this.paymentMethod,
    required this.label,
    required this.amountMinor,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.transactionCount,
    required this.percentage,
    this.customPaymentMethodName,
  });

  final MoneyPaymentMethod paymentMethod;
  final String label;
  final String? customPaymentMethodName;
  final int amountMinor;
  final int incomeMinor;
  final int expenseMinor;
  final int transactionCount;
  final double percentage;
}

class MoneyStatisticsAccountPaymentMethodSlice {
  const MoneyStatisticsAccountPaymentMethodSlice({
    required this.accountId,
    required this.accountName,
    required this.paymentMethod,
    required this.paymentMethodLabel,
    required this.amountMinor,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.transactionCount,
    required this.percentage,
  });

  final String accountId;
  final String accountName;
  final MoneyPaymentMethod paymentMethod;
  final String paymentMethodLabel;
  final int amountMinor;
  final int incomeMinor;
  final int expenseMinor;
  final int transactionCount;
  final double percentage;
}

class MoneyStatisticsRankSlice {
  const MoneyStatisticsRankSlice({
    required this.id,
    required this.name,
    required this.amountMinor,
    required this.transactionCount,
    required this.percentage,
  });

  final String id;
  final String name;
  final int amountMinor;
  final int transactionCount;
  final double percentage;
}

class MoneyStatisticsMemberSlice {
  const MoneyStatisticsMemberSlice({
    required this.memberId,
    required this.memberName,
    required this.role,
    required this.paidAmountMinor,
    required this.participatedAmountMinor,
    required this.paidRecordCount,
    required this.participationCount,
  });

  final String memberId;
  final String memberName;
  final String role;
  final int paidAmountMinor;
  final int participatedAmountMinor;
  final int paidRecordCount;
  final int participationCount;

  int get involvedAmountMinor => paidAmountMinor + participatedAmountMinor;

  int get netAmountMinor => paidAmountMinor - participatedAmountMinor;
}

class MoneyStatisticsComparisonSummary {
  const MoneyStatisticsComparisonSummary({
    required this.incomeMinor,
    required this.expenseMinor,
    required this.incomeTransactionCount,
    required this.expenseTransactionCount,
  });

  const MoneyStatisticsComparisonSummary.empty()
    : incomeMinor = 0,
      expenseMinor = 0,
      incomeTransactionCount = 0,
      expenseTransactionCount = 0;

  final int incomeMinor;
  final int expenseMinor;
  final int incomeTransactionCount;
  final int expenseTransactionCount;

  int get netMinor => incomeMinor - expenseMinor;
}

class MoneyStatisticsSummary {
  const MoneyStatisticsSummary({
    required this.currencyCode,
    required this.totalIncomeMinor,
    required this.totalExpenseMinor,
    required this.incomeTransactionCount,
    required this.expenseTransactionCount,
    required this.trend,
    required this.expenseCategories,
    required this.incomeCategories,
    required this.accounts,
    required this.accountTypes,
    required this.paymentMethods,
    required this.accountPaymentMethods,
    required this.merchants,
    required this.expenseSubCategories,
    required this.incomeSubCategories,
    required this.hasMixedCurrencies,
    required this.familyMembers,
    required this.previousPeriod,
    required this.samePeriodLastYear,
  });

  const MoneyStatisticsSummary.empty()
    : currencyCode = 'CNY',
      totalIncomeMinor = 0,
      totalExpenseMinor = 0,
      incomeTransactionCount = 0,
      expenseTransactionCount = 0,
      trend = const <MoneyStatisticsTrendPoint>[],
      expenseCategories = const <MoneyStatisticsCategorySlice>[],
      incomeCategories = const <MoneyStatisticsCategorySlice>[],
      accounts = const <MoneyStatisticsAccountSlice>[],
      accountTypes = const <MoneyStatisticsAccountTypeSlice>[],
      paymentMethods = const <MoneyStatisticsPaymentMethodSlice>[],
      accountPaymentMethods =
          const <MoneyStatisticsAccountPaymentMethodSlice>[],
      merchants = const <MoneyStatisticsRankSlice>[],
      expenseSubCategories = const <MoneyStatisticsRankSlice>[],
      incomeSubCategories = const <MoneyStatisticsRankSlice>[],
      hasMixedCurrencies = false,
      familyMembers = const <MoneyStatisticsMemberSlice>[],
      previousPeriod = const MoneyStatisticsComparisonSummary.empty(),
      samePeriodLastYear = const MoneyStatisticsComparisonSummary.empty();

  final String currencyCode;
  final int totalIncomeMinor;
  final int totalExpenseMinor;
  final int incomeTransactionCount;
  final int expenseTransactionCount;
  final List<MoneyStatisticsTrendPoint> trend;
  final List<MoneyStatisticsCategorySlice> expenseCategories;
  final List<MoneyStatisticsCategorySlice> incomeCategories;
  final List<MoneyStatisticsAccountSlice> accounts;
  final List<MoneyStatisticsAccountTypeSlice> accountTypes;
  final List<MoneyStatisticsPaymentMethodSlice> paymentMethods;
  final List<MoneyStatisticsAccountPaymentMethodSlice> accountPaymentMethods;
  final List<MoneyStatisticsRankSlice> merchants;
  final List<MoneyStatisticsRankSlice> expenseSubCategories;
  final List<MoneyStatisticsRankSlice> incomeSubCategories;
  final bool hasMixedCurrencies;
  final List<MoneyStatisticsMemberSlice> familyMembers;
  final MoneyStatisticsComparisonSummary previousPeriod;
  final MoneyStatisticsComparisonSummary samePeriodLastYear;

  int get netMinor => totalIncomeMinor - totalExpenseMinor;

  int get averageIncomeMinor {
    if (incomeTransactionCount <= 0) {
      return 0;
    }
    return totalIncomeMinor ~/ incomeTransactionCount;
  }

  int get averageExpenseMinor {
    if (expenseTransactionCount <= 0) {
      return 0;
    }
    return totalExpenseMinor ~/ expenseTransactionCount;
  }

  bool get hasTransactionData {
    return totalIncomeMinor != 0 ||
        totalExpenseMinor != 0 ||
        trend.any((point) => point.incomeMinor != 0 || point.expenseMinor != 0);
  }

  bool get isEmpty {
    return !hasTransactionData &&
        expenseCategories.isEmpty &&
        incomeCategories.isEmpty &&
        accounts.isEmpty &&
        accountTypes.isEmpty &&
        paymentMethods.isEmpty &&
        accountPaymentMethods.isEmpty &&
        merchants.isEmpty &&
        expenseSubCategories.isEmpty &&
        incomeSubCategories.isEmpty &&
        familyMembers.isEmpty &&
        previousPeriod.incomeMinor == 0 &&
        previousPeriod.expenseMinor == 0 &&
        samePeriodLastYear.incomeMinor == 0 &&
        samePeriodLastYear.expenseMinor == 0;
  }
}

enum MoneyStatisticsTimeBucket {
  earlyMorning(5, 11, '清晨'),
  morning(11, 14, '上午'),
  afternoon(14, 18, '下午'),
  evening(18, 23, '晚上'),
  lateNight(23, 5, '深夜');

  const MoneyStatisticsTimeBucket(this.startHour, this.endHour, this.label);

  final int startHour;
  final int endHour;
  final String label;

  static MoneyStatisticsTimeBucket? forHour(int hour) {
    for (final bucket in MoneyStatisticsTimeBucket.values) {
      final start = bucket.startHour;
      final end = bucket.endHour;
      if (start < end) {
        if (hour >= start && hour < end) {
          return bucket;
        }
      } else if (hour >= start || hour < end) {
        return bucket;
      }
    }
    return null;
  }
}

class MoneyStatisticsTimeSlice {
  const MoneyStatisticsTimeSlice({
    required this.bucket,
    required this.amountMinor,
    required this.transactionCount,
    required this.percentage,
  });

  final MoneyStatisticsTimeBucket bucket;
  final int amountMinor;
  final int transactionCount;
  final double percentage;
}

class MoneyStatisticsWeekdaySlice {
  const MoneyStatisticsWeekdaySlice({
    required this.weekday,
    required this.amountMinor,
    required this.transactionCount,
    required this.percentage,
  });

  final int weekday;
  final int amountMinor;
  final int transactionCount;
  final double percentage;

  bool get isWeekend => weekday == 6 || weekday == 7;
}

class MoneyStatisticsRefundSummary {
  const MoneyStatisticsRefundSummary({
    required this.refundCount,
    required this.refundAmountMinor,
    required this.transactionCount,
    required this.transactionAmountMinor,
  });

  final int refundCount;
  final int refundAmountMinor;
  final int transactionCount;
  final int transactionAmountMinor;

  double get refundRate {
    if (transactionCount <= 0) {
      return 0;
    }
    return refundCount / transactionCount;
  }
}

class MoneyStatisticsSourceSlice {
  const MoneyStatisticsSourceSlice({
    required this.sourceType,
    required this.label,
    required this.amountMinor,
    required this.transactionCount,
    required this.percentage,
  });

  final String sourceType;
  final String label;
  final int amountMinor;
  final int transactionCount;
  final double percentage;
}

class MoneyStatisticsSourceTrendPoint {
  const MoneyStatisticsSourceTrendPoint({
    required this.bucketStart,
    required this.installmentMinor,
    required this.autoPostingMinor,
    required this.otherMinor,
  });

  final DateTime bucketStart;
  final int installmentMinor;
  final int autoPostingMinor;
  final int otherMinor;

  int get totalMinor => installmentMinor + autoPostingMinor + otherMinor;
}

class MoneyStatisticsTagSlice {
  const MoneyStatisticsTagSlice({
    required this.tag,
    required this.amountMinor,
    required this.transactionCount,
    required this.percentage,
  });

  final String tag;
  final int amountMinor;
  final int transactionCount;
  final double percentage;
}

class MoneyStatisticsCreditUtilizationSlice {
  const MoneyStatisticsCreditUtilizationSlice({
    required this.accountId,
    required this.accountName,
    required this.currencyCode,
    required this.creditLimitMinor,
    required this.usedMinor,
    required this.availableMinor,
  });

  final String accountId;
  final String accountName;
  final String currencyCode;
  final int creditLimitMinor;
  final int usedMinor;
  final int availableMinor;

  double get utilization {
    if (creditLimitMinor <= 0) {
      return 0;
    }
    return usedMinor / creditLimitMinor;
  }
}

class MoneyStatisticsInsights {
  const MoneyStatisticsInsights({
    required this.currencyCode,
    required this.timeSlices,
    required this.weekdaySlices,
    required this.refund,
    required this.sourceSlices,
    required this.sourceTrend,
    required this.tagSlices,
    required this.creditUtilization,
  });

  const MoneyStatisticsInsights.empty()
    : currencyCode = 'CNY',
      timeSlices = const <MoneyStatisticsTimeSlice>[],
      weekdaySlices = const <MoneyStatisticsWeekdaySlice>[],
      refund = const MoneyStatisticsRefundSummary(
        refundCount: 0,
        refundAmountMinor: 0,
        transactionCount: 0,
        transactionAmountMinor: 0,
      ),
      sourceSlices = const <MoneyStatisticsSourceSlice>[],
      sourceTrend = const <MoneyStatisticsSourceTrendPoint>[],
      tagSlices = const <MoneyStatisticsTagSlice>[],
      creditUtilization = const <MoneyStatisticsCreditUtilizationSlice>[];

  final String currencyCode;
  final List<MoneyStatisticsTimeSlice> timeSlices;
  final List<MoneyStatisticsWeekdaySlice> weekdaySlices;
  final MoneyStatisticsRefundSummary refund;
  final List<MoneyStatisticsSourceSlice> sourceSlices;
  final List<MoneyStatisticsSourceTrendPoint> sourceTrend;
  final List<MoneyStatisticsTagSlice> tagSlices;
  final List<MoneyStatisticsCreditUtilizationSlice> creditUtilization;
}

// ──────────────────────────────────────────────────────────────
// Phase 6B entities
// ──────────────────────────────────────────────────────────────

class MoneyBudgetHistoryTrendPoint {
  const MoneyBudgetHistoryTrendPoint({
    required this.periodStart,
    required this.periodEnd,
    required this.budgetAmountMinor,
    required this.usedAmountMinor,
    required this.budgetCount,
    required this.overspentBudgetCount,
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final int budgetAmountMinor;
  final int usedAmountMinor;
  final int budgetCount;
  final int overspentBudgetCount;

  double get usageRate {
    if (budgetAmountMinor <= 0) return 0;
    return usedAmountMinor / budgetAmountMinor;
  }
}

class MoneyUpcomingCashFlowItem {
  const MoneyUpcomingCashFlowItem({
    required this.sourceType,
    required this.title,
    required this.amountMinor,
    required this.currencyCode,
    required this.dueDate,
  });

  final String sourceType;
  final String title;
  final int amountMinor;
  final String currencyCode;
  final DateTime dueDate;
}

class MoneyUpcomingCashFlowSummary {
  const MoneyUpcomingCashFlowSummary({
    required this.items,
    required this.next30DaysMinor,
    required this.next90DaysMinor,
    required this.monthlyRecurringMinor,
  });

  const MoneyUpcomingCashFlowSummary.empty()
    : items = const <MoneyUpcomingCashFlowItem>[],
      next30DaysMinor = 0,
      next90DaysMinor = 0,
      monthlyRecurringMinor = 0;

  final List<MoneyUpcomingCashFlowItem> items;
  final int next30DaysMinor;
  final int next90DaysMinor;
  final int monthlyRecurringMinor;
}

// ──────────────────────────────────────────────────────────────
// Phase 6D: Asset Snapshot entities
// ──────────────────────────────────────────────────────────────

class MoneyAssetSnapshotEntity {
  const MoneyAssetSnapshotEntity({
    required this.id,
    required this.userId,
    required this.accountId,
    required this.balanceMinor,
    required this.currencyCode,
    required this.capturedDate,
    required this.createdAt,
    required this.updatedAt,
    this.deviceId,
  });

  final String id;
  final String userId;
  final String accountId;
  final int balanceMinor;
  final String currencyCode;
  final int capturedDate;
  final String? deviceId;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class MoneyNetWorthTrendPoint {
  const MoneyNetWorthTrendPoint({
    required this.date,
    required this.assetMinor,
    required this.liabilityMinor,
  });

  final DateTime date;
  final int assetMinor;
  final int liabilityMinor;

  int get netMinor => assetMinor - liabilityMinor;
}
