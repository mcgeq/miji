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

  Future<MoneyTransactionEntity> addExpense(
    MoneyCategoryEntity category,
    int amountMinor, {
    required String accountId,
    List<String> tags = const <String>[],
  }) {
    return repository.createTransaction(
      'user_1',
      MoneyTransactionDraft(
        type: MoneyTransactionType.expense,
        transactionAt: DateTime.now().toUtc(),
        amountMinor: amountMinor,
        currencyCode: 'CNY',
        description: '代付消费',
        accountId: accountId,
        categoryId: category.id,
        paymentMethod: MoneyPaymentMethod.cash,
        tags: tags,
        ledgerId: 'default_ledger_user_1',
        actualPayerAccount: 'default',
      ),
    );
  }

  test('system internal account is auto-created and queryable', () async {
    // 任意一次仓库操作都会触发 ensureReadyForUser，创建系统内部账户。
    final internalList = await repository
        .watchSystemInternalAccountsForUser('user_1')
        .first;

    expect(internalList, hasLength(1));
    final internal = internalList.single;
    expect(internal.id, 'internal_account_user_1');
    expect(internal.type, MoneyAccountType.internal);
    expect(internal.isVirtual, isTrue);
    expect(internal.isActive, isTrue);
  });

  test(
    'internal account stays out of visible and ledger account lists',
    () async {
      final visible = await repository
          .watchVisibleAccountsForUser('user_1')
          .first;
      expect(
        visible.map((account) => account.id),
        isNot(contains('internal_account_user_1')),
      );

      final ledgerAccounts = await repository
          .watchAccountsForLedger('user_1', 'default_ledger_user_1')
          .first;
      expect(
        ledgerAccounts.map((account) => account.id),
        isNot(contains('internal_account_user_1')),
      );
      expect(
        ledgerAccounts.map((account) => account.id),
        contains(bankAccount.id),
      );
    },
  );

  test('expense on internal account counts into tag budget', () async {
    await repository.createBudget(
      'user_1',
      MoneyBudgetDraft(
        name: '南京旅游预算',
        amountMinor: 500000,
        scopeType: MoneyBudgetScopeType.tag,
        tag: '南京旅游',
      ),
    );

    await addExpense(
      diningCategory,
      20000,
      accountId: 'internal_account_user_1',
      tags: const ['南京旅游'],
    );

    final budgets = await repository.watchBudgetsForUser('user_1').first;
    final budget = budgets.singleWhere((b) => b.tag == '南京旅游');
    expect(budget.usedAmountMinor, 20000);
  });
}
