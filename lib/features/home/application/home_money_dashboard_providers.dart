import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';

/// Tracks which week to display. 0 = anchor week
/// (current week for current month, first week for other months).
final homeWeekOffsetProvider = NotifierProvider<HomeWeekOffsetController, int>(
  HomeWeekOffsetController.new,
);

class HomeWeekOffsetController extends Notifier<int> {
  @override
  int build() {
    ref.watch(homeMoneySelectedMonthProvider);
    // 0 表示当前月「本周」（以今天为中心的滚动窗口），
    // 或历史月份的「第 1 周」。
    return 0;
  }

  void set(int value) {
    state = value;
  }
}

final homeMoneySelectedMonthProvider =
    NotifierProvider<HomeMoneySelectedMonthController, DateTime>(
      HomeMoneySelectedMonthController.new,
    );

class HomeMoneySelectedMonthController extends Notifier<DateTime> {
  @override
  DateTime build() {
    ref.watch(
      authSessionControllerProvider.select((session) => session.userId),
    );
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void set(DateTime value) {
    state = DateTime(value.year, value.month);
  }

  void move(int delta) {
    state = DateTime(state.year, state.month + delta);
  }
}

final homeMoneyMonthScopeProvider = Provider<HomeMoneyMonthScope>((ref) {
  final selectedMonth = ref.watch(homeMoneySelectedMonthProvider);
  return HomeMoneyMonthScope.from(selectedMonth);
});

final homeCategoryStructureTypeProvider =
    NotifierProvider<
      HomeCategoryStructureTypeController,
      HomeCategoryStructureType
    >(HomeCategoryStructureTypeController.new);

class HomeCategoryStructureTypeController
    extends Notifier<HomeCategoryStructureType> {
  @override
  HomeCategoryStructureType build() {
    ref.watch(
      authSessionControllerProvider.select((session) => session.userId),
    );
    return HomeCategoryStructureType.expense;
  }

  void set(HomeCategoryStructureType value) {
    state = value;
  }
}

final homeMonthTransactionsProvider =
    FutureProvider<List<MoneyTransactionEntity>>((ref) async {
      ref.watch(moneyDataRefreshVersionProvider);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        return const <MoneyTransactionEntity>[];
      }

      final ledger = await ref.watch(currentUserCurrentLedgerProvider.future);
      if (ledger == null) {
        return const <MoneyTransactionEntity>[];
      }

      final scope = ref.watch(homeMoneyMonthScopeProvider);

      // 多取前后各 7 天：趋势卡片是「以今天为中心」的滚动窗口，
      // 可能跨到上/下个月，这些天也要有数据。
      final fetchStart = _addDays(scope.start, -homeTrendFetchPaddingDays);
      final fetchEndExclusive = _addDays(
        scope.endExclusive,
        homeTrendFetchPaddingDays,
      );

      return _fetchCompletedTransactions(
        ref,
        userId: session.userId!,
        ledgerId: ledger.id,
        start: fetchStart,
        endExclusive: fetchEndExclusive,
      );
    });

/// 分页取 [start, endExclusive) 区间内「已完成」的交易。
///
/// 抽出来是因为日历要按**任意月份**查库（不只是当前选中月），
/// 两处必须用完全相同的过滤条件（分页大小、软删除、状态）。
Future<List<MoneyTransactionEntity>> _fetchCompletedTransactions(
  Ref ref, {
  required String userId,
  required String ledgerId,
  required DateTime start,
  required DateTime endExclusive,
}) async {
  final repository = ref.read(moneyRepositoryProvider);
  final transactions = <MoneyTransactionEntity>[];
  var pageNumber = 1;
  const pageSize = 200;

  while (true) {
    final page = await repository.listTransactions(
      userId,
      MoneyTransactionQuery(
        page: pageNumber,
        pageSize: pageSize,
        dateStart: start,
        dateEnd: endExclusive.subtract(const Duration(microseconds: 1)),
        ledgerId: ledgerId,
      ),
    );
    transactions.addAll(page.items);
    if (!page.hasMore) {
      break;
    }
    pageNumber += 1;
  }

  return transactions
      .where(
        (transaction) =>
            !transaction.isDeleted &&
            transaction.status == MoneyTransactionStatus.completed,
      )
      .toList(growable: false);
}

MoneyBudgetEntity? selectHomeMonthlyExpenseBudget(
  List<MoneyBudgetEntity> budgets,
  HomeMoneyMonthScope scope,
) {
  final candidates =
      budgets.where((budget) {
        final overlapsMonth =
            budget.periodStart.isBefore(scope.endExclusive) &&
            budget.periodEnd.isAfter(scope.start);
        final supportedPeriod =
            budget.periodType == MoneyBudgetPeriodType.monthly ||
            budget.periodType == MoneyBudgetPeriodType.billingCycle;
        return budget.isActive &&
            budget.isExpenseLimit &&
            supportedPeriod &&
            overlapsMonth;
      }).toList()..sort((a, b) {
        final scopeCompare = _budgetScopeRank(
          a.scopeType,
        ).compareTo(_budgetScopeRank(b.scopeType));
        if (scopeCompare != 0) {
          return scopeCompare;
        }

        final aSpan = a.periodEnd.difference(a.periodStart).inDays;
        final bSpan = b.periodEnd.difference(b.periodStart).inDays;
        final spanCompare = aSpan.compareTo(bSpan);
        if (spanCompare != 0) {
          return spanCompare;
        }
        return b.amountMinor.compareTo(a.amountMinor);
      });

  return candidates.isEmpty ? null : candidates.first;
}

