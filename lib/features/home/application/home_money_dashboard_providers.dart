import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';
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
      final repository = ref.watch(moneyRepositoryProvider);
      final transactions = <MoneyTransactionEntity>[];
      var pageNumber = 1;
      const pageSize = 200;

      while (true) {
        final page = await repository.listTransactions(
          session.userId!,
          MoneyTransactionQuery(
            page: pageNumber,
            pageSize: pageSize,
            dateStart: scope.start,
            dateEnd: scope.endExclusive.subtract(
              const Duration(microseconds: 1),
            ),
            ledgerId: ledger.id,
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
    });

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

        final amountMinor = _effectiveAmountMinor(transaction);
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
final homeWeeklyWeekCountProvider = Provider<int>((ref) {
  final scope = ref.watch(homeMoneyMonthScopeProvider);
  final start = scope.start;
  final lastDay = scope.endExclusive.subtract(const Duration(days: 1));

  final firstMonday = start.subtract(Duration(days: start.weekday - 1));
  final lastDayMonday = lastDay.subtract(Duration(days: lastDay.weekday - 1));
  return lastDayMonday.difference(firstMonday).inDays ~/ 7 + 1;
});

/// 7 daily spending points for the week at [homeWeekOffsetProvider].
final homeWeeklySpendingProvider = FutureProvider<List<HomeDailySpendingPoint>>(
  (ref) async {
    final transactions = await ref.watch(homeMonthTransactionsProvider.future);
    final scope = ref.watch(homeMoneyMonthScopeProvider);
    final offset = ref.watch(homeWeekOffsetProvider);

    // Build a daily lookup for the entire month
    final dailyMap = <DateTime, _DailyAccum>{};
    for (final txn in transactions) {
      final date = _dateOnly(txn.transactionAt);
      if (date.isBefore(scope.start) || !date.isBefore(scope.endExclusive)) {
        continue;
      }
      final amount = _effectiveAmountMinor(txn);
      if (amount <= 0) {
        continue;
      }
      final accum = dailyMap.putIfAbsent(date, () => _DailyAccum());
      if (txn.type == MoneyTransactionType.expense) {
        accum.expenseMinor += amount;
        accum.count += 1;
      } else if (txn.type == MoneyTransactionType.income) {
        accum.incomeMinor += amount;
      }
    }

    // Determine 7-day window start
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final anchorMonth = scope.anchorMonth;
    final isCurrentMonth =
        anchorMonth.year == now.year && anchorMonth.month == now.month;

    final windowStart = isCurrentMonth
        ? today
              .subtract(const Duration(days: 3))
              .add(Duration(days: offset * 7))
        : _mondayOfWeekContaining(anchorMonth).add(Duration(days: offset * 7));

    return List.generate(7, (i) {
      final date = windowStart.add(Duration(days: i));
      final data = dailyMap[date];
      return HomeDailySpendingPoint(
        date: date,
        expenseMinor: data?.expenseMinor ?? 0,
        incomeMinor: data?.incomeMinor ?? 0,
        transactionCount: data?.count ?? 0,
        isInMonth:
            date.month == anchorMonth.month && date.year == anchorMonth.year,
      );
    });
  },
);

class _DailyAccum {
  int expenseMinor = 0;
  int incomeMinor = 0;
  int count = 0;
}

DateTime _mondayOfWeekContaining(DateTime date) {
  return date.subtract(Duration(days: date.weekday - 1));
}

final homeCategoryStructureProvider =
    FutureProvider<List<HomeCategorySpendingItem>>((ref) async {
      final transactions = await ref.watch(
        homeMonthTransactionsProvider.future,
      );
      final type = ref.watch(homeCategoryStructureTypeProvider);
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

      for (final transaction in transactions) {
        if (transaction.type != transactionType) {
          continue;
        }
        final amountMinor = _effectiveAmountMinor(transaction);
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
      final sorted = transactions.toList()
        ..sort((a, b) => b.transactionAt.compareTo(a.transactionAt));

      return sorted
          .take(5)
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

            return HomeRecentTransactionItem(
              id: transaction.id,
              title: title,
              categoryName: category?.name ?? transaction.type.label,
              accountName: account?.name ?? '未知账户',
              amountMinor: _effectiveAmountMinor(transaction),
              currencyCode: transaction.currencyCode,
              transactionAt: transaction.transactionAt,
              type: _recentTypeFor(transaction.type),
            );
          })
          .toList(growable: false);
    });

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
  };
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

int _effectiveAmountMinor(MoneyTransactionEntity transaction) {
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
