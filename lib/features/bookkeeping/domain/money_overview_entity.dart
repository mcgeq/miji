import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';

class MoneyOverviewEntity {
  const MoneyOverviewEntity({
    required this.currencySummaries,
    required this.accounts,
    required this.budgets,
    required this.recentTransactions,
  });

  const MoneyOverviewEntity.empty()
    : currencySummaries = const <MoneyOverviewCurrencySummary>[],
      accounts = const <MoneyAccountEntity>[],
      budgets = const <MoneyBudgetEntity>[],
      recentTransactions = const <MoneyTransactionEntity>[];

  factory MoneyOverviewEntity.fromSources({
    required List<MoneyAccountEntity> accounts,
    required Map<String, MoneyAccountMonthlySummary> accountSummaries,
    required List<MoneyBudgetEntity> budgets,
    required List<MoneyTransactionEntity> recentTransactions,
  }) {
    final mutableSummaries = <String, _MutableOverviewCurrencySummary>{};
    for (final account in accounts) {
      final summary = mutableSummaries.putIfAbsent(
        account.currencyCode,
        () => _MutableOverviewCurrencySummary(account.currencyCode),
      );
      if (account.isActive) {
        if (account.type.isCreditLike) {
          if (account.usedCreditMinor > 0) {
            summary.liabilityMinor += account.usedCreditMinor;
          }
        } else {
          summary.assetMinor += account.balanceMinor;
        }
      }

      final monthly = accountSummaries[account.id];
      if (monthly != null) {
        summary.currentIncomeMinor += monthly.currentIncomeMinor;
        summary.currentExpenseMinor += monthly.currentExpenseMinor;
      }
    }

    for (final budget in budgets.where((budget) => budget.isActive)) {
      final summary = mutableSummaries.putIfAbsent(
        budget.currencyCode,
        () => _MutableOverviewCurrencySummary(budget.currencyCode),
      );
      if (budget.isIncomeTarget) {
        summary.incomeTargetAmountMinor += budget.amountMinor;
        summary.incomeTargetEarnedMinor += budget.usedAmountMinor;
      } else {
        summary.expenseBudgetAmountMinor += budget.amountMinor;
        summary.expenseBudgetUsedMinor += budget.usedAmountMinor;
      }
    }

    final currencySummaries =
        mutableSummaries.values.map((summary) => summary.toEntity()).toList()
          ..sort(
            (left, right) => left.currencyCode.compareTo(right.currencyCode),
          );

    return MoneyOverviewEntity(
      currencySummaries: currencySummaries,
      accounts: accounts,
      budgets: budgets,
      recentTransactions: recentTransactions,
    );
  }

  final List<MoneyOverviewCurrencySummary> currencySummaries;
  final List<MoneyAccountEntity> accounts;
  final List<MoneyBudgetEntity> budgets;
  final List<MoneyTransactionEntity> recentTransactions;

  int get activeAccountCount {
    return accounts.where((account) => account.isActive).length;
  }

  int get activeBudgetCount {
    return budgets.where((budget) => budget.isActive).length;
  }

  int get activeExpenseBudgetCount {
    return budgets
        .where((budget) => budget.isActive && budget.isExpenseLimit)
        .length;
  }

  int get activeIncomeTargetCount {
    return budgets
        .where((budget) => budget.isActive && budget.isIncomeTarget)
        .length;
  }

  int get overspentBudgetCount {
    return budgets
        .where((budget) => budget.isActive && budget.isOverspent)
        .length;
  }

  int get alertExpenseBudgetCount {
    return budgets
        .where(
          (budget) =>
              budget.isActive && budget.isExpenseLimit && budget.shouldAlert,
        )
        .length;
  }

  int get completedIncomeTargetCount {
    return budgets
        .where((budget) => budget.isActive && budget.isCompleted)
        .length;
  }

  int get alertIncomeTargetCount {
    return budgets
        .where(
          (budget) =>
              budget.isActive && budget.isIncomeTarget && budget.shouldAlert,
        )
        .length;
  }
}

class MoneyOverviewCurrencySummary {
  const MoneyOverviewCurrencySummary({
    required this.currencyCode,
    required this.assetMinor,
    required this.liabilityMinor,
    required this.currentIncomeMinor,
    required this.currentExpenseMinor,
    required int this._expenseBudgetAmountMinor,
    required int this._expenseBudgetUsedMinor,
    required int this._incomeTargetAmountMinor,
    required int this._incomeTargetEarnedMinor,
  });

  final String currencyCode;
  final int assetMinor;
  final int liabilityMinor;
  final int currentIncomeMinor;
  final int currentExpenseMinor;
  final int? _expenseBudgetAmountMinor;
  final int? _expenseBudgetUsedMinor;
  final int? _incomeTargetAmountMinor;
  final int? _incomeTargetEarnedMinor;

  int get netAssetMinor => assetMinor - liabilityMinor;

  int get currentNetMinor => currentIncomeMinor - currentExpenseMinor;

  int get expenseBudgetAmountMinor => _expenseBudgetAmountMinor ?? 0;

  int get expenseBudgetUsedMinor => _expenseBudgetUsedMinor ?? 0;

  int get incomeTargetAmountMinor => _incomeTargetAmountMinor ?? 0;

  int get incomeTargetEarnedMinor => _incomeTargetEarnedMinor ?? 0;

  int get expenseBudgetRemainingMinor {
    return expenseBudgetAmountMinor - expenseBudgetUsedMinor;
  }

  int get incomeTargetRemainingMinor {
    return incomeTargetAmountMinor - incomeTargetEarnedMinor;
  }
}

class _MutableOverviewCurrencySummary {
  _MutableOverviewCurrencySummary(this.currencyCode);

  final String currencyCode;
  int assetMinor = 0;
  int liabilityMinor = 0;
  int currentIncomeMinor = 0;
  int currentExpenseMinor = 0;
  int expenseBudgetAmountMinor = 0;
  int expenseBudgetUsedMinor = 0;
  int incomeTargetAmountMinor = 0;
  int incomeTargetEarnedMinor = 0;

  MoneyOverviewCurrencySummary toEntity() {
    return MoneyOverviewCurrencySummary(
      currencyCode: currencyCode,
      assetMinor: assetMinor,
      liabilityMinor: liabilityMinor,
      currentIncomeMinor: currentIncomeMinor,
      currentExpenseMinor: currentExpenseMinor,
      expenseBudgetAmountMinor: expenseBudgetAmountMinor,
      expenseBudgetUsedMinor: expenseBudgetUsedMinor,
      incomeTargetAmountMinor: incomeTargetAmountMinor,
      incomeTargetEarnedMinor: incomeTargetEarnedMinor,
    );
  }
}
