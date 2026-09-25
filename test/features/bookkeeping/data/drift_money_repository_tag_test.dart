import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/seed/database_seed_runner.dart';
import 'package:miji/features/bookkeeping/data/drift_money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';
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
    repository = DriftMoneyRepository(
      database: database,
      seedRunner: DatabaseSeedRunner(database: database),
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

  Future<MoneyTransactionEntity> seedTransactionWithTag(String tag) {
    return repository.createTransaction(
      'user_1',
      MoneyTransactionDraft(
        type: MoneyTransactionType.expense,
        transactionAt: DateTime.utc(2026, 1, 5),
        amountMinor: 1200,
        currencyCode: 'CNY',
        description: '旅游',
        accountId: account.id,
        categoryId: expenseCategory.id,
        paymentMethod: MoneyPaymentMethod.onlinePayment,
        tags: [tag],
      ),
    );
  }

  Future<MoneyTransactionEntity> loadTransaction(String id) async {
    final page = await repository.listTransactions(
      'user_1',
      const MoneyTransactionQuery(pageSize: 50),
    );
    return page.items.firstWhere((item) => item.id == id);
  }

  Future<MoneyBudgetEntity> seedBudgetWithTag(String tag) {
    return repository.createBudget(
      'user_1',
      MoneyBudgetDraft(name: '旅游预算', amountMinor: 500000, tag: tag),
    );
  }

  test('重命名标签会级联更新流水与预算引用', () async {
    final transaction = await seedTransactionWithTag('南京旅游');
    final budget = await seedBudgetWithTag('南京旅游');

    await repository.renameTag('user_1', '南京旅游', '云南旅游');

    final updatedTransaction = await loadTransaction(transaction.id);
    expect(updatedTransaction.tags, ['云南旅游']);

    final budgets = await repository.watchBudgetsForUser('user_1').first;
    final updatedBudget = budgets.singleWhere((b) => b.id == budget.id);
    expect(updatedBudget.tag, '云南旅游');

    final candidates = await repository
        .watchTagCandidatesForUser('user_1')
        .first;
    expect(candidates, contains('云南旅游'));
    expect(candidates, isNot(contains('南京旅游')));
  });

  test('删除标签会从流水与预算中移除引用', () async {
    final transaction = await seedTransactionWithTag('南京旅游');
    await seedBudgetWithTag('南京旅游');

    await repository.deleteTag('user_1', '南京旅游');

    final updatedTransaction = await loadTransaction(transaction.id);
    expect(updatedTransaction.tags, isEmpty);

    final budgets = await repository.watchBudgetsForUser('user_1').first;
    expect(budgets.where((b) => b.tag == '南京旅游'), isEmpty);

    final candidates = await repository
        .watchTagCandidatesForUser('user_1')
        .first;
    expect(candidates, isEmpty);
  });

  test('重命名到已存在标签时合并且不产生重复', () async {
    await repository.createTransaction(
      'user_1',
      MoneyTransactionDraft(
        type: MoneyTransactionType.expense,
        transactionAt: DateTime.utc(2026, 1, 6),
        amountMinor: 800,
        currencyCode: 'CNY',
        description: '旅游二',
        accountId: account.id,
        categoryId: expenseCategory.id,
        paymentMethod: MoneyPaymentMethod.onlinePayment,
        tags: ['南京旅游', '云南旅游'],
      ),
    );

    await repository.renameTag('user_1', '南京旅游', '云南旅游');

    final candidates = await repository
        .watchTagCandidatesForUser('user_1')
        .first;
    expect(candidates, ['云南旅游']);
  });
}
