import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/seed/database_seed_runner.dart';
import 'package:miji/features/bookkeeping/data/drift_money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_repository.dart';
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

  Future<int> currentBalance() async {
    final accounts = await repository
        .watchVisibleAccountsForUser('user_1')
        .first;
    return accounts.singleWhere((item) => item.id == account.id).balanceMinor;
  }

  Future<MoneyTransactionEntity> createExpense({
    required MoneyTransactionStatus status,
    int amountMinor = 1200,
  }) {
    return repository.createTransaction(
      'user_1',
      MoneyTransactionDraft(
        type: MoneyTransactionType.expense,
        transactionAt: DateTime.utc(2026, 1, 5),
        amountMinor: amountMinor,
        currencyCode: 'CNY',
        description: '午餐',
        accountId: account.id,
        categoryId: expenseCategory.id,
        paymentMethod: MoneyPaymentMethod.alipay,
        status: status,
      ),
    );
  }

  test('待处理流水不占用账户余额', () async {
    await createExpense(status: MoneyTransactionStatus.pending);
    expect(await currentBalance(), 100000000);
  });

  test('已完成流水立即扣减余额', () async {
    await createExpense(status: MoneyTransactionStatus.completed);
    expect(await currentBalance(), 99998800);
  });

  test('待处理确认入账后才扣减余额', () async {
    final transaction = await createExpense(
      status: MoneyTransactionStatus.pending,
    );
    expect(await currentBalance(), 100000000);

    await repository.setTransactionStatus(
      'user_1',
      transaction.id,
      MoneyTransactionStatus.completed,
    );
    expect(await currentBalance(), 99998800);
  });

  test('已完成作废后回滚余额', () async {
    final transaction = await createExpense(
      status: MoneyTransactionStatus.completed,
    );
    expect(await currentBalance(), 99998800);

    await repository.setTransactionStatus(
      'user_1',
      transaction.id,
      MoneyTransactionStatus.voided,
    );
    expect(await currentBalance(), 100000000);
  });

  test('待处理可直接作废且不影响余额', () async {
    final transaction = await createExpense(
      status: MoneyTransactionStatus.pending,
    );
    await repository.setTransactionStatus(
      'user_1',
      transaction.id,
      MoneyTransactionStatus.voided,
    );
    expect(await currentBalance(), 100000000);
  });

  test('删除待处理流水不改变余额', () async {
    final transaction = await createExpense(
      status: MoneyTransactionStatus.pending,
    );
    await repository.deleteTransaction('user_1', transaction.id);
    expect(await currentBalance(), 100000000);
  });

  test('编辑待处理流水不改变余额', () async {
    final transaction = await createExpense(
      status: MoneyTransactionStatus.pending,
    );
    await repository.updateTransaction(
      'user_1',
      MoneyTransactionUpdate(
        id: transaction.id,
        type: MoneyTransactionType.expense,
        transactionAt: DateTime.utc(2026, 1, 6),
        amountMinor: 5000,
        currencyCode: 'CNY',
        notes: null,
        accountId: account.id,
        categoryId: expenseCategory.id,
        paymentMethod: MoneyPaymentMethod.alipay,
      ),
    );
    expect(await currentBalance(), 100000000);
  });

  test('已作废流水不允许再次变更状态', () async {
    final transaction = await createExpense(
      status: MoneyTransactionStatus.completed,
    );
    await repository.setTransactionStatus(
      'user_1',
      transaction.id,
      MoneyTransactionStatus.voided,
    );
    expect(
      () => repository.setTransactionStatus(
        'user_1',
        transaction.id,
        MoneyTransactionStatus.completed,
      ),
      throwsA(isA<MoneyRepositoryException>()),
    );
  });
}
