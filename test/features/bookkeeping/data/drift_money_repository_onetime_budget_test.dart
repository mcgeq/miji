import 'package:drift/drift.dart' hide isNull;
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
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';

void main() {
  late AppDatabase database;
  late DriftMoneyRepository repository;
  late MoneyAccountEntity bankAccount;
  late MoneyCategoryEntity diningCategory;

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

    bankAccount = await repository.createAccount(
      'user_1',
      MoneyAccountDraft(
        name: '银行卡',
        type: MoneyAccountType.bank,
        initialBalanceMinor: 1000000,
      ),
    );
    diningCategory = await repository.createCategory(
      'user_1',
      MoneyCategoryDraft(name: '餐饮', kind: MoneyCategoryKind.expense),
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<MoneyBudgetEntity> createOneTimeBudget({
    DateTime? startDate,
    DateTime? endDate,
    MoneyBudgetScopeType scopeType = MoneyBudgetScopeType.all,
    String? tag,
    bool omitRange = false,
  }) {
    return repository.createBudget(
      'user_1',
      MoneyBudgetDraft(
        name: '旅行预算',
        amountMinor: 100000,
        scopeType: scopeType,
        tag: tag,
        periodType: MoneyBudgetPeriodType.oneTime,
        startDate: omitRange ? null : (startDate ?? DateTime(2026, 4, 1)),
        endDate: omitRange ? null : (endDate ?? DateTime(2026, 4, 5)),
      ),
    );
  }

  Future<MoneyTransactionEntity> addExpense(
    MoneyCategoryEntity category,
    int amountMinor, {
    required DateTime at,
    List<String> tags = const <String>[],
  }) {
    return repository.createTransaction(
      'user_1',
      MoneyTransactionDraft(
        type: MoneyTransactionType.expense,
        transactionAt: at,
        amountMinor: amountMinor,
        currencyCode: 'CNY',
        description: '测试消费',
        accountId: bankAccount.id,
        categoryId: category.id,
        paymentMethod: MoneyPaymentMethod.bankCard,
        tags: tags,
        ledgerId: 'default_ledger_user_1',
        actualPayerAccount: 'default',
      ),
    );
  }

  Future<MoneyBudgetEntity> refreshBudget(String budgetId) async {
    final budgets = await repository.watchBudgetsForUser('user_1').first;
    return budgets.singleWhere((budget) => budget.id == budgetId);
  }

  test('creates one-time budget with fixed date range', () async {
    final budget = await createOneTimeBudget();

    expect(budget.periodType, MoneyBudgetPeriodType.oneTime);
    expect(budget.periodStart, DateTime(2026, 4, 1));
    // endDate 存 exclusive 次日，展示为含结束当天。
    expect(budget.periodEnd, DateTime(2026, 4, 5, 23, 59, 59, 999));
  });

  test('counts only transactions inside the fixed range', () async {
    final budget = await createOneTimeBudget();
    await addExpense(diningCategory, 10000, at: DateTime(2026, 4, 3, 12));
    await addExpense(diningCategory, 5000, at: DateTime(2026, 3, 31, 12));
    await addExpense(diningCategory, 2000, at: DateTime(2026, 4, 6, 0, 0, 1));

    final refreshed = await refreshBudget(budget.id);
    expect(refreshed.usedAmountMinor, 10000);
  });

  test(
    'tag-scoped one-time budget counts tagged transactions in range',
    () async {
      final budget = await createOneTimeBudget(
        scopeType: MoneyBudgetScopeType.tag,
        tag: '南京旅游',
      );
      await addExpense(
        diningCategory,
        8000,
        at: DateTime(2026, 4, 2, 12),
        tags: const ['南京旅游'],
      );
      await addExpense(
        diningCategory,
        3000,
        at: DateTime(2026, 4, 2, 12),
        tags: const ['其他'],
      );
      await addExpense(
        diningCategory,
        1000,
        at: DateTime(2026, 4, 2, 12),
        tags: const ['南京旅游'],
      );

      final refreshed = await refreshBudget(budget.id);
      expect(refreshed.usedAmountMinor, 9000);
    },
  );

  test('rejects one-time budget without date range', () async {
    await expectLater(
      createOneTimeBudget(omitRange: true),
      throwsA(
        isA<MoneyRepositoryException>().having(
          (error) => error.code,
          'code',
          MoneyRepositoryErrorCode.unsupportedBudgetPeriod,
        ),
      ),
    );
  });

  test('rejects one-time budget with end before start', () async {
    await expectLater(
      createOneTimeBudget(
        startDate: DateTime(2026, 4, 10),
        endDate: DateTime(2026, 4, 1),
      ),
      throwsA(
        isA<MoneyRepositoryException>().having(
          (error) => error.code,
          'code',
          MoneyRepositoryErrorCode.unsupportedBudgetPeriod,
        ),
      ),
    );
  });

  test('edits one-time budget date range', () async {
    final budget = await createOneTimeBudget();
    await addExpense(diningCategory, 6000, at: DateTime(2026, 4, 3, 12));

    final updated = await repository.updateBudget(
      'user_1',
      MoneyBudgetUpdate(
        id: budget.id,
        name: budget.name,
        ledgerId: 'default_ledger_user_1',
        amountMinor: budget.amountMinor,
        periodType: MoneyBudgetPeriodType.oneTime,
        startDate: DateTime(2026, 5, 1),
        endDate: DateTime(2026, 5, 3),
      ),
    );

    expect(updated.periodStart, DateTime(2026, 5, 1));
    expect(updated.periodEnd, DateTime(2026, 5, 3, 23, 59, 59, 999));
    // 4 月的交易不再属于新范围。
    expect(updated.usedAmountMinor, 0);
  });

  test('switches one-time budget to monthly period', () async {
    final budget = await createOneTimeBudget();

    final updated = await repository.updateBudget(
      'user_1',
      MoneyBudgetUpdate(
        id: budget.id,
        name: budget.name,
        ledgerId: 'default_ledger_user_1',
        amountMinor: budget.amountMinor,
        periodType: MoneyBudgetPeriodType.monthly,
      ),
    );

    expect(updated.periodType, MoneyBudgetPeriodType.monthly);
    final now = DateTime.now();
    expect(updated.periodStart, DateTime(now.year, now.month));
    expect(
      updated.periodEnd,
      DateTime(
        now.year,
        now.month + 1,
      ).subtract(const Duration(milliseconds: 1)),
    );
  });

  test('snapshot refresh works for one-time budget', () async {
    final budget = await createOneTimeBudget();
    await addExpense(diningCategory, 4000, at: DateTime(2026, 4, 4, 12));

    // currentUserBudgetsProvider 每次执行都会走这条链路。
    await repository.refreshBudgetSnapshotsForUser('user_1');

    final snapshots = await repository
        .watchBudgetSnapshotsForUser('user_1')
        .first;
    final snapshot = snapshots.singleWhere((s) => s.budgetId == budget.id);
    expect(snapshot.periodType, MoneyBudgetPeriodType.oneTime);
    expect(snapshot.periodStart, DateTime(2026, 4, 1));
    expect(snapshot.periodEnd, DateTime(2026, 4, 5, 23, 59, 59, 999));
    expect(snapshot.usedAmountMinor, 4000);
  });
}