final homeMonthBudgetSummaryProvider = FutureProvider<HomeMonthBudgetSummary>((
  ref,
) async {
  final scope = ref.watch(homeMoneyMonthScopeProvider);
  final ledger = await ref.watch(currentUserCurrentLedgerProvider.future);
  final budgets = await ref.watch(currentUserBudgetsProvider.future);
  final budget = selectHomeMonthlyExpenseBudget(budgets, scope);

  if (budget == null) {
    return HomeMonthBudgetSummary.empty(
      currencyCode: ledger?.baseCurrencyCode ?? 'CNY',
      remainingDays: scope.remainingDays,
    );
  }

  final session = ref.watch(authSessionControllerProvider);
  if (!session.isUnlocked || session.userId == null) {
    return HomeMonthBudgetSummary.empty(
      currencyCode: ledger?.baseCurrencyCode ?? 'CNY',
      remainingDays: scope.remainingDays,
    );
  }

  final repository = ref.watch(moneyRepositoryProvider);
  final pendingAmount = await repository.getPendingAutoPostingAmountForBudget(
    session.userId!,
    budget.id,
    scope.start,
    scope.endExclusive,
  );

  final now = DateTime.now();
  final pace = homeBudgetPeriodPaceFor(
    budget,
    DateTime(now.year, now.month, now.day),
  );

  final totalUsedMinor = budget.usedAmountMinor + pendingAmount;

  return HomeMonthBudgetSummary(
    hasBudget: true,
    currencyCode: budget.currencyCode,
    budgetId: budget.id,
    budgetName: budget.name,
    totalMinor: budget.amountMinor,
    usedMinor: totalUsedMinor,
    remainingMinor: budget.amountMinor - totalUsedMinor,
    progress: totalUsedMinor / budget.amountMinor,
    periodProgress: pace.periodProgress,
    paceRatio: pace.paceRatioFor(totalUsedMinor / budget.amountMinor),
    paceLabel: homeBudgetPaceLabelFor(
      totalUsedMinor / budget.amountMinor,
      pace.periodProgress,
    ),
    remainingDays: pace.remainingDays,
  );
});

final homeTodaySpendingSummaryProvider =
    FutureProvider<HomeTodaySpendingSummary>((ref) async {
      final scope = ref.watch(homeMoneyMonthScopeProvider);
      final ledger = await ref.watch(currentUserCurrentLedgerProvider.future);
      final transactions = await ref.watch(
        homeMonthTransactionsProvider.future,
      );
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final weekStart = today.subtract(Duration(days: today.weekday - 1));
      final expenseDays = <DateTime>{};

      var todayExpenseMinor = 0;
      var todayIncomeMinor = 0;
      var weekExpenseMinor = 0;
      var monthExpenseMinor = 0;
      var monthIncomeMinor = 0;
      var monthExpenseTransactionCount = 0;
      var todayTransactionCount = 0;

      for (final transaction in transactions) {
        final date = _dateOnly(transaction.transactionAt);
        if (date.isBefore(scope.start) || !date.isBefore(scope.endExclusive)) {
          continue;
        }

        final amountMinor = effectiveMoneyAmountMinor(transaction);
        if (amountMinor <= 0) {
          continue;
        }

        switch (transaction.type) {
          case MoneyTransactionType.expense:
            expenseDays.add(date);
            monthExpenseMinor += amountMinor;
            monthExpenseTransactionCount += 1;
            if (!date.isBefore(weekStart) && !date.isAfter(today)) {
              weekExpenseMinor += amountMinor;
            }
            if (date == today) {
              todayExpenseMinor += amountMinor;
              todayTransactionCount += 1;
            }
          case MoneyTransactionType.income:
            monthIncomeMinor += amountMinor;
            if (date == today) {
              todayIncomeMinor += amountMinor;
              todayTransactionCount += 1;
            }
          case MoneyTransactionType.transfer:
            break;
        }
      }

      return HomeTodaySpendingSummary(
        currencyCode: transactions.isEmpty
            ? ledger?.baseCurrencyCode ?? 'CNY'
            : transactions.first.currencyCode,
        todayExpenseMinor: todayExpenseMinor,
        todayIncomeMinor: todayIncomeMinor,
        weekExpenseMinor: weekExpenseMinor,
        monthExpenseMinor: monthExpenseMinor,
        monthIncomeMinor: monthIncomeMinor,
        monthExpenseTransactionCount: monthExpenseTransactionCount,
        todayTransactionCount: todayTransactionCount,
        dailyAverageExpenseMinor: expenseDays.isEmpty
            ? 0
            : monthExpenseMinor ~/ expenseDays.length,
      );
    });

/// How many calendar weeks overlap with the selected month.
/// 趋势卡片展示的 7 天窗口。
///
/// 当前月以**今天为中心**（今天永远落在第 [homeTrendTodayIndex] 根柱子上），
/// 更早的窗口每 7 天回溯一格；历史月份则按月份内的自然周（周一起始）切分。
class HomeTrendWindow {
  const HomeTrendWindow({
    required this.start,
    required this.blockCount,
    required this.offset,
    required this.rolling,
  });

