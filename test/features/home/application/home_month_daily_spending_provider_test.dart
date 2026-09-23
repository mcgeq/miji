import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/auth/domain/auth_session.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/home/application/home_money_dashboard_providers.dart';

/// 日历翻月必须**真的去查库并重算**，而不是复用别处的月份数据。
///
/// 这里盯住两条路径：
/// - 展示月份 == 仪表盘选中月 → 复用 `homeMonthTransactionsProvider`（已含 ±7 天，零额外查询）；
/// - 其它月份（用户在日历里往回翻）→ 按该月单独查一次库。
void main() {
  test('选中月复用已加载的月交易，不再额外查库', () async {
    final repository = _FakeMoneyRepository();
    final container = _container(repository, selectedMonth: DateTime(2026, 3));

    final summary = await container.read(
      homeMonthDailySpendingProvider(DateTime(2026, 3)).future,
    );

    expect(summary.expenseMinor, greaterThan(0));
    // 只有 homeMonthTransactionsProvider 那一次（按 ±7 天的范围查）。
    expect(repository.calls, hasLength(1));
    expect(repository.calls.single.start, DateTime(2026, 2, 22));
    expect(repository.calls.single.endExclusive, DateTime(2026, 4, 8));
  });

  test('日历翻到别的月份时，会按那个月单独查库并重算', () async {
    final repository = _FakeMoneyRepository(
      // 每个月只放一笔，金额=月份序号×100 元，方便断言「算的确实是那个月」。
      amountForMonth: (month) => month * 10000,
    );
    final container = _container(repository, selectedMonth: DateTime(2026, 3));

    final march = await container.read(
      homeMonthDailySpendingProvider(DateTime(2026, 3)).future,
    );
    expect(march.expenseMinor, 30000);

    // 往前翻到 1 月。
    final january = await container.read(
      homeMonthDailySpendingProvider(DateTime(2026, 1)).future,
    );

    expect(january.expenseMinor, 10000);
    expect(january.month, DateTime(2026, 1));
    // 第二次查询的范围必须正好是 1 月整月。
    expect(repository.calls, hasLength(2));
    expect(repository.calls.last.start, DateTime(2026, 1));
    expect(repository.calls.last.endExclusive, DateTime(2026, 2));
  });

  test('切换选中月份后会重新查库，旧月份缓存不再冒充新月份', () async {
    final repository = _FakeMoneyRepository(
      amountForMonth: (month) => month * 10000,
    );
    final container = _container(repository, selectedMonth: DateTime(2026, 3));

    await container.read(
      homeMonthDailySpendingProvider(DateTime(2026, 3)).future,
    );
    final callsAfterFirst = repository.calls.length;

    // 用户在顶栏/日历把月份切到 2 月。
    container
        .read(homeMoneySelectedMonthProvider.notifier)
        .set(DateTime(2026, 2));

    final february = await container.read(
      homeMonthDailySpendingProvider(DateTime(2026, 2)).future,
    );

    expect(february.expenseMinor, 20000, reason: '必须重新查库并重算');
    expect(
      repository.calls.length,
      greaterThan(callsAfterFirst),
      reason: '切月应当触发新的数据库查询',
    );
    // 新查询范围是 2 月 ±7 天（选中月路径）。
    expect(repository.calls.last.start, DateTime(2026, 1, 25));
    expect(repository.calls.last.endExclusive, DateTime(2026, 3, 8));
  });
}

ProviderContainer _container(
  _FakeMoneyRepository repository, {
  required DateTime selectedMonth,
}) {
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(_UnlockedAuthController.new),
      moneyRepositoryProvider.overrideWithValue(repository),
      currentUserCurrentLedgerProvider.overrideWith(
        (ref) async => _ledgerEntity(),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(homeMoneySelectedMonthProvider.notifier).set(selectedMonth);
  return container;
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

class _QueryRange {
  const _QueryRange({required this.start, required this.endExclusive});

  final DateTime start;
  final DateTime endExclusive;
}

class _FakeMoneyRepository extends Fake implements MoneyRepository {
  _FakeMoneyRepository({this.amountForMonth});

  /// 返回的金额可以按月份定制；默认每个月固定一笔 100 元。
  final int Function(int month)? amountForMonth;

  final List<_QueryRange> calls = <_QueryRange>[];

  @override
  Future<void> ensureReadyForUser(String userId) async {}

  @override
  Future<MoneyTransactionPage> listTransactions(
    String userId,
    MoneyTransactionQuery query,
  ) async {
    final start = query.dateStart!;
    // 仓储接口收的是闭区间，这里换算回「开区间末端」方便断言。
    final endExclusive = query.dateEnd!.add(const Duration(microseconds: 1));
    calls.add(_QueryRange(start: start, endExclusive: endExclusive));

    // 区间内每个「1 号」放一笔，金额 = 月份 × 100 元。
    // 这样断言「算的是哪个月」不会被 ±7 天的补白干扰。
    final items = <MoneyTransactionEntity>[];
    var cursor = DateTime(start.year, start.month);
    while (cursor.isBefore(endExclusive)) {
      if (!cursor.isBefore(start)) {
        items.add(_txn(cursor, (amountForMonth ?? (_) => 10000)(cursor.month)));
      }
      cursor = DateTime(cursor.year, cursor.month + 1);
    }

    return MoneyTransactionPage(
      items: items,
      page: query.page,
      pageSize: query.pageSize,
      hasMore: false,
      total: items.length,
    );
  }
}

MoneyTransactionEntity _txn(DateTime at, int amountMinor) {
  final now = DateTime.utc(2026, 1, 1);
  return MoneyTransactionEntity(
    id: 'txn-${at.millisecondsSinceEpoch}-$amountMinor',
    userId: 'user-1',
    type: MoneyTransactionType.expense,
    status: MoneyTransactionStatus.completed,
    transactionAt: at,
    amountMinor: amountMinor,
    refundAmountMinor: 0,
    currencyCode: 'CNY',
    description: '',
    notes: null,
    merchant: null,
    location: null,
    accountId: 'account-1',
    toAccountId: null,
    categoryId: 'category-1',
    subCategoryId: null,
    paymentMethod: MoneyPaymentMethod.other,
    customPaymentMethodName: null,
    actualPayerAccount: 'default',
    relatedTransactionId: null,
    installmentPlanId: null,
    sourceTemplateRunId: null,
    interestRateBasisPoints: null,
    totalInterestMinor: 0,
    calcMethod: null,
    tags: const [],
    isDeleted: false,
    createdAt: now,
    updatedAt: now,
  );
}
