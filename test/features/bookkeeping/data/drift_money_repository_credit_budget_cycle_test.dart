import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/seed/database_seed_runner.dart';
import 'package:miji/core/sync/delta_sync/sync_change_logger.dart';
import 'package:miji/core/sync/delta_sync/sync_identity_store.dart';
import 'package:miji/features/bookkeeping/data/drift_money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';

void main() {
  late AppDatabase database;
  late DriftMoneyRepository repository;

  setUp(() async {
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
  });

  tearDown(() async {
    await database.close();
  });

  test('persists budget cycle start day for credit-like accounts', () async {
    final account = await repository.createAccount(
      'user_1',
      const MoneyAccountDraft(
        name: '招行信用卡',
        type: MoneyAccountType.creditCard,
        initialBalanceMinor: 2000000,
        statementDay: 17,
        repaymentDay: 10,
        budgetCycleStartDay: 16,
      ),
    );

    expect(account.statementDay, 17);
    expect(account.repaymentDay, 10);
    expect(account.budgetCycleStartDay, 16);

    final updated = await repository.updateAccount(
      'user_1',
      MoneyAccountUpdate(
        id: account.id,
        name: account.name,
        type: account.type,
        currencyCode: account.currencyCode,
        initialBalanceMinor: account.initialBalanceMinor,
        statementDay: 17,
        repaymentDay: 10,
        budgetCycleStartDay: 15,
      ),
    );

    expect(updated.budgetCycleStartDay, 15);

    final rows = await (database.select(
      database.moneyAccounts,
    )..where((row) => row.id.equals(account.id))).get();
    expect(rows.single.budgetCycleStartDay, 15);
  });

  test('billing-cycle budget uses custom budget cycle start day', () async {
    final account = await repository.createAccount(
      'user_1',
      const MoneyAccountDraft(
        name: '招行信用卡',
        type: MoneyAccountType.creditCard,
        initialBalanceMinor: 2000000,
        statementDay: 17,
        repaymentDay: 10,
        budgetCycleStartDay: 16,
      ),
    );

    final budget = await repository.createBudget(
      'user_1',
      MoneyBudgetDraft(
        name: '信用卡账单周期预算',
        amountMinor: 300000,
        accountId: account.id,
        periodType: MoneyBudgetPeriodType.billingCycle,
      ),
    );

    expect(budget.periodStart, DateTime(2026, 6, 16));
    expect(budget.periodEnd, DateTime(2026, 7, 15, 23, 59, 59, 999));
  });

  test(
    'billing-cycle budget falls back to statement day when custom day is unset',
    () async {
      final account = await repository.createAccount(
        'user_1',
        const MoneyAccountDraft(
          name: '备用信用卡',
          type: MoneyAccountType.creditCard,
          initialBalanceMinor: 2000000,
          statementDay: 17,
          repaymentDay: 10,
        ),
      );

      final budget = await repository.createBudget(
        'user_1',
        MoneyBudgetDraft(
          name: '默认账单周期预算',
          amountMinor: 300000,
          accountId: account.id,
          periodType: MoneyBudgetPeriodType.billingCycle,
        ),
      );

      expect(budget.periodStart, DateTime(2026, 6, 17));
      expect(budget.periodEnd, DateTime(2026, 7, 16, 23, 59, 59, 999));
    },
  );

  test(
    'billing-cycle budget includes last visible day and excludes next cycle start',
    () async {
      final account = await repository.createAccount(
        'user_1',
        const MoneyAccountDraft(
          name: '招行信用卡',
          type: MoneyAccountType.creditCard,
          initialBalanceMinor: 2000000,
          statementDay: 17,
          repaymentDay: 10,
          budgetCycleStartDay: 16,
        ),
      );
      final category = await repository.createCategory(
        'user_1',
        const MoneyCategoryDraft(name: '餐饮', kind: MoneyCategoryKind.expense),
      );
      final budget = await repository.createBudget(
        'user_1',
        MoneyBudgetDraft(
          name: '信用卡账单周期预算',
          amountMinor: 300000,
          accountId: account.id,
          periodType: MoneyBudgetPeriodType.billingCycle,
        ),
      );

      await repository.createTransaction(
        'user_1',
        MoneyTransactionDraft(
          type: MoneyTransactionType.expense,
          transactionAt: DateTime(2026, 7, 15, 23, 59, 59, 999),
          amountMinor: 12000,
          currencyCode: 'CNY',
          description: '本期最后一天',
          accountId: account.id,
          categoryId: category.id,
          paymentMethod: MoneyPaymentMethod.creditCard,
        ),
      );
      await repository.createTransaction(
        'user_1',
        MoneyTransactionDraft(
          type: MoneyTransactionType.expense,
          transactionAt: DateTime(2026, 7, 16),
          amountMinor: 99000,
          currencyCode: 'CNY',
          description: '下期第一天',
          accountId: account.id,
          categoryId: category.id,
          paymentMethod: MoneyPaymentMethod.creditCard,
        ),
      );

      final budgets = await repository.watchBudgetsForUser('user_1').first;
      final refreshed = budgets.singleWhere((item) => item.id == budget.id);

      expect(refreshed.usedAmountMinor, 12000);
    },
  );
}