  /// 窗口首日。
  final DateTime start;

  /// 可选的窗口数量。
  final int blockCount;

  /// 当前选中的窗口序号。
  final int offset;

  /// true = 以今天为中心的滚动窗口；false = 月份内的自然周。
  final bool rolling;

  DateTime get lastDay => _addDays(start, 6);

  List<String> get blockLabels => [
    for (var index = 0; index < blockCount; index++)
      rolling ? _rollingLabel(index) : '第 ${index + 1} 周',
  ];

  static String _rollingLabel(int index) {
    return switch (index) {
      0 => '本周',
      1 => '上周',
      _ => '$index 周前',
    };
  }
}

/// 「今天」在滚动窗口中的固定位置（0 基），即第 4 根柱子。
const homeTrendTodayIndex = 3;

/// 当前月最多可回溯的窗口数。
const homeTrendMaxBlocks = 5;

/// 为了覆盖跨月的滚动窗口，月份交易需要多取几天。
const homeTrendFetchPaddingDays = 7;

final homeTrendWindowProvider = Provider<HomeTrendWindow>((ref) {
  final scope = ref.watch(homeMoneyMonthScopeProvider);
  final offset = ref.watch(homeWeekOffsetProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final isCurrentMonth =
      scope.anchorMonth.year == now.year &&
      scope.anchorMonth.month == now.month;

  if (!isCurrentMonth) {
    final blockCount = homeWeekCountForMonth(scope.anchorMonth);
    final safeOffset = offset.clamp(0, blockCount - 1);
    return HomeTrendWindow(
      start: homeWeekStartForMonth(scope.anchorMonth, safeOffset),
      blockCount: blockCount,
      offset: safeOffset,
      rolling: false,
    );
  }

  final blockCount = homeRollingBlockCount(scope.anchorMonth, today);
  final safeOffset = offset.clamp(0, blockCount - 1);
  return HomeTrendWindow(
    start: _addDays(today, -homeTrendTodayIndex - safeOffset * 7),
    blockCount: blockCount,
    offset: safeOffset,
    rolling: true,
  );
});

/// 当前月可回溯的窗口数：只统计起始日仍在本月内的窗口。
int homeRollingBlockCount(DateTime month, DateTime today) {
  final firstWindowStart = _addDays(today, -homeTrendTodayIndex);
  final diff = _daysBetween(_firstDayOfMonth(month), firstWindowStart);
  return (diff ~/ 7 + 1).clamp(1, homeTrendMaxBlocks);
}

/// 月份内以周一为起点的自然周数量。
int homeWeekCountForMonth(DateTime month) {
  final firstMonday = _mondayOfWeekContaining(_firstDayOfMonth(month));
  final lastDay = _addDays(_firstDayOfMonth(month), _daysInMonth(month) - 1);
  final lastMonday = _mondayOfWeekContaining(lastDay);
  return _daysBetween(firstMonday, lastMonday) ~/ 7 + 1;
}

/// 选中月份第 [index] 周（自然周）的起始日（周一）。index 从 0 开始。
DateTime homeWeekStartForMonth(DateTime month, int index) {
  return _addDays(_mondayOfWeekContaining(_firstDayOfMonth(month)), index * 7);
}

/// 某个月的逐日聚合结果。
///
/// 日历（月视图）与趋势卡（周窗口）共用这一份聚合：周窗口可能跨月，
/// 所以 [byDay] 里会包含月份之外的补白天数，两边各取所需。
class HomeMonthlyDailySpending {
  const HomeMonthlyDailySpending({
    required this.month,
    required this.byDay,
    required this.expenseMinor,
    required this.incomeMinor,
    required this.transactionCount,
    required this.dailyAverageExpenseMinor,
    this.transactionsByDay = const <DateTime, List<MoneyTransactionEntity>>{},
  });

  const HomeMonthlyDailySpending.empty(this.month)
    : byDay = const <DateTime, HomeDailySpendingPoint>{},
      transactionsByDay = const <DateTime, List<MoneyTransactionEntity>>{},
      expenseMinor = 0,
      incomeMinor = 0,
      transactionCount = 0,
      dailyAverageExpenseMinor = 0;

  /// 月份锚点（该月 1 日 0 点）。
  final DateTime month;

  /// 日期（只保留年月日）→ 当日聚合。
  final Map<DateTime, HomeDailySpendingPoint> byDay;

  /// 月内（不含补白天数）的支出合计。
  final int expenseMinor;

  /// 月内（不含补白天数）的收入合计。
  final int incomeMinor;

  final int transactionCount;

  /// 月内日均支出（当月按「已过天数」摊，历史月按整月摊）。
  final int dailyAverageExpenseMinor;

  /// 某一天的流水（按时间倒序），供日历的日详情列出明细。
  final Map<DateTime, List<MoneyTransactionEntity>> transactionsByDay;

  /// 月净额：正数代表这个月净收入。
  int get netMinor => incomeMinor - expenseMinor;

  /// 某一天的流水（时间倒序）。
  List<MoneyTransactionEntity> transactionsForDay(int day) {
    return transactionsByDay[DateTime(month.year, month.month, day)] ??
        const <MoneyTransactionEntity>[];
  }

  /// 某一天的聚合（没有记录时返回 0 值点，供日历画空日）。
  HomeDailySpendingPoint pointForDay(int day) {
    final date = DateTime(month.year, month.month, day);
    return byDay[date] ??
        HomeDailySpendingPoint(
          date: date,
          expenseMinor: 0,
          incomeMinor: 0,
          transactionCount: 0,
          isInMonth: true,
        );
  }
}

/// 把交易聚合成「按天」的收支。
///
/// 纯函数：不碰 provider、不查库，日历/趋势/测试共用同一套口径，
/// 避免三处各算一遍算出口径差异（原来的日聚合内联在周 provider 里）。
HomeMonthlyDailySpending buildMonthlyDailySpending({
  required DateTime month,
  required List<MoneyTransactionEntity> transactions,
  DateTime? today,
}) {
  final anchor = DateTime(month.year, month.month);
  final dailyMap = <DateTime, _DailyAccum>{};
  final transactionsByDay = <DateTime, List<MoneyTransactionEntity>>{};
  var monthExpense = 0;
  var monthIncome = 0;
  var monthCount = 0;

  for (final txn in transactions) {
    final amount = effectiveMoneyAmountMinor(txn);
    if (amount <= 0) {
      continue;
    }
    final date = _dateOnly(txn.transactionAt);
    final accum = dailyMap.putIfAbsent(date, () => _DailyAccum());
    transactionsByDay
        .putIfAbsent(date, () => <MoneyTransactionEntity>[])
        .add(txn);
    final inMonth = date.year == anchor.year && date.month == anchor.month;
    if (txn.type == MoneyTransactionType.expense) {
      accum.expenseMinor += amount;
      accum.count += 1;
      if (inMonth) {
        monthExpense += amount;
        monthCount += 1;
      }
    } else if (txn.type == MoneyTransactionType.income) {
      accum.incomeMinor += amount;
      if (inMonth) {
        monthIncome += amount;
        monthCount += 1;
      }
    }
  }

  final byDay = <DateTime, HomeDailySpendingPoint>{
    for (final entry in dailyMap.entries)
      entry.key: HomeDailySpendingPoint(
        date: entry.key,
        expenseMinor: entry.value.expenseMinor,
        incomeMinor: entry.value.incomeMinor,
        transactionCount: entry.value.count,
        isInMonth:
            entry.key.year == anchor.year && entry.key.month == anchor.month,
      ),
  };

  // 日均：当月按「已经过去的天数」摊平（月初不会因为只过了 3 天就把日均压得很低），
  // 历史月按整月天数摊平。
  final now = today ?? DateTime.now();
  final isCurrentMonth = now.year == anchor.year && now.month == anchor.month;
  final divisor = isCurrentMonth
      ? now.day
      : DateTime(anchor.year, anchor.month + 1, 0).day;

  for (final dayTransactions in transactionsByDay.values) {
    dayTransactions.sort((a, b) => b.transactionAt.compareTo(a.transactionAt));
  }

  return HomeMonthlyDailySpending(
    month: anchor,
    byDay: byDay,
    transactionsByDay: transactionsByDay,
    expenseMinor: monthExpense,
    incomeMinor: monthIncome,
    transactionCount: monthCount,
    dailyAverageExpenseMinor: divisor <= 0
        ? 0
        : (monthExpense / divisor).round(),
  );
}

/// 指定月份的逐日聚合。
///
/// **切月会真的重新查库并重算**：
/// - 该月正是仪表盘选中月时，直接复用 `homeMonthTransactionsProvider`
///   已经取回的那一批（它本身覆盖选中月 ±7 天，整月都在里面），避免重复查询；
/// - 其它月份（用户在日历里往回翻）才按需单独查库。
final homeMonthDailySpendingProvider =
    FutureProvider.family<HomeMonthlyDailySpending, DateTime>((
      ref,
      month,
    ) async {
      ref.watch(moneyDataRefreshVersionProvider);
      final anchor = DateTime(month.year, month.month);
      final selected = ref.watch(homeMoneySelectedMonthProvider);
      final isSelectedMonth =
          selected.year == anchor.year && selected.month == anchor.month;

      if (isSelectedMonth) {
        final transactions = await ref.watch(
          homeMonthTransactionsProvider.future,
        );
        return buildMonthlyDailySpending(
          month: anchor,
          transactions: transactions,
        );
      }

      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        return HomeMonthlyDailySpending.empty(anchor);
      }
      final ledger = await ref.watch(currentUserCurrentLedgerProvider.future);
      if (ledger == null) {
        return HomeMonthlyDailySpending.empty(anchor);
      }

      final start = DateTime(anchor.year, anchor.month);
      final transactions = await _fetchCompletedTransactions(
        ref,
        userId: session.userId!,
        ledgerId: ledger.id,
        start: start,
        endExclusive: DateTime(anchor.year, anchor.month + 1),
      );
      return buildMonthlyDailySpending(
        month: anchor,
        transactions: transactions,
      );
    });

