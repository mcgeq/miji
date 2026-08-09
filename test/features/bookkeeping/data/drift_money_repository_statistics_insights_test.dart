import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/seed/database_seed_runner.dart';
import 'package:miji/core/sync/delta_sync/sync_change_logger.dart';
import 'package:miji/core/sync/delta_sync/sync_identity_store.dart';
import 'package:miji/features/bookkeeping/data/drift_money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_statistics_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';

void main() {
  late AppDatabase database;
  late DriftMoneyRepository repository;
  MoneyAccountEntity? defaultAccount;
  MoneyCategoryEntity? defaultCategory;

  setUp(() async {
    defaultAccount = null;
    defaultCategory = null;
    database = AppDatabase(NativeDatabase.memory());
    var nextChangeId = 0;
    repository = DriftMoneyRepository(
      database: database,
      seedRunner: DatabaseSeedRunner(database: database),
      syncChangeLogger: SyncChangeLogger(
        database: database,
        identityResolver: const FixedSyncIdentityResolver(
          SyncIdentity(deviceId: 'device-a', datasetId: 'dataset-a'),
        ),
        createId: () => 'change-${nextChangeId += 1}',
        now: () => DateTime.utc(2026, 7, 13, 8),
      ),
      now: () => DateTime.utc(2026, 7, 13, 8),
    );

    final now = DateTime.utc(2026, 1, 2, 3, 4, 5);
    await database
        .into(database.users)
        .insert(
          UsersCompanion.insert(
            id: 'user_1',
            username: 'user_1',
            email: 'user_1@example.com',
            displayName: '用户',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.moneyMembers)
        .insert(
          MoneyMembersCompanion.insert(
            id: 'default_member_user_1',
            userId: 'user_1',
            name: '用户',
            role: 'owner',
            status: 'active',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.moneyLedgers)
        .insert(
          MoneyLedgersCompanion.insert(
            id: 'default_ledger_user_1',
            userId: 'user_1',
            name: '个人账本',
            createdByMemberId: 'default_member_user_1',
            ledgerType: 'personal',
            status: 'active',
            baseCurrencyCode: 'CNY',
            settlementCycle: 'manual',
            settlementDay: 1,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.moneyLedgerMembers)
        .insert(
          MoneyLedgerMembersCompanion.insert(
            ledgerId: 'default_ledger_user_1',
            memberId: 'default_member_user_1',
            createdAt: now,
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  Future<MoneyAccountEntity> createBankAccount(String name) {
    return repository.createAccount(
      'user_1',
      MoneyAccountDraft(
        name: name,
        type: MoneyAccountType.bank,
        initialBalanceMinor: 1000000,
      ),
    );
  }

  Future<MoneyCategoryEntity> createExpenseCategory(String name) {
    return repository.createCategory(
      'user_1',
      MoneyCategoryDraft(name: name, kind: MoneyCategoryKind.expense),
    );
  }

  Future<MoneyAccountEntity> ensureDefaultAccount() async {
    return defaultAccount ??= await createBankAccount('日常账户');
  }

  Future<MoneyCategoryEntity> ensureDefaultCategory() async {
    return defaultCategory ??= await createExpenseCategory('餐饮');
  }

  Future<void> addExpense(
    DateTime date,
    int amountMinor, {
    MoneyAccountEntity? account,
    MoneyCategoryEntity? category,
    String? merchant,
    String? sourceTemplateRunId,
    String actualPayerAccount = 'default',
    List<String> tags = const <String>[],
    int refundAmountMinor = 0,
  }) async {
    final targetAccount = account ?? await ensureDefaultAccount();
    final targetCategory = category ?? await ensureDefaultCategory();
    final transaction = await repository.createTransaction(
      'user_1',
      MoneyTransactionDraft(
        type: MoneyTransactionType.expense,
        transactionAt: date,
        amountMinor: amountMinor,
        currencyCode: 'CNY',
        description: merchant ?? '测试消费',
        merchant: merchant,
        accountId: targetAccount.id,
        categoryId: targetCategory.id,
        paymentMethod: MoneyPaymentMethod.bankCard,
        ledgerId: 'default_ledger_user_1',
        actualPayerAccount: actualPayerAccount,
        sourceTemplateRunId: sourceTemplateRunId,
        tags: tags,
      ),
    );
    if (refundAmountMinor > 0) {
      await (database.update(
        database.moneyTransactions,
      )..where((row) => row.id.equals(transaction.id))).write(
        MoneyTransactionsCompanion(refundAmountMinor: Value(refundAmountMinor)),
      );
    }
  }

  MoneyStatisticsQuery monthQuery() {
    return MoneyStatisticsQuery(
      dateStart: DateTime(2026, 7),
      dateEndExclusive: DateTime(2026, 8),
      groupBy: MoneyStatisticsGroupBy.day,
      ledgerId: 'default_ledger_user_1',
    );
  }

  test('returns empty insights when no transactions', () async {
    final insights = await repository.getStatisticsInsightsForUser(
      'user_1',
      monthQuery(),
    );

    expect(insights.currencyCode, 'CNY');
    expect(insights.timeSlices, isEmpty);
    expect(insights.weekdaySlices, isEmpty);
    expect(insights.refund.refundCount, 0);
    expect(insights.sourceSlices, isEmpty);
    expect(insights.sourceTrend, hasLength(1));
    expect(insights.sourceTrend.single.bucketStart, DateTime(2026, 7));
    expect(insights.tagSlices, isEmpty);
  });

  test('buckets expenses into time buckets with correct boundaries', () async {
    await addExpense(DateTime(2026, 7, 1, 3), 1000); // 深夜 23-5
    await addExpense(DateTime(2026, 7, 1, 7), 2000); // 清晨 5-11
    await addExpense(DateTime(2026, 7, 1, 12), 3000); // 上午 11-14
    await addExpense(DateTime(2026, 7, 1, 16), 4000); // 下午 14-18
    await addExpense(DateTime(2026, 7, 1, 21), 5000); // 晚上 18-23

    final insights = await repository.getStatisticsInsightsForUser(
      'user_1',
      monthQuery(),
    );

    expect(
      insights.timeSlices.map((slice) => slice.bucket),
      MoneyStatisticsTimeBucket.values,
    );
    final byBucket = {
      for (final slice in insights.timeSlices) slice.bucket: slice.amountMinor,
    };
    expect(byBucket[MoneyStatisticsTimeBucket.lateNight], 1000);
    expect(byBucket[MoneyStatisticsTimeBucket.earlyMorning], 2000);
    expect(byBucket[MoneyStatisticsTimeBucket.morning], 3000);
    expect(byBucket[MoneyStatisticsTimeBucket.afternoon], 4000);
    expect(byBucket[MoneyStatisticsTimeBucket.evening], 5000);
    final total = insights.timeSlices.fold<int>(
      0,
      (sum, slice) => sum + slice.amountMinor,
    );
    expect(total, 15000);
    final counts = {
      for (final slice in insights.timeSlices)
        slice.bucket: slice.transactionCount,
    };
    expect(counts.values.fold<int>(0, (sum, count) => sum + count), 5);
    expect(counts[MoneyStatisticsTimeBucket.lateNight], 1);
  });

  test('groups expenses by weekday and marks weekends', () async {
    await addExpense(DateTime(2026, 7, 6), 1000); // 周一
    await addExpense(DateTime(2026, 7, 7), 2000); // 周二
    await addExpense(DateTime(2026, 7, 11), 4000); // 周六
    await addExpense(DateTime(2026, 7, 12), 5000); // 周日

    final insights = await repository.getStatisticsInsightsForUser(
      'user_1',
      monthQuery(),
    );

    expect(insights.weekdaySlices, hasLength(7));
    expect(insights.weekdaySlices[0].weekday, 1);
    expect(insights.weekdaySlices[0].amountMinor, 1000);
    expect(insights.weekdaySlices[5].amountMinor, 4000);
    expect(insights.weekdaySlices[5].isWeekend, isTrue);
    expect(insights.weekdaySlices[6].amountMinor, 5000);
    final total = insights.weekdaySlices.fold<int>(
      0,
      (sum, slice) => sum + slice.amountMinor,
    );
    expect(total, 12000);
  });

  test('computes refund summary with refunded transactions', () async {
    await addExpense(DateTime(2026, 7, 2), 5000);
    await addExpense(DateTime(2026, 7, 3), 8000, refundAmountMinor: 2000);
    await addExpense(DateTime(2026, 7, 4), 3000, refundAmountMinor: 3000);
    await addExpense(DateTime(2026, 7, 5, 12), 1000);

    final insights = await repository.getStatisticsInsightsForUser(
      'user_1',
      monthQuery(),
    );

    expect(insights.refund.refundCount, 2);
    expect(insights.refund.refundAmountMinor, 5000);
    expect(insights.refund.transactionCount, 4);
    expect(insights.refund.refundRate, closeTo(0.5, 0.001));
  });

  test('splits expenses into installment, auto-posting and manual', () async {
    await addExpense(DateTime(2026, 7, 3), 3000); // 手工
    await addExpense(
      DateTime(2026, 7, 4),
      4000,
      actualPayerAccount: 'installment',
    );
    await addExpense(DateTime(2026, 7, 5), 5000, sourceTemplateRunId: 'run-1');

    final insights = await repository.getStatisticsInsightsForUser(
      'user_1',
      monthQuery(),
    );

    final byType = {
      for (final slice in insights.sourceSlices) slice.sourceType: slice,
    };
    expect(byType['manual']!.amountMinor, 3000);
    expect(byType['installment']!.amountMinor, 4000);
    expect(byType['auto_posting']!.amountMinor, 5000);
    expect(byType['installment']!.label, '分期');
    expect(byType['auto_posting']!.label, '自动记账');
    expect(byType['manual']!.percentage, closeTo(0.25, 0.001));
  });

  test('builds monthly source trend aligned to the filter window', () async {
    await addExpense(DateTime(2026, 7, 10), 1000);
    await addExpense(
      DateTime(2026, 7, 11),
      2000,
      actualPayerAccount: 'installment',
    );
    await addExpense(DateTime(2026, 7, 12), 3000, sourceTemplateRunId: 'run-1');

    final insights = await repository.getStatisticsInsightsForUser(
      'user_1',
      MoneyStatisticsQuery(
        dateStart: DateTime(2026, 6),
        dateEndExclusive: DateTime(2026, 8),
        groupBy: MoneyStatisticsGroupBy.month,
        ledgerId: 'default_ledger_user_1',
      ),
    );

    expect(insights.sourceTrend, hasLength(2));
    expect(insights.sourceTrend.first.bucketStart, DateTime(2026, 6));
    expect(insights.sourceTrend.last.bucketStart, DateTime(2026, 7));
    final point = insights.sourceTrend.last;
    expect(point.otherMinor, 1000);
    expect(point.installmentMinor, 2000);
    expect(point.autoPostingMinor, 3000);
    expect(point.totalMinor, 6000);
  });

  test('ranks tags by expense amount', () async {
    await addExpense(DateTime(2026, 7, 2), 3000, tags: const ['出差']);
    await addExpense(DateTime(2026, 7, 3), 2000, tags: const ['出差', '餐饮']);
    await addExpense(DateTime(2026, 7, 4), 1000, tags: const ['餐饮']);
    await addExpense(DateTime(2026, 7, 5), 4000);

    final insights = await repository.getStatisticsInsightsForUser(
      'user_1',
      monthQuery(),
    );

    expect(insights.tagSlices, hasLength(2));
    expect(insights.tagSlices[0].tag, '出差');
    expect(insights.tagSlices[0].amountMinor, 5000);
    expect(insights.tagSlices[0].transactionCount, 2);
    expect(insights.tagSlices[1].tag, '餐饮');
    expect(insights.tagSlices[1].amountMinor, 3000);
    expect(insights.tagSlices[0].percentage, closeTo(0.625, 0.001));
  });

  test('reports credit utilization for credit-like accounts only', () async {
    await createBankAccount('日常账户');
    final creditCard = await repository.createAccount(
      'user_1',
      const MoneyAccountDraft(
        name: '招商银行',
        type: MoneyAccountType.creditCard,
        initialBalanceMinor: 2000000,
        statementDay: 5,
        repaymentDay: 25,
      ),
    );
    final huabei = await repository.createAccount(
      'user_1',
      const MoneyAccountDraft(
        name: '花呗',
        type: MoneyAccountType.huabei,
        initialBalanceMinor: 1000000,
      ),
    );

    await addExpense(DateTime(2026, 7, 2), 1200000, account: creditCard);
    await addExpense(DateTime(2026, 7, 3), 400000, account: huabei);

    final insights = await repository.getStatisticsInsightsForUser(
      'user_1',
      monthQuery(),
    );

    expect(insights.creditUtilization, hasLength(2));
    final credit = insights.creditUtilization.singleWhere(
      (slice) => slice.accountId == creditCard.id,
    );
    expect(credit.creditLimitMinor, 2000000);
    expect(credit.usedMinor, 1200000);
    expect(credit.availableMinor, 800000);
    expect(credit.utilization, closeTo(0.6, 0.001));
    final huabeiSlice = insights.creditUtilization.singleWhere(
      (slice) => slice.accountId == huabei.id,
    );
    expect(huabeiSlice.usedMinor, 400000);
    expect(huabeiSlice.utilization, closeTo(0.4, 0.001));
  });
}
