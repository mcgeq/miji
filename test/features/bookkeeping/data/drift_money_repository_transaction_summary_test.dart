import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/seed/database_seed_runner.dart';
import 'package:miji/core/sync/delta_sync/sync_change_logger.dart';
import 'package:miji/core/sync/delta_sync/sync_identity_store.dart';
import 'package:miji/features/bookkeeping/data/drift_money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';

/// 汇总条与排序的数据层保证。
void main() {
  late AppDatabase database;
  late DriftMoneyRepository repository;
  late MoneyAccountEntity account;
  late MoneyCategoryEntity expenseCategory;
  late MoneyCategoryEntity incomeCategory;

  final transactionDate = DateTime.utc(2026, 7, 1, 10);

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

    account = await repository.createAccount(
      'user_1',
      MoneyAccountDraft(
        name: '银行卡',
        type: MoneyAccountType.bank,
        initialBalanceMinor: 1000000,
      ),
    );
    expenseCategory = await repository.createCategory(
      'user_1',
      MoneyCategoryDraft(name: '餐饮', kind: MoneyCategoryKind.expense),
    );
    incomeCategory = await repository.createCategory(
      'user_1',
      MoneyCategoryDraft(name: '工资', kind: MoneyCategoryKind.income),
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<MoneyTransactionEntity> addExpense(int amountMinor, {DateTime? at}) {
    return repository.createTransaction(
      'user_1',
      MoneyTransactionDraft(
        type: MoneyTransactionType.expense,
        transactionAt: at ?? transactionDate,
        amountMinor: amountMinor,
        currencyCode: 'CNY',
        description: '测试消费',
        accountId: account.id,
        categoryId: expenseCategory.id,
        paymentMethod: MoneyPaymentMethod.bankCard,
        ledgerId: 'default_ledger_user_1',
        actualPayerAccount: 'default',
      ),
    );
  }

  Future<void> addIncome(int amountMinor) {
    return repository.createTransaction(
      'user_1',
      MoneyTransactionDraft(
        type: MoneyTransactionType.income,
        transactionAt: transactionDate,
        amountMinor: amountMinor,
        currencyCode: 'CNY',
        description: '测试收入',
        accountId: account.id,
        categoryId: incomeCategory.id,
        paymentMethod: MoneyPaymentMethod.bankCard,
        ledgerId: 'default_ledger_user_1',
        actualPayerAccount: 'default',
      ),
    );
  }

  group('summarizeTransactions', () {
    test('aggregates every transaction, not just the first page', () async {
      // 25 笔 > 默认 pageSize 20，确保汇总不受分页影响。
      for (var index = 0; index < 25; index++) {
        await addExpense(1000);
      }
      await addIncome(50000);

      final query = MoneyTransactionQuery(pageSize: 20);
      final page = await repository.listTransactions('user_1', query);
      expect(page.items.length, 20);
      expect(page.total, 26);

      final summary = await repository.summarizeTransactions('user_1', query);
      expect(summary.count, 26);
      expect(summary.expenseMinor, 25000);
      expect(summary.incomeMinor, 50000);
      expect(summary.netMinor, 25000);
    });

    test('respects the same filters as the list', () async {
      await addExpense(1000);
      await addExpense(2000);
      await addIncome(50000);

      final onlyExpense = await repository.summarizeTransactions(
        'user_1',
        const MoneyTransactionQuery(type: MoneyTransactionType.expense),
      );
      expect(onlyExpense.count, 2);
      expect(onlyExpense.expenseMinor, 3000);
      expect(onlyExpense.incomeMinor, 0);

      final onlyIncome = await repository.summarizeTransactions(
        'user_1',
        const MoneyTransactionQuery(type: MoneyTransactionType.income),
      );
      expect(onlyIncome.count, 1);
      expect(onlyIncome.incomeMinor, 50000);
      expect(onlyIncome.expenseMinor, 0);
    });

    test('excludes transfers from expense and income totals', () async {
      await addExpense(10000);
      await addIncome(50000);
      final secondAccount = await repository.createAccount(
        'user_1',
        MoneyAccountDraft(
          name: '现金',
          type: MoneyAccountType.cash,
          initialBalanceMinor: 0,
        ),
      );
      await repository.createTransfer(
        'user_1',
        MoneyTransferDraft(
          transactionAt: transactionDate,
          amountMinor: 30000,
          currencyCode: 'CNY',
          description: '转账',
          fromAccountId: account.id,
          toAccountId: secondAccount.id,
          ledgerId: 'default_ledger_user_1',
        ),
      );

      final summary = await repository.summarizeTransactions(
        'user_1',
        const MoneyTransactionQuery(),
      );

      // 转账的两个方向都不计入支出/收入/笔数。
      expect(summary.count, 2);
      expect(summary.expenseMinor, 10000);
      expect(summary.incomeMinor, 50000);
      expect(summary.netMinor, 40000);
    });

    test('ignores legacy rows filed under a transfer category', () async {
      await addExpense(10000);
      // 历史数据里可能存在「用转账分类记的支出/收入」：统计页与账户余额都按转账
      // 处理，汇总条也必须一致地排除，否则笔数与金额会和别处对不上。
      await database
          .into(database.moneyTransactions)
          .insert(
            MoneyTransactionsCompanion.insert(
              id: 'legacy_transfer_income',
              userId: 'user_1',
              type: MoneyTransactionType.income.storageValue,
              status: MoneyTransactionStatus.completed.storageValue,
              transactionAt: transactionDate,
              amountMinor: 999900,
              currencyCode: 'CNY',
              description: '历史转账',
              accountId: account.id,
              categoryId: 'income_transfer',
              paymentMethod: MoneyPaymentMethod.bankTransfer.storageValue,
              actualPayerAccount: 'default',
              createdAt: transactionDate,
              updatedAt: transactionDate,
            ),
          );

      final summary = await repository.summarizeTransactions(
        'user_1',
        const MoneyTransactionQuery(),
      );

      expect(summary.count, 1);
      expect(summary.expenseMinor, 10000);
      expect(summary.incomeMinor, 0);
    });

    test('subtracts refunds from the expense total', () async {
      final transaction = await addExpense(10000);
      await repository.recordTransactionRefund('user_1', transaction.id, 4000);

      final summary = await repository.summarizeTransactions(
        'user_1',
        const MoneyTransactionQuery(),
      );
      expect(summary.expenseMinor, 6000);
    });

    test('returns an empty summary when nothing matches', () async {
      await addExpense(1000);

      final summary = await repository.summarizeTransactions(
        'user_1',
        MoneyTransactionQuery(
          dateStart: DateTime(2020, 1, 1),
          dateEnd: DateTime(2020, 12, 31),
        ),
      );
      expect(summary.count, 0);
      expect(summary.expenseMinor, 0);
      expect(summary.incomeMinor, 0);
    });
  });

  group('transaction sorting', () {
    test('sorts by time descending by default', () async {
      await addExpense(1000, at: DateTime.utc(2026, 7, 1, 10));
      await addExpense(2000, at: DateTime.utc(2026, 7, 3, 10));
      await addExpense(3000, at: DateTime.utc(2026, 7, 2, 10));

      final page = await repository.listTransactions(
        'user_1',
        const MoneyTransactionQuery(),
      );
      // 7/3 -> 7/2 -> 7/1
      expect(page.items.map((item) => item.amountMinor).toList(), [
        2000,
        3000,
        1000,
      ]);
    });

    test('sorts by amount descending', () async {
      await addExpense(1000, at: DateTime.utc(2026, 7, 1, 10));
      await addExpense(3000, at: DateTime.utc(2026, 7, 2, 10));
      await addExpense(2000, at: DateTime.utc(2026, 7, 3, 10));

      final page = await repository.listTransactions(
        'user_1',
        const MoneyTransactionQuery(
          sortField: MoneyTransactionSortField.amount,
        ),
      );
      expect(page.items.map((item) => item.amountMinor).toList(), [
        3000,
        2000,
        1000,
      ]);
    });

    test('sorts by amount ascending', () async {
      await addExpense(1000, at: DateTime.utc(2026, 7, 1, 10));
      await addExpense(3000, at: DateTime.utc(2026, 7, 2, 10));
      await addExpense(2000, at: DateTime.utc(2026, 7, 3, 10));

      final page = await repository.listTransactions(
        'user_1',
        const MoneyTransactionQuery(
          sortField: MoneyTransactionSortField.amount,
          sortAscending: true,
        ),
      );
      expect(page.items.map((item) => item.amountMinor).toList(), [
        1000,
        2000,
        3000,
      ]);
    });

    test('sorts by time ascending', () async {
      await addExpense(1000, at: DateTime.utc(2026, 7, 1, 10));
      await addExpense(2000, at: DateTime.utc(2026, 7, 3, 10));
      await addExpense(3000, at: DateTime.utc(2026, 7, 2, 10));

      final page = await repository.listTransactions(
        'user_1',
        const MoneyTransactionQuery(sortAscending: true),
      );
      expect(page.items.map((item) => item.amountMinor).toList(), [
        1000,
        3000,
        2000,
      ]);
    });
  });

  group('MoneyTransactionQuery', () {
    test('copyWith keeps filters and only changes what is passed', () {
      const query = MoneyTransactionQuery(
        page: 3,
        pageSize: 50,
        keyword: '奶茶',
        ledgerId: 'ledger-1',
      );

      final updated = query.copyWith(
        page: 1,
        sortField: MoneyTransactionSortField.amount,
        sortAscending: true,
      );

      expect(updated.page, 1);
      expect(updated.pageSize, 50);
      expect(updated.keyword, '奶茶');
      expect(updated.ledgerId, 'ledger-1');
      expect(updated.sortField, MoneyTransactionSortField.amount);
      expect(updated.sortAscending, isTrue);
    });

    test('equality includes the sort settings', () {
      const base = MoneyTransactionQuery();
      expect(base == const MoneyTransactionQuery(), isTrue);
      expect(
        base ==
            const MoneyTransactionQuery(
              sortField: MoneyTransactionSortField.amount,
            ),
        isFalse,
      );
    });
  });
}