/// 7 daily spending points for the selected trend window.
final homeWeeklySpendingProvider = FutureProvider<List<HomeDailySpendingPoint>>(
  (ref) async {
    final scope = ref.watch(homeMoneyMonthScopeProvider);
    final window = ref.watch(homeTrendWindowProvider);
    // 走同一个按月聚合入口：周窗口可能跨月，补白天数也在 byDay 里。
    final monthly = await ref.watch(
      homeMonthDailySpendingProvider(scope.anchorMonth).future,
    );

    return List.generate(7, (i) {
      final date = _addDays(window.start, i);
      return monthly.byDay[date] ??
          HomeDailySpendingPoint(
            date: date,
            expenseMinor: 0,
            incomeMinor: 0,
            transactionCount: 0,
            isInMonth:
                date.month == scope.anchorMonth.month &&
                date.year == scope.anchorMonth.year,
          );
    });
  },
);

class _DailyAccum {
  int expenseMinor = 0;
  int incomeMinor = 0;
  int count = 0;
}

DateTime _firstDayOfMonth(DateTime month) {
  return DateTime(month.year, month.month);
}

int _daysInMonth(DateTime month) {
  return DateTime(month.year, month.month + 1, 0).day;
}

/// 用构造函数做日期加减（而不是 Duration），跨夏令时也不会把日期挪走。
DateTime _addDays(DateTime date, int days) {
  return DateTime(date.year, date.month, date.day + days);
}

