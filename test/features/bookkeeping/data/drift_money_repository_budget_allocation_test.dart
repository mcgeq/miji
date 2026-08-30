import 'dart:async';
import 'dart:convert';

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
import 'package:miji/features/bookkeeping/domain/money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
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

  test('manages budget allocations and records delta changes', () async {
    final account = await repository.createAccount(
      'user_1',
      const MoneyAccountDraft(
        name: '现金',
        type: MoneyAccountType.cash,
        initialBalanceMinor: 0,
      ),
    );
    final budget = await repository.createBudget(
      'user_1',
      MoneyBudgetDraft(
        name: '餐饮预算',
        amountMinor: 100000,
        accountId: account.id,
      ),
    );

    final allocation = await repository.createBudgetAllocation(
      'user_1',
      MoneyBudgetAllocationDraft(
        budgetId: budget.id,
        allocatedAmountMinor: 30000,
        notes: '工作日午餐',
      ),
    );

    expect(allocation.budgetId, budget.id);
    expect(allocation.allocatedAmountMinor, 30000);
    expect(allocation.remainingAmountMinor, 30000);
    expect(allocation.status, MoneyBudgetAllocationStatus.active);

    final watched = await repository
        .watchBudgetAllocationsForUser('user_1', budget.id)
        .first;
    expect(watched.map((item) => item.id), [allocation.id]);

    final updated = await repository.updateBudgetAllocation(
      'user_1',
      MoneyBudgetAllocationUpdate(
        id: allocation.id,
        allocatedAmountMinor: 36000,
        notes: '工作日午餐和咖啡',
      ),
    );
    expect(updated.allocatedAmountMinor, 36000);
    expect(updated.remainingAmountMinor, 36000);
    expect(updated.version, allocation.version + 1);

    await repository.deleteBudgetAllocation('user_1', allocation.id);
    expect(
      await repository.watchBudgetAllocationsForUser('user_1', budget.id).first,
      isEmpty,
    );

    final allocationLogs =
        (await database.select(database.syncChangeLogs).get())
            .where(
              (row) =>
                  row.targetTable ==
                  SyncChangeLogger.moneyBudgetAllocationsTableName,
            )
            .toList();
    expect(allocationLogs.map((row) => row.operation), [
      'insert',
      'update',
      'delete',
    ]);
    expect(
      jsonDecode(allocationLogs[1].changedFieldsJson),
      containsPair('allocated_amount_minor', 36000),
    );
    expect(
      jsonDecode(allocationLogs[1].changedFieldsJson),
      isNot(containsPair('budget_id', budget.id)),
    );
  });

  test(
    'calculates category allocation usage from matching transactions',
    () async {
      final account = await repository.createAccount(
        'user_1',
        const MoneyAccountDraft(
          name: '现金',
          type: MoneyAccountType.cash,
          initialBalanceMinor: 50000,
        ),
      );
      final food = await repository.createCategory(
        'user_1',
        const MoneyCategoryDraft(name: '餐饮', kind: MoneyCategoryKind.expense),
      );
      final shopping = await repository.createCategory(
        'user_1',
        const MoneyCategoryDraft(name: '购物', kind: MoneyCategoryKind.expense),
      );
      final budget = await repository.createBudget(
        'user_1',
        MoneyBudgetDraft(
          name: '月度支出',
          amountMinor: 40000,
          accountId: account.id,
        ),
      );
      final allocation = await repository.createBudgetAllocation(
        'user_1',
        MoneyBudgetAllocationDraft(
          budgetId: budget.id,
          categoryId: food.id,
          allocatedAmountMinor: 20000,
        ),
      );

      await repository.createTransaction(
        'user_1',
        MoneyTransactionDraft(
          type: MoneyTransactionType.expense,
          transactionAt: DateTime.now().toUtc(),
          amountMinor: 12000,
          currencyCode: 'CNY',
          description: '午餐',
          accountId: account.id,
          categoryId: food.id,
          paymentMethod: MoneyPaymentMethod.cash,
        ),
      );
      await repository.createTransaction(
        'user_1',
        MoneyTransactionDraft(
          type: MoneyTransactionType.expense,
          transactionAt: DateTime.now().toUtc(),
          amountMinor: 5000,
          currencyCode: 'CNY',
          description: '衣服',
          accountId: account.id,
          categoryId: shopping.id,
          paymentMethod: MoneyPaymentMethod.cash,
        ),
      );

      final watched = await repository
          .watchBudgetAllocationsForUser('user_1', budget.id)
          .first;
      final refreshed = watched.singleWhere((item) => item.id == allocation.id);

      expect(refreshed.usedAmountMinor, 12000);
      expect(refreshed.remainingAmountMinor, 8000);
    },
  );

  test(
    'calculates family member allocation usage from split details',
    () async {
      final account = await repository.createAccount(
        'user_1',
        const MoneyAccountDraft(
          name: '家庭卡',
          type: MoneyAccountType.bank,
          initialBalanceMinor: 100000,
        ),
      );
      final category = await repository.createCategory(
        'user_1',
        const MoneyCategoryDraft(name: '家庭餐饮', kind: MoneyCategoryKind.expense),
      );
      final family = await repository.createLedger(
        'user_1',
        const MoneyLedgerDraft(name: '家庭账本'),
      );
      final me = await repository.createMember(
        'user_1',
        const MoneyMemberDraft(name: '我', role: 'owner'),
        ledgerId: family.id,
      );
      final partner = await repository.createMember(
        'user_1',
        const MoneyMemberDraft(name: '家人', role: 'participant'),
        ledgerId: family.id,
      );
      final budget = await repository.createBudget(
        'user_1',
        MoneyBudgetDraft(
          name: '家庭月预算',
          ledgerId: family.id,
          amountMinor: 60000,
          accountId: account.id,
        ),
      );
      final allocation = await repository.createBudgetAllocation(
        'user_1',
        MoneyBudgetAllocationDraft(
          budgetId: budget.id,
          memberId: partner.id,
          allocatedAmountMinor: 30000,
        ),
      );
      final transaction = await repository.createTransaction(
        'user_1',
        MoneyTransactionDraft(
          type: MoneyTransactionType.expense,
          ledgerId: family.id,
          transactionAt: DateTime.now().toUtc(),
          amountMinor: 20000,
          currencyCode: 'CNY',
          description: '家庭晚餐',
          accountId: account.id,
          categoryId: category.id,
          paymentMethod: MoneyPaymentMethod.bankCard,
        ),
      );
      await repository.createSplitForTransaction(
        'user_1',
        MoneySplitDraft(
          ledgerId: family.id,
          transactionId: transaction.id,
          splitType: MoneySplitType.fixedAmount,
          payerMemberId: me.id,
          participants: [
            MoneySplitParticipantDraft(memberId: me.id, amountMinor: 8000),
            MoneySplitParticipantDraft(
              memberId: partner.id,
              amountMinor: 12000,
            ),
          ],
        ),
      );

      final watched = await repository
          .watchBudgetAllocationsForUser('user_1', budget.id)
          .first;
      final refreshed = watched.singleWhere((item) => item.id == allocation.id);

      expect(refreshed.usedAmountMinor, 12000);
      expect(refreshed.remainingAmountMinor, 18000);
    },
  );

  test(
    'updates allocation usage stream when matching transaction changes',
    () async {
      final account = await repository.createAccount(
        'user_1',
        const MoneyAccountDraft(
          name: '现金',
          type: MoneyAccountType.cash,
          initialBalanceMinor: 50000,
        ),
      );
      final food = await repository.createCategory(
        'user_1',
        const MoneyCategoryDraft(name: '餐饮', kind: MoneyCategoryKind.expense),
      );
      final budget = await repository.createBudget(
        'user_1',
        MoneyBudgetDraft(
          name: '月度支出',
          amountMinor: 40000,
          accountId: account.id,
        ),
      );
      final allocation = await repository.createBudgetAllocation(
        'user_1',
        MoneyBudgetAllocationDraft(
          budgetId: budget.id,
          categoryId: food.id,
          allocatedAmountMinor: 20000,
        ),
      );

      final iterator = StreamIterator(
        repository.watchBudgetAllocationsForUser('user_1', budget.id),
      );
      addTearDown(iterator.cancel);
      expect(await iterator.moveNext(), isTrue);
      expect(
        iterator.current
            .singleWhere((item) => item.id == allocation.id)
            .usedAmountMinor,
        0,
      );

      final nextEmission = iterator.moveNext().timeout(
        const Duration(seconds: 2),
      );
      await Future<void>.delayed(Duration.zero);

      await repository.createTransaction(
        'user_1',
        MoneyTransactionDraft(
          type: MoneyTransactionType.expense,
          transactionAt: DateTime.now().toUtc(),
          amountMinor: 12000,
          currencyCode: 'CNY',
          description: '午餐',
          accountId: account.id,
          categoryId: food.id,
          paymentMethod: MoneyPaymentMethod.cash,
        ),
      );

      expect(await nextEmission, isTrue);
      final refreshed = iterator.current.singleWhere(
        (item) => item.id == allocation.id,
      );
      expect(refreshed.usedAmountMinor, 12000);
      expect(refreshed.remainingAmountMinor, 8000);
    },
  );

  test('rejects allocations exceeding budget amount', () async {
    final account = await repository.createAccount(
      'user_1',
      const MoneyAccountDraft(
        name: '现金',
        type: MoneyAccountType.cash,
        initialBalanceMinor: 0,
      ),
    );
    final budget = await repository.createBudget(
      'user_1',
      MoneyBudgetDraft(name: '月度支出', amountMinor: 10000, accountId: account.id),
    );
    await repository.createBudgetAllocation(
      'user_1',
      MoneyBudgetAllocationDraft(
        budgetId: budget.id,
        allocatedAmountMinor: 7000,
      ),
    );

    await expectLater(
      repository.createBudgetAllocation(
        'user_1',
        MoneyBudgetAllocationDraft(
          budgetId: budget.id,
          allocatedAmountMinor: 4000,
        ),
      ),
      throwsA(
        isA<MoneyRepositoryException>().having(
          (error) => error.code,
          'code',
          MoneyRepositoryErrorCode.invalidBudgetAmount,
        ),
      ),
    );
  });

  test(
    'allows a single participant with the payer outside the split details',
    () async {
      final account = await repository.createAccount(
        'user_1',
        const MoneyAccountDraft(
          name: '家庭卡',
          type: MoneyAccountType.bank,
          initialBalanceMinor: 100000,
        ),
      );
      final category = await repository.createCategory(
        'user_1',
        const MoneyCategoryDraft(name: '家庭餐饮', kind: MoneyCategoryKind.expense),
      );
      final family = await repository.createLedger(
        'user_1',
        const MoneyLedgerDraft(name: '家庭账本'),
      );
      final me = await repository.createMember(
        'user_1',
        const MoneyMemberDraft(name: '我', role: 'owner'),
        ledgerId: family.id,
      );
      final partner = await repository.createMember(
        'user_1',
        const MoneyMemberDraft(name: '家人', role: 'participant'),
        ledgerId: family.id,
      );
      final transaction = await repository.createTransaction(
        'user_1',
        MoneyTransactionDraft(
          type: MoneyTransactionType.expense,
          ledgerId: family.id,
          transactionAt: DateTime.now().toUtc(),
          amountMinor: 20000,
          currencyCode: 'CNY',
          description: '代购',
          accountId: account.id,
          categoryId: category.id,
          paymentMethod: MoneyPaymentMethod.bankCard,
        ),
      );

      // 付款人（我）只垫付不参与分摊，参与成员仅家人一人。
      final split = await repository.createSplitForTransaction(
        'user_1',
        MoneySplitDraft(
          ledgerId: family.id,
          transactionId: transaction.id,
          splitType: MoneySplitType.fixedAmount,
          payerMemberId: me.id,
          participants: [
            MoneySplitParticipantDraft(
              memberId: partner.id,
              amountMinor: 20000,
            ),
          ],
        ),
      );

      expect(split.payerMemberId, me.id);
      expect(split.details, hasLength(1));
      expect(split.details.single.memberId, partner.id);
      expect(split.details.single.amountMinor, 20000);
    },
  );
}
