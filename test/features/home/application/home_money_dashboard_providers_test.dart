import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/auth/domain/auth_session.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';
import 'package:miji/features/home/application/home_money_dashboard_providers.dart';

void main() {
  test('computes budget period progress and pace from budget dates', () {
    final budget = _budget(
      amountMinor: 400000,
      usedAmountMinor: 232000,
      periodStart: DateTime(2026, 7),
      periodEnd: DateTime(2026, 7, 31, 23, 59, 59, 999),
    );

    final pace = homeBudgetPeriodPaceFor(budget, DateTime(2026, 7, 19));

    expect(pace.remainingDays, 13);
    expect(pace.periodProgress, closeTo(19 / 31, 0.001));
    expect(
      pace.paceRatioFor(budget.progress),
      closeTo(0.58 / (19 / 31), 0.001),
    );
    expect(
      homeBudgetPaceLabelFor(budget.progress, pace.periodProgress),
      '节奏正常',
    );
    expect(homeBudgetPaceLabelFor(0.84, pace.periodProgress), '花费偏快');
    expect(homeBudgetPaceLabelFor(1.02, pace.periodProgress), '已超支');
  });

  test(
    'home dashboard refetches after moneyDataRefreshCoordinator.refreshHome',
    () async {
      final repository = _FakeMoneyRepository();
      final container = ProviderContainer(
        overrides: [
          authSessionControllerProvider.overrideWith(
            _UnlockedAuthController.new,
          ),
          moneyRepositoryProvider.overrideWithValue(repository),
          homeMoneyMonthScopeProvider.overrideWithValue(
            HomeMoneyMonthScope.from(DateTime(2026, 7)),
          ),
          currentUserCurrentLedgerProvider.overrideWith(
            (ref) async => _ledgerEntity(),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(homeMonthTransactionsProvider, (_, _) {});

      final initial = await container.read(
        homeMonthTransactionsProvider.future,
      );
      expect(initial, isEmpty);
      expect(repository.listTransactionsCalls, 1);

      container.read(moneyDataRefreshCoordinatorProvider).refreshHome();
      // refreshHome 的 bump 在 microtask 中合并执行，先让出事件循环再读取。
      await Future<void>.delayed(Duration.zero);
      await container.read(homeMonthTransactionsProvider.future);

      expect(repository.listTransactionsCalls, 2);
    },
  );
}

MoneyLedgerEntity _ledgerEntity() {
  final now = DateTime.utc(2026, 1, 1);
  return MoneyLedgerEntity(
    id: 'ledger-1',
    userId: 'user-1',
    name: '个人账本',
    ledgerType: 'personal',
    status: 'active',
    baseCurrencyCode: 'CNY',
    createdAt: now,
    updatedAt: now,
  );
}

class _UnlockedAuthController extends AuthSessionController {
  @override
  AuthSession build() => const AuthSession(userId: 'user-1', isUnlocked: true);
}

class _FakeMoneyRepository extends Fake implements MoneyRepository {
  int listTransactionsCalls = 0;

  @override
  Future<void> ensureReadyForUser(String userId) async {}

  @override
  Future<MoneyTransactionPage> listTransactions(
    String userId,
    MoneyTransactionQuery query,
  ) async {
    listTransactionsCalls += 1;
    return MoneyTransactionPage(
      items: const <MoneyTransactionEntity>[],
      page: query.page,
      pageSize: query.pageSize,
      hasMore: false,
      total: 0,
    );
  }
}

MoneyBudgetEntity _budget({
  required int amountMinor,
  required int usedAmountMinor,
  required DateTime periodStart,
  required DateTime periodEnd,
}) {
  return MoneyBudgetEntity(
    id: 'budget-1',
    userId: 'user-1',
    ledgerId: 'ledger-1',
    scopeType: MoneyBudgetScopeType.all,
    name: '日常支出预算',
    trackingType: MoneyBudgetTrackingType.expenseLimit,
    periodType: MoneyBudgetPeriodType.monthly,
    repeatInterval: 1,
    amountMinor: amountMinor,
    currencyCode: 'CNY',
    periodStart: periodStart,
    periodEnd: periodEnd,
    categoryId: null,
    subCategoryId: null,
    usedAmountMinor: usedAmountMinor,
    isActive: true,
    alertEnabled: true,
    alertThresholdPercent: 80,
    autoRollover: false,
    createdAt: periodStart,
    updatedAt: periodStart,
  );
}
