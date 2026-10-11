import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/seed/database_seed_runner.dart';
import 'package:miji/core/sync/delta_sync/sync_change_logger.dart';
import 'package:miji/core/sync/delta_sync/sync_identity_store.dart';
import 'package:miji/features/bookkeeping/data/drift_money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_auto_posting_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';

void main() {
  late AppDatabase database;
  late DriftMoneyRepository repository;
  late MoneyAccountEntity account;
  late MoneyCategoryEntity expenseCategory;

  setUp(() async {
    final now = DateTime.utc(2026, 1, 2, 3, 4, 5);
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
        now: () => now,
      ),
      now: () => now,
    );

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
          mode: InsertMode.insertOrIgnore,
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
          mode: InsertMode.insertOrIgnore,
        );
    await database
        .into(database.moneyLedgerMembers)
        .insert(
          MoneyLedgerMembersCompanion.insert(
            ledgerId: 'default_ledger_user_1',
            memberId: 'default_member_user_1',
            createdAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );

    account = await repository.createAccount(
      'user_1',
      const MoneyAccountDraft(
        name: '支付宝',
        type: MoneyAccountType.alipay,
        initialBalanceMinor: 100000000,
      ),
    );
    expenseCategory = await repository.createCategory(
      'user_1',
      const MoneyCategoryDraft(name: '餐饮', kind: MoneyCategoryKind.expense),
    );
  });

  tearDown(() async {
    await database.close();
  });

  MoneyAutoPostingTemplateDraft templateDraft({
    required MoneyAutoPostingFrequency frequency,
    int? dayOfMonth,
    int? weekday,
    int timeOfDayMinutes = 9 * 60,
    String? accountId,
    int? amountMinor,
  }) {
    return MoneyAutoPostingTemplateDraft(
      name: '测试模板',
      type: MoneyTransactionType.expense,
      amountMinor: amountMinor ?? 12345,
      currencyCode: 'CNY',
      description: '自动记账测试',
      accountId: accountId ?? account.id,
      categoryId: expenseCategory.id,
      paymentMethod: MoneyPaymentMethod.alipay,
      ledgerId: 'default_ledger_user_1',
      timeOfDayMinutes: timeOfDayMinutes,
      frequency: frequency,
      dayOfMonth: dayOfMonth,
      weekday: weekday,
      startsOn: DateTime(2029, 12, 1),
    );
  }

  test(
    'daily template posts transactions at the template local time',
    () async {
      final template = await repository.createAutoPostingTemplate(
        'user_1',
        templateDraft(frequency: MoneyAutoPostingFrequency.daily),
      );
      expect(template.currencyCode, 'CNY');

      final summary = await repository.executeDueAutoPostings(
        'user_1',
        now: DateTime(2030, 1, 1, 5, 0),
      );

      expect(summary.postedCount, greaterThanOrEqualTo(1));
      // 每笔流水都必须落在模板指定的本地时刻 09:00（修复前 UTC+8 会记成 17:00）。
      final transactions = await (database.select(
        database.moneyTransactions,
      )..where((r) => r.userId.equals('user_1'))).get();
      expect(transactions, hasLength(summary.postedCount));
      for (final transaction in transactions) {
        final local = transaction.transactionAt.toLocal();
        expect(
          local.hour,
          9,
          reason: 'transactionAt=${transaction.transactionAt}',
        );
        expect(local.minute, 0);
        expect(transaction.currencyCode, 'CNY');
        expect(transaction.amountMinor, 12345);
      }

      // 再次执行不得重复入账（幂等）。
      final again = await repository.executeDueAutoPostings(
        'user_1',
        now: DateTime(2030, 1, 1, 5, 0),
      );
      expect(again.postedCount, 0);
      expect(again.skippedCount, summary.postedCount);
    },
  );

  test('monthly day31 clamps to last day and keeps local time', () async {
    final template = await repository.createAutoPostingTemplate(
      'user_1',
      templateDraft(
        frequency: MoneyAutoPostingFrequency.monthly,
        dayOfMonth: 31,
        timeOfDayMinutes: 21 * 60 + 30,
      ),
    );
    expect(template.dayOfMonth, 31);

    final summary = await repository.executeDueAutoPostings(
      'user_1',
      now: DateTime(2030, 3, 1, 10, 0),
    );

    // 2029-12、2030-01、2030-02（2/28 不存在 31 日，钳制到月末）。
    expect(summary.postedCount, 3);

    final transactions =
        await (database.select(database.moneyTransactions)
              ..where((r) => r.userId.equals('user_1'))
              ..orderBy([(r) => OrderingTerm.asc(r.transactionAt)]))
            .get();
    expect(transactions, hasLength(3));
    final localDates = [
      for (final t in transactions)
        (t.transactionAt.toLocal(), t.transactionAt),
    ];
    expect(localDates[0].$1.month, 12);
    expect(localDates[0].$1.day, 31);
    expect(localDates[1].$1.month, 1);
    expect(localDates[1].$1.day, 31);
    expect(localDates[2].$1.month, 2);
    expect(localDates[2].$1.day, 28);
    for (final (local, _) in localDates) {
      expect(local.hour, 21);
      expect(local.minute, 30);
    }
  });

  test(
    'weekly template posts on the configured weekday at local time',
    () async {
      await repository.createAutoPostingTemplate(
        'user_1',
        templateDraft(
          frequency: MoneyAutoPostingFrequency.weekly,
          weekday: DateTime.friday,
          timeOfDayMinutes: 0,
        ),
      );

      final summary = await repository.executeDueAutoPostings(
        'user_1',
        now: DateTime(2029, 12, 29, 9, 0),
      );

      // 2029-12-07/14/21/28 都是周五，均早于 12/29 09:00。
      expect(summary.postedCount, 4);
      for (final transaction in await (database.select(
        database.moneyTransactions,
      )..where((r) => r.userId.equals('user_1'))).get()) {
        expect(transaction.transactionAt.toLocal().weekday, DateTime.friday);
        expect(transaction.transactionAt.toLocal().hour, 0);
        expect(transaction.transactionAt.toLocal().minute, 0);
      }
    },
  );

  test(
    'blocked run can be reset to pending and re-posted after funds restored',
    () async {
      // 余额很低的账户：模板金额必然触发 insufficientFunds → blocked。
      final lowAccount = await repository.createAccount(
        'user_1',
        const MoneyAccountDraft(
          name: '零钱账户',
          type: MoneyAccountType.cash,
          initialBalanceMinor: 100,
        ),
      );
      final incomeCategory = await repository.createCategory(
        'user_1',
        const MoneyCategoryDraft(name: '收入', kind: MoneyCategoryKind.income),
      );
      final template = await repository.createAutoPostingTemplate(
        'user_1',
        templateDraft(
          frequency: MoneyAutoPostingFrequency.monthly,
          dayOfMonth: 1,
          accountId: lowAccount.id,
        ),
      );

      // 首次执行：余额不足 → 已拦截，且不产生流水。
      final first = await repository.executeAutoPostingTemplateNow(
        'user_1',
        template.id,
        now: DateTime(2029, 12, 1, 10, 0),
      );
      expect(first.blockedCount, 1);
      expect(first.postedCount, 0);
      expect(
        await (database.select(
          database.moneyTransactions,
        )..where((r) => r.userId.equals('user_1'))).get(),
        isEmpty,
      );

      var runs = await (database.select(
        database.moneyAutoPostingRuns,
      )..where((r) => r.userId.equals('user_1'))).get();
      expect(runs, hasLength(1));
      expect(
        runs.single.status,
        MoneyAutoPostingRunStatus.blocked.storageValue,
      );
      expect(runs.single.errorCode, isNotNull);

      // 重置为待执行：清空错误信息。
      await repository.resetAutoPostingRun('user_1', runs.single.id);
      runs = await (database.select(
        database.moneyAutoPostingRuns,
      )..where((r) => r.userId.equals('user_1'))).get();
      expect(
        runs.single.status,
        MoneyAutoPostingRunStatus.pending.storageValue,
      );
      expect(runs.single.errorCode, isNull);
      expect(runs.single.errorMessage, isNull);

      // 补足余额后再次执行 → 成功入账。
      await repository.createTransaction(
        'user_1',
        MoneyTransactionDraft(
          type: MoneyTransactionType.income,
          transactionAt: DateTime(2029, 12, 1, 8, 0),
          amountMinor: 50000,
          currencyCode: 'CNY',
          description: '充值',
          accountId: lowAccount.id,
          categoryId: incomeCategory.id,
          paymentMethod: MoneyPaymentMethod.cash,
          ledgerId: 'default_ledger_user_1',
        ),
      );
      final second = await repository.executeAutoPostingTemplateNow(
        'user_1',
        template.id,
        now: DateTime(2029, 12, 1, 10, 0),
      );
      expect(second.postedCount, 1);
      expect(second.blockedCount, 0);

      runs = await (database.select(
        database.moneyAutoPostingRuns,
      )..where((r) => r.userId.equals('user_1'))).get();
      expect(runs.single.status, MoneyAutoPostingRunStatus.posted.storageValue);
      expect(runs.single.transactionId, isNotNull);
    },
  );
}