DateTime _mondayOfWeekContaining(DateTime date) {
  return _addDays(
    DateTime(date.year, date.month, date.day),
    -(date.weekday - 1),
  );
}

int _daysBetween(DateTime from, DateTime to) {
  return DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
}

final homeCategoryStructureProvider =
    FutureProvider<List<HomeCategorySpendingItem>>((ref) async {
      final type = ref.watch(homeCategoryStructureTypeProvider);
      return ref.watch(homeCategorySpendingProvider(type).future);
    });

final homeRecentTransactionsProvider =
    FutureProvider<List<HomeRecentTransactionItem>>((ref) async {
      final transactions = await ref.watch(
        homeMonthTransactionsProvider.future,
      );
      final expenseCatalog = await ref.watch(
        currentUserCategoryCatalogProvider(MoneyCategoryKind.expense).future,
      );
      final incomeCatalog = await ref.watch(
        currentUserCategoryCatalogProvider(MoneyCategoryKind.income).future,
      );
      final accounts = await ref.watch(
        currentUserVisibleAccountsProvider.future,
      );
      final accountsById = {
        for (final account in accounts) account.id: account,
      };
      final scope = ref.watch(homeMoneyMonthScopeProvider);
      final monthTransactions = transactions
          .where((transaction) {
            final date = _dateOnly(transaction.transactionAt);
            return !date.isBefore(scope.start) &&
                date.isBefore(scope.endExclusive);
          })
          .toList(growable: false);

      final sorted = monthTransactions.toList()
        ..sort((a, b) => b.transactionAt.compareTo(a.transactionAt));

      final categoryStats = _buildExpenseCategoryStats(monthTransactions);

      return sorted
          .take(homeRecentTransactionCount)
          .map((transaction) {
            final catalog = transaction.type == MoneyTransactionType.income
                ? incomeCatalog
                : expenseCatalog;
            final category = transaction.type == MoneyTransactionType.transfer
                ? null
                : catalog.categoryById(transaction.categoryId);
            final account = accountsById[transaction.accountId];
            final title = transaction.description.trim().isEmpty
                ? transaction.type.label
                : transaction.description.trim();
            final amountMinor = effectiveMoneyAmountMinor(transaction);

            return HomeRecentTransactionItem(
              id: transaction.id,
              title: title,
              categoryName: category?.name ?? transaction.type.label,
              accountName: account?.name ?? '未知账户',
              amountMinor: amountMinor,
              currencyCode: transaction.currencyCode,
              transactionAt: transaction.transactionAt,
              type: _recentTypeFor(transaction.type),
              isUnusual: isHomeUnusualExpense(
                transactionType: transaction.type,
                amountMinor: amountMinor,
                categoryId: transaction.categoryId,
                stats: categoryStats,
              ),
            );
          })
          .toList(growable: false);
    });

/// 首页最近账单展示条数。
const homeRecentTransactionCount = 5;

/// 判定为「异常」需要同分类至少有这么多笔当月支出。
const homeUnusualExpenseMinSamples = 3;

/// 金额达到同分类当月均值的多少倍时标记为异常。
const homeUnusualExpenseRatio = 3.0;

