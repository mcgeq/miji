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
    // 没有预留时可支配额度就是全额预算，与 usedProgress 同值。
    expect(
      homeBudgetPaceLabelFor(
        spendableProgress: budget.progress,
        usedProgress: budget.progress,
        periodProgress: pace.periodProgress,
      ),
      '节奏正常',
    );
    expect(
      homeBudgetPaceLabelFor(
        spendableProgress: 0.84,
        usedProgress: 0.84,
        periodProgress: pace.periodProgress,
      ),
      '花费偏快',
    );
    // 已用超过全额预算由调用方（hero）判超支，节奏函数本身只讲快慢。
    expect(
      homeBudgetPaceLabelFor(
        spendableProgress: 1.02,
        usedProgress: 1.02,
        periodProgress: pace.periodProgress,
      ),
      '花费偏快',
    );
  });

  test('pace divides by the spendable pool, not the full budget', () {
    // 用户实报：预算 4980、已用 2013.39、已预留 2778.39、日均可花 12.54。
    // 已预留被未来义务锁死，真正能安排的是 4980 − 2778.39 = 2201.61，
    // 已经用掉 91.4%，而时间才过 54.8% —— 这是明确偏快。
    // 旧的（全额做分母）算法得到 0.404 / 0.548 = 0.74 倍，判「偏慢」，
    // 与同一张卡上的「日均可花 ¥12.54」互相矛盾：12.54 恰恰是按扣掉
    // 预留算出来的。
    const total = 4980.0;
    const used = 2013.39;
    const committed = 2778.39;
    const periodProgress = 17 / 31; // 0.5484

    final spendableProgress = used / (total - committed); // 0.9143
    expect(spendableProgress, closeTo(0.914, 0.001));
    expect(
      homeBudgetPaceLabelFor(
        spendableProgress: spendableProgress,
        usedProgress: used / total,
        periodProgress: periodProgress,
      ),
      '花费偏快',
    );
    expect(
      homeBudgetHeroPaceLabel(
        usedProgress: used / total,
        spendableProgress: spendableProgress,
        periodProgress: periodProgress,
        occupiedProgress: (used + committed) / total,
      ),
      '花费偏快',
    );
  });

  test('spendable progress is capped when the pool is reserved out', () {
    expect(
      homeBudgetSpendableProgress(
        totalMinor: 100000,
        usedMinor: 20000,
        committedMinor: 0,
      ),
      closeTo(0.2, 1e-9),
    );
    // 预留已经把额度吃光：没有可支配余量，任何已用都算用满。
    expect(
      homeBudgetSpendableProgress(
        totalMinor: 100000,
        usedMinor: 5000,
        committedMinor: 100000,
      ),
      1,
    );
  });

  test('pace label switches at the documented ratios', () {
    // 时间过半时的三档：0.7 / 1.0 / 1.3 倍（无预留，两比例同值）。
    String label(double progress) => homeBudgetPaceLabelFor(
      spendableProgress: progress,
      usedProgress: progress,
      periodProgress: 0.5,
    );

    expect(label(0.35), '节奏偏慢');
    expect(label(0.50), '节奏正常');
    expect(label(0.65), '花费偏快');

    // 月初已用不足 5% 时不判偏慢：倍率此时完全由分母决定。
    expect(
      homeBudgetPaceLabelFor(
        spendableProgress: 0.01,
        usedProgress: 0.01,
        periodProgress: 0.03,
      ),
      '节奏正常',
    );
    expect(
      homeBudgetPaceLabelFor(
        spendableProgress: 0.5,
        usedProgress: 0.5,
        periodProgress: 0.03,
      ),
      '花费偏快',
    );

    // 后半月不再出现「时间过了 80%、只用了 80% 却说偏快」的反向判定。
    expect(
      homeBudgetPaceLabelFor(
        spendableProgress: 0.80,
        usedProgress: 0.80,
        periodProgress: 0.85,
      ),
      '节奏正常',
    );
  });

  test('hero pace label ranks overspent and reserved-full above pace', () {
    // 已超支优先于一切。
    expect(
      homeBudgetHeroPaceLabel(
        usedProgress: 1.02,
        spendableProgress: 1,
        periodProgress: 0.55,
        occupiedProgress: 1.02,
      ),
      '已超支',
    );
    // 占用到 100%：已用没超、额度被预留吃穿，结论同样是「这个月钱没了」。
    // 以前这里返回「额度已被预留占满」，于是 Hero 说「还可花 ¥0」、记账卡
    // 说「本月已超支」—— 同一份数据两个结论。构成由明细行去拆。
    expect(
      homeBudgetHeroPaceLabel(
        usedProgress: 0.4,
        spendableProgress: 1,
        periodProgress: 0.55,
        occupiedProgress: 1.0,
      ),
      '已超支',
    );
    // 节奏报警时讲节奏 —— 行动项是「别再花」。
    expect(
      homeBudgetHeroPaceLabel(
        usedProgress: 0.4,
        spendableProgress: 0.976,
        periodProgress: 0.55,
        occupiedProgress: 0.99,
      ),
      '花费偏快',
    );
    // 节奏没报警、占用却很高，才由「大半被预留」解释钱为什么紧。
    expect(
      homeBudgetHeroPaceLabel(
        usedProgress: 0.02,
        spendableProgress: 0.25,
        periodProgress: 0.5,
        occupiedProgress: 0.94,
      ),
      '额度大半已被预留',
    );
    // 占用不高时走节奏判定（这里是偏慢）。
    expect(
      homeBudgetHeroPaceLabel(
        usedProgress: 0.4,
        spendableProgress: 0.4,
        periodProgress: 0.55,
        occupiedProgress: 0.4,
      ),
      '节奏偏慢',
    );
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

  @override
  Future<void> resetAutoPostingRun(String userId, String runId) async {}
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
