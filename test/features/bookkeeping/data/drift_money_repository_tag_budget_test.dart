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
  late MoneyCategoryEntity transportCategory;

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
    transportCategory = await repository.createCategory(
      'user_1',
      MoneyCategoryDraft(name: '交通', kind: MoneyCategoryKind.expense),
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<MoneyBudgetEntity> createTagBudget({String? tag}) {
    return repository.createBudget(
      'user_1',
      MoneyBudgetDraft(
        name: '南京旅游预算',
        amountMinor: 500000,
        scopeType: MoneyBudgetScopeType.tag,
        tag: tag ?? '南京旅游',
      ),
    );
  }

  Future<MoneyBudgetEntity> createAllBudget() {
    return repository.createBudget(
      'user_1',
      MoneyBudgetDraft(
        name: '月度总预算',
        amountMinor: 1000000,
        scopeType: MoneyBudgetScopeType.all,
      ),
    );
  }

  Future<MoneyBudgetEntity> createCategoryBudget(MoneyCategoryEntity category) {
    return repository.createBudget(
      'user_1',
      MoneyBudgetDraft(
        name: '分类预算',
        amountMinor: 800000,
        scopeType: MoneyBudgetScopeType.category,
        categoryId: category.id,
      ),
    );
  }

  Future<MoneyTransactionEntity> addExpense(
    MoneyCategoryEntity category,
    int amountMinor, {
    List<String> tags = const <String>[],
  }) {
    return repository.createTransaction(
      'user_1',
      MoneyTransactionDraft(
        type: MoneyTransactionType.expense,
        transactionAt: DateTime.now().toUtc(),
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

  test('creates tag-scoped budget with tag stored', () async {
    final budget = await createTagBudget();

    expect(budget.scopeType, MoneyBudgetScopeType.tag);
    expect(budget.tag, '南京旅游');
    expect(budget.categoryId, isNull);
    expect(budget.accountId, isNull);
  });

  test('strict tag matching counts only exact tagged transactions', () async {
    final budget = await createTagBudget();
    await addExpense(diningCategory, 20000, tags: const ['南京旅游']);
    await addExpense(diningCategory, 5000, tags: const ['南京']);
    await addExpense(diningCategory, 3000, tags: const ['南京旅游day1']);
    await addExpense(transportCategory, 1000);

    final refreshed = await refreshBudget(budget.id);
    expect(refreshed.usedAmountMinor, 20000);
  });

  test('tag budget counts across categories additively', () async {
    final tagBudget = await createTagBudget();
    final allBudget = await createAllBudget();
    final diningBudget = await createCategoryBudget(diningCategory);
    final transportBudget = await createCategoryBudget(transportCategory);

    await addExpense(diningCategory, 15000, tags: const ['南京旅游']);
    await addExpense(transportCategory, 25000, tags: const ['南京旅游']);

    final refreshedTag = await refreshBudget(tagBudget.id);
    expect(refreshedTag.usedAmountMinor, 40000);

    final refreshedAll = await refreshBudget(allBudget.id);
    expect(refreshedAll.usedAmountMinor, 40000);

    final refreshedDining = await refreshBudget(diningBudget.id);
    expect(refreshedDining.usedAmountMinor, 15000);

    final refreshedTransport = await refreshBudget(transportBudget.id);
    expect(refreshedTransport.usedAmountMinor, 25000);
  });

  test('updating transaction tag moves amount between tag budgets', () async {
    final nanjingBudget = await createTagBudget();
    final yunnanBudget = await createTagBudget(tag: '云南旅游');
    final transaction = await addExpense(
      diningCategory,
      12000,
      tags: const ['南京旅游'],
    );

    await repository.updateTransaction(
      'user_1',
      MoneyTransactionUpdate(
        id: transaction.id,
        type: MoneyTransactionType.expense,
        transactionAt: transaction.transactionAt,
        amountMinor: transaction.amountMinor,
        currencyCode: transaction.currencyCode,
        notes: transaction.notes,
        merchant: transaction.merchant,
        location: transaction.location,
        accountId: transaction.accountId,
        categoryId: transaction.categoryId,
        subCategoryId: transaction.subCategoryId,
        paymentMethod: transaction.paymentMethod,
        tags: const ['云南旅游'],
      ),
    );

    final refreshedNanjing = await refreshBudget(nanjingBudget.id);
    expect(refreshedNanjing.usedAmountMinor, 0);

    final refreshedYunnan = await refreshBudget(yunnanBudget.id);
    expect(refreshedYunnan.usedAmountMinor, 12000);
  });

  test('clearing tag removes amount from tag budget', () async {
    final budget = await createTagBudget();
    final transaction = await addExpense(
      diningCategory,
      8000,
      tags: const ['南京旅游'],
    );

    await repository.updateTransaction(
      'user_1',
      MoneyTransactionUpdate(
        id: transaction.id,
        type: MoneyTransactionType.expense,
        transactionAt: transaction.transactionAt,
        amountMinor: transaction.amountMinor,
        currencyCode: transaction.currencyCode,
        notes: transaction.notes,
        merchant: transaction.merchant,
        location: transaction.location,
        accountId: transaction.accountId,
        categoryId: transaction.categoryId,
        subCategoryId: transaction.subCategoryId,
        paymentMethod: transaction.paymentMethod,
        tags: const <String>[],
      ),
    );

    final refreshed = await refreshBudget(budget.id);
    expect(refreshed.usedAmountMinor, 0);
  });

  test('deleting tagged transaction removes amount from tag budget', () async {
    final budget = await createTagBudget();
    final transaction = await addExpense(
      diningCategory,
      6000,
      tags: const ['南京旅游'],
    );

    await repository.deleteTransaction('user_1', transaction.id);

    final refreshed = await refreshBudget(budget.id);
    expect(refreshed.usedAmountMinor, 0);
  });

  test('rejects tag budget combined with category', () async {
    await expectLater(
      repository.createBudget(
        'user_1',
        MoneyBudgetDraft(
          name: '非法预算',
          amountMinor: 10000,
          scopeType: MoneyBudgetScopeType.tag,
          tag: '南京旅游',
          categoryId: diningCategory.id,
        ),
      ),
      throwsA(
        isA<MoneyRepositoryException>().having(
          (error) => error.code,
          'code',
          MoneyRepositoryErrorCode.invalidBudgetScope,
        ),
      ),
    );
  });

  test('tag candidates merge transaction tags and budget tags', () async {
    await createTagBudget();
    await addExpense(diningCategory, 1000, tags: const ['出差']);
    await addExpense(transportCategory, 2000, tags: const ['出差']);

    final candidates = await repository
        .watchTagCandidatesForUser('user_1')
        .first;

    expect(candidates, containsAll(<String>['出差', '南京旅游']));
  });
}