/// 分类当月支出的样本数与均值。
Map<String, ({int count, int meanMinor})> _buildExpenseCategoryStats(
  List<MoneyTransactionEntity> transactions,
) {
  final totals = <String, int>{};
  final counts = <String, int>{};
  for (final transaction in transactions) {
    if (transaction.type != MoneyTransactionType.expense) {
      continue;
    }
    final amountMinor = effectiveMoneyAmountMinor(transaction);
    if (amountMinor <= 0) {
      continue;
    }
    totals.update(
      transaction.categoryId,
      (value) => value + amountMinor,
      ifAbsent: () => amountMinor,
    );
    counts.update(
      transaction.categoryId,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
  }

  return {
    for (final entry in totals.entries)
      entry.key: (
        count: counts[entry.key] ?? 0,
        meanMinor: entry.value ~/ (counts[entry.key] ?? 1),
      ),
  };
}

/// 纯函数，便于单测：金额是否明显高于同分类当月均值。
bool isHomeUnusualExpense({
  required MoneyTransactionType transactionType,
  required int amountMinor,
  required String categoryId,
  required Map<String, ({int count, int meanMinor})> stats,
}) {
  if (transactionType != MoneyTransactionType.expense || amountMinor <= 0) {
    return false;
  }
  final stat = stats[categoryId];
  if (stat == null ||
      stat.count < homeUnusualExpenseMinSamples ||
      stat.meanMinor <= 0) {
    return false;
  }
  return amountMinor >= stat.meanMinor * homeUnusualExpenseRatio;
}

class HomeBudgetPeriodPace {
  const HomeBudgetPeriodPace({
    required this.periodProgress,
    required this.remainingDays,
  });

  final double periodProgress;
  final int remainingDays;

  double paceRatioFor(double budgetProgress) {
    if (periodProgress <= 0) {
      return budgetProgress.clamp(0, 1).toDouble();
    }
    return budgetProgress / periodProgress;
  }
}

HomeBudgetPeriodPace homeBudgetPeriodPaceFor(
  MoneyBudgetEntity budget,
  DateTime today,
) {
  final periodStart = _dateOnly(budget.periodStart);
  final periodEndExclusive = _dateOnly(
    budget.periodEnd,
  ).add(const Duration(days: 1));
  final normalizedToday = _dateOnly(today);
  final totalDays = periodEndExclusive.difference(periodStart).inDays;
  if (totalDays <= 0) {
    return const HomeBudgetPeriodPace(periodProgress: 0, remainingDays: 0);
  }

  final elapsedDays = normalizedToday.isBefore(periodStart)
      ? 0
      : normalizedToday.isBefore(periodEndExclusive)
      ? normalizedToday.difference(periodStart).inDays + 1
      : totalDays;
  final remainingDays =
      normalizedToday.isAfter(
        periodEndExclusive.subtract(const Duration(days: 1)),
      )
      ? 0
      : normalizedToday.isBefore(periodStart)
      ? totalDays
      : periodEndExclusive.difference(normalizedToday).inDays;

  return HomeBudgetPeriodPace(
    periodProgress: elapsedDays / totalDays,
    remainingDays: remainingDays,
  );
}

String homeBudgetPaceLabelFor(double budgetProgress, double periodProgress) {
  if (budgetProgress >= 1) {
    return '已超支';
  }
  if (budgetProgress >= 0.8 || budgetProgress > periodProgress + 0.12) {
    return '花费偏快';
  }
  return '节奏正常';
}

int _budgetScopeRank(MoneyBudgetScopeType type) {
  return switch (type) {
    MoneyBudgetScopeType.all => 0,
    MoneyBudgetScopeType.category => 1,
    MoneyBudgetScopeType.account => 2,
    MoneyBudgetScopeType.categoryAccount => 3,
    MoneyBudgetScopeType.tag => 4,
  };
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

/// 扣掉退款后的实际金额（下限 0）。
///
/// 原来叫 `_effectiveAmountMinor`，日历的「当日流水」也要用同一口径，
/// 所以提升为公开函数，避免两处各写一遍。
int effectiveMoneyAmountMinor(MoneyTransactionEntity transaction) {
  final amount = transaction.amountMinor - transaction.refundAmountMinor;
  return amount < 0 ? 0 : amount;
}

HomeRecentTransactionType _recentTypeFor(MoneyTransactionType type) {
  return switch (type) {
    MoneyTransactionType.expense => HomeRecentTransactionType.expense,
    MoneyTransactionType.income => HomeRecentTransactionType.income,
    MoneyTransactionType.transfer => HomeRecentTransactionType.transfer,
  };
}

// ============================================================================
// 分类结构（按类型参数化）
// ============================================================================

/// 按收支类型计算的当月分类结构。
///
/// 面板使用当前选中的类型；洞察条固定取支出，避免被用户的 tab 选择影响。
final homeCategorySpendingProvider =
    FutureProvider.family<
      List<HomeCategorySpendingItem>,
      HomeCategoryStructureType
    >((ref, type) async {
      final transactions = await ref.watch(
        homeMonthTransactionsProvider.future,
      );
      final transactionType = switch (type) {
        HomeCategoryStructureType.expense => MoneyTransactionType.expense,
        HomeCategoryStructureType.income => MoneyTransactionType.income,
      };
      final categoryKind = switch (type) {
        HomeCategoryStructureType.expense => MoneyCategoryKind.expense,
        HomeCategoryStructureType.income => MoneyCategoryKind.income,
      };
      final catalog = await ref.watch(
        currentUserCategoryCatalogProvider(categoryKind).future,
      );
      final totalsByCategory = <String, int>{};

      final scope = ref.watch(homeMoneyMonthScopeProvider);
      for (final transaction in transactions) {
        if (transaction.type != transactionType) {
          continue;
        }
        final date = _dateOnly(transaction.transactionAt);
        if (date.isBefore(scope.start) || !date.isBefore(scope.endExclusive)) {
          continue;
        }
        final amountMinor = effectiveMoneyAmountMinor(transaction);
        if (amountMinor <= 0) {
          continue;
        }
        totalsByCategory.update(
          transaction.categoryId,
          (value) => value + amountMinor,
          ifAbsent: () => amountMinor,
        );
      }

      final totalAmountMinor = totalsByCategory.values.fold<int>(
        0,
        (sum, value) => sum + value,
      );
      final sorted = totalsByCategory.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sorted
          .map((entry) {
            final category = catalog.categoryById(entry.key);
            return HomeCategorySpendingItem(
              categoryId: entry.key,
              categoryName: category?.name ?? '未命名分类',
              amountMinor: entry.value,
              currencyCode: transactions.isEmpty
                  ? 'CNY'
                  : transactions.first.currencyCode,
              ratio: totalAmountMinor == 0 ? 0 : entry.value / totalAmountMinor,
            );
          })
          .toList(growable: false);
    });

// ============================================================================
// 净资产
// ============================================================================

/// 首页的净资产卡片，复用记账域的聚合结果，避免两处各算一遍。
final homeNetAssetSummaryProvider = FutureProvider<HomeNetAssetSummary>((
  ref,
) async {
  final worth = await ref.watch(currentUserNetWorthSummaryProvider.future);
  return HomeNetAssetSummary(
    currencyCode: worth.currencyCode,
    assetMinor: worth.assetMinor,
    liabilityMinor: worth.liabilityMinor,
  );
});

// ============================================================================
// 分类预算
// ============================================================================

/// 当月生效的分类预算，按金额降序取前 [visibleCount] 条。
final homeCategoryBudgetSummaryProvider =
    FutureProvider<HomeCategoryBudgetSummary>((ref) async {
      final scope = ref.watch(homeMoneyMonthScopeProvider);
      final budgets = await ref.watch(currentUserBudgetsProvider.future);

      final active =
          budgets
              .where(
                (budget) =>
                    budget.isActive &&
                    budget.isExpenseLimit &&
                    budget.scopeType == MoneyBudgetScopeType.category &&
                    budget.periodStart.isBefore(scope.endExclusive) &&
                    budget.periodEnd.isAfter(scope.start),
              )
              .toList()
            ..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));

      final items = active
          .take(homeCategoryBudgetVisibleCount)
          .map(
            (budget) => HomeCategoryBudgetProgress(
              budgetId: budget.id,
              name: budget.name,
              amountMinor: budget.amountMinor,
              usedMinor: budget.usedAmountMinor,
              currencyCode: budget.currencyCode,
            ),
          )
          .toList(growable: false);

      return HomeCategoryBudgetSummary(
        items: items,
        nearLimitCount: active
            .where(
              (budget) =>
                  budget.amountMinor > 0 &&
                  budget.usedAmountMinor / budget.amountMinor >= 0.8,
            )
            .length,
        totalCount: active.length,
      );
    });

/// Hero 内最多展示几条分类预算。
const homeCategoryBudgetVisibleCount = 2;

// ============================================================================
// 连续记账天数
// ============================================================================

/// 连续记账统计窗口（天）。
const homeStreakWindowDays = 120;

final homeStreakProvider = FutureProvider<HomeStreak>((ref) async {
  ref.watch(moneyDataRefreshVersionProvider);
  final session = ref.watch(authSessionControllerProvider);
  if (!session.isUnlocked || session.userId == null) {
    return const HomeStreak.empty();
  }

  final ledger = await ref.watch(currentUserCurrentLedgerProvider.future);
  final repository = ref.watch(moneyRepositoryProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final windowStart = today.subtract(
    const Duration(days: homeStreakWindowDays - 1),
  );

  final recordedDays = <DateTime>{};
  var pageNumber = 1;
  const pageSize = 200;
  // 只需要「哪些天有记录」，跳过的行数上限用于兜底，避免极端数据量下死循环。
  const maxPages = 10;

  while (pageNumber <= maxPages) {
    final page = await repository.listTransactions(
      session.userId!,
      MoneyTransactionQuery(
        page: pageNumber,
        pageSize: pageSize,
        dateStart: windowStart,
        dateEnd: today.add(const Duration(days: 1)),
        ledgerId: ledger?.id,
      ),
    );
    for (final transaction in page.items) {
      if (transaction.isDeleted ||
          transaction.status != MoneyTransactionStatus.completed) {
        continue;
      }
      recordedDays.add(_dateOnly(transaction.transactionAt));
    }
    if (!page.hasMore) {
      break;
    }
    pageNumber += 1;
  }

  final hasRecordedToday = recordedDays.contains(today);
  var cursor = hasRecordedToday
      ? today
      : today.subtract(const Duration(days: 1));
  var days = 0;
  while (recordedDays.contains(cursor)) {
    days += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return HomeStreak(
    days: days,
    hasRecordedToday: hasRecordedToday,
    cappedAt: homeStreakWindowDays,
  );
});

// ============================================================================
// 洞察条
// ============================================================================

final homeInsightProvider = FutureProvider<HomeInsight?>((ref) async {
  final today = await ref.watch(homeTodaySpendingSummaryProvider.future);
  final budget = await ref.watch(homeMonthBudgetSummaryProvider.future);
  final categories = await ref.watch(
    homeCategorySpendingProvider(HomeCategoryStructureType.expense).future,
  );

  return buildHomeInsight(
    today: today,
    budget: budget,
    categories: categories,
    now: DateTime.now(),
  );
});

/// 把已有数字翻译成一组「一件事一条」的洞察。
///
/// 每条自带语气（决定颜色）和跳转目标（决定可操作性），最后按严重程度
/// 排序并截断。原来把所有判断用 `；` 拼成一句话的做法信息密度过高，
/// 用户既读不出重点，也无法据此操作。
HomeInsight? buildHomeInsight({
  required HomeTodaySpendingSummary today,
  required HomeMonthBudgetSummary budget,
  required List<HomeCategorySpendingItem> categories,
  DateTime? now,
}) {
  final hasAnyData =
      today.monthExpenseMinor > 0 ||
      today.monthIncomeMinor > 0 ||
      today.todayExpenseMinor > 0;
  if (!hasAnyData) {
    return null;
  }

  final currencyCode = today.currencyCode;
  final items = <HomeInsightItem>[];

  // 1. 预算超支 —— 最严重，且给出超出金额。
  if (budget.hasBudget && budget.progress >= 1) {
    items.add(
      HomeInsightItem(
        kind: HomeInsightKind.budgetExceeded,
        tone: HomeInsightTone.danger,
        target: HomeInsightTarget.budgets,
        actionLabel: '看预算',
        segments: [
          const HomeInsightSegment('本月预算已超支 '),
          HomeInsightSegment(
            formatMoneyMinor(
              budget.usedMinor - budget.totalMinor,
              currencyCode,
            ),
            emphasis: true,
          ),
        ],
      ),
    );
  } else if (budget.hasBudget && budget.paceLabel == homeInsightFastPaceLabel) {
    // 2. 花得比时间进度快 —— 还没超，但需要提醒。
    items.add(
      HomeInsightItem(
        kind: HomeInsightKind.budgetPace,
        tone: HomeInsightTone.warning,
        target: HomeInsightTarget.budgets,
        actionLabel: '看预算',
        segments: [
          const HomeInsightSegment('花得比时间进度快，还剩 '),
          HomeInsightSegment('${budget.remainingDays} 天', emphasis: true),
          const HomeInsightSegment('，日均可花 '),
          HomeInsightSegment(
            formatMoneyMinor(budget.dailyAllowanceMinor, currencyCode),
            emphasis: true,
          ),
        ],
      ),
    );
  }

  // 3. 今天 vs 日均；没有记录时给一个轻量提醒。
  if (today.todayExpenseMinor > 0) {
    final diff = today.todayExpenseMinor - today.dailyAverageExpenseMinor;
    if (today.dailyAverageExpenseMinor > 0 && diff != 0) {
      final less = diff < 0;
      items.add(
        HomeInsightItem(
          kind: HomeInsightKind.spendingVsAverage,
          tone: less ? HomeInsightTone.positive : HomeInsightTone.neutral,
          segments: [
            HomeInsightSegment(less ? '今天比日均少花 ' : '今天比日均多花 '),
            HomeInsightSegment(
              formatMoneyMinor(diff.abs(), currencyCode),
              emphasis: true,
            ),
          ],
        ),
      );
    } else {
      items.add(
        HomeInsightItem(
          kind: HomeInsightKind.spendingVsAverage,
          tone: HomeInsightTone.neutral,
          segments: [
            HomeInsightSegment(
              '今天已花 ${formatMoneyMinor(today.todayExpenseMinor, currencyCode)}，和日均持平',
            ),
          ],
        ),
      );
    }
  }

  // 4. 支出大头在哪。
  final top = categories.isEmpty ? null : categories.first;
  if (top != null && top.ratio >= homeInsightTopCategoryThreshold) {
    items.add(
      HomeInsightItem(
        kind: HomeInsightKind.topCategory,
        tone: HomeInsightTone.neutral,
        target: HomeInsightTarget.categories,
        actionLabel: '看分类',
        segments: [
          HomeInsightSegment('${top.categoryName}占本月支出 '),
          HomeInsightSegment('${(top.ratio * 100).round()}%', emphasis: true),
        ],
      ),
    );
  }

  // 5. 今天还没记账：只是轻量提醒，放在分析类之后（同样都是 neutral，
  //    靠声明顺序决定先后）。白天「今天还没支出」本来就正常，容易变成噪音，
  //    所以过了 [homeInsightNoSpendingHintHour] 点才提示。
  final currentHour = (now ?? DateTime.now()).hour;
  if (today.todayExpenseMinor <= 0 &&
      currentHour >= homeInsightNoSpendingHintHour) {
    items.add(
      const HomeInsightItem(
        kind: HomeInsightKind.noSpendingToday,
        tone: HomeInsightTone.neutral,
        segments: [HomeInsightSegment('今天还没有支出记录')],
      ),
    );
  }

  if (items.isEmpty) {
    return null;
  }

  // 稳定排序：先按严重程度，同级别按规则声明顺序。List.sort 本身不稳定。
  final ordered = items.asMap().entries.toList()
    ..sort((a, b) {
      final bySeverity = b.value.severity.compareTo(a.value.severity);
      return bySeverity != 0 ? bySeverity : a.key.compareTo(b.key);
    });

  return HomeInsight(
    items: ordered
        .map((entry) => entry.value)
        .take(homeInsightMaxItems)
        .toList(growable: false),
  );
}

/// `homeBudgetPaceLabelFor` 里表示「花得偏快」的文案。
const homeInsightFastPaceLabel = '花费偏快';

/// 首页最多展示几条洞察。
const homeInsightMaxItems = 3;

/// 超过这个整点还没记账，才提示「今天还没有支出记录」。
const homeInsightNoSpendingHintHour = 18;

/// 分类占比超过该阈值时进入洞察条。
const homeInsightTopCategoryThreshold = 0.3;
