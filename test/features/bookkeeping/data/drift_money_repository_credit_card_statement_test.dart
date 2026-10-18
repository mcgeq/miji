import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/seed/database_seed_runner.dart';
import 'package:miji/core/sync/delta_sync/sync_change_logger.dart';
import 'package:miji/core/sync/delta_sync/sync_identity_store.dart';
import 'package:miji/features/bookkeeping/data/drift_money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_credit_card_bill_view.dart';
import 'package:miji/features/bookkeeping/domain/money_credit_card_statement_entity.dart';
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
    await database
        .into(database.moneyCategories)
        .insert(
          MoneyCategoriesCompanion.insert(
            id: 'system_transfer',
            userId: const Value<String?>(null),
            name: '转账',
            kind: MoneyCategoryKind.expense.storageValue,
            isSystem: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  });

  tearDown(() async {
    await database.close();
  });

  test('derives current statement from custom credit card cycle', () async {
    final account = await _createCreditCard(repository);
    final category = await repository.createCategory(
      'user_1',
      const MoneyCategoryDraft(name: '餐饮', kind: MoneyCategoryKind.expense),
    );

    await _createExpense(
      repository,
      account.id,
      category.id,
      9000,
      DateTime(2026, 6, 15),
      '上期',
    );
    final first = await _createExpense(
      repository,
      account.id,
      category.id,
      12000,
      DateTime(2026, 6, 16),
      '本期第一天',
    );
    final last = await _createExpense(
      repository,
      account.id,
      category.id,
      34000,
      DateTime(2026, 7, 15, 23, 59),
      '本期最后一天',
    );
    await _createExpense(
      repository,
      account.id,
      category.id,
      50000,
      DateTime(2026, 7, 16),
      '下期',
    );

    final statement = await repository.getCreditCardStatementForAccount(
      'user_1',
      account.id,
      asOf: DateTime.utc(2026, 7, 20),
    );

    expect(statement, isNotNull);
    expect(statement!.periodStart, DateTime(2026, 6, 16));
    expect(statement.periodEndExclusive, DateTime(2026, 7, 16));
    expect(statement.repaymentDate, DateTime(2026, 8, 10));
    expect(statement.purchaseAmountMinor, 46000);
    expect(statement.amountDueMinor, 46000);
    expect(statement.transactions.map((item) => item.id), [last.id, first.id]);
  });

  test(
    'repayment lowers remaining due without becoming income or expense',
    () async {
      final creditCard = await _createCreditCard(repository);
      final bank = await repository.createAccount(
        'user_1',
        const MoneyAccountDraft(
          name: '储蓄卡',
          type: MoneyAccountType.bank,
          initialBalanceMinor: 500000,
        ),
      );
      final category = await repository.createCategory(
        'user_1',
        const MoneyCategoryDraft(name: '购物', kind: MoneyCategoryKind.expense),
      );

      await _createExpense(
        repository,
        creditCard.id,
        category.id,
        100000,
        DateTime(2026, 7, 1),
        '显示器',
      );
      await repository.createTransfer(
        'user_1',
        MoneyTransferDraft(
          transactionAt: DateTime(2026, 7, 5),
          amountMinor: 40000,
          currencyCode: 'CNY',
          description: '信用卡还款',
          fromAccountId: bank.id,
          toAccountId: creditCard.id,
        ),
      );

      final statement = await repository.getCreditCardStatementForAccount(
        'user_1',
        creditCard.id,
        asOf: DateTime.utc(2026, 7, 20),
      );

      expect(statement, isNotNull);
      expect(statement!.purchaseAmountMinor, 100000);
      expect(statement.repaymentAmountMinor, 40000);
      expect(statement.amountDueMinor, 60000);
      expect(
        statement.transactions.where(
          (item) => item.type == MoneyTransactionType.transfer,
        ),
        isEmpty,
      );
    },
  );

  test(
    'current bill falls back to account debt when issued-period rows do not explain debt',
    () async {
      final account = await _createCreditCard(repository);
      final category = await repository.createCategory(
        'user_1',
        const MoneyCategoryDraft(name: '购物', kind: MoneyCategoryKind.expense),
      );

      await _createExpense(
        repository,
        account.id,
        category.id,
        120000,
        DateTime(2026, 5, 10),
        '历史欠款',
      );

      final bill = await repository.getCurrentCreditCardBillViewForAccount(
        'user_1',
        account.id,
        asOf: DateTime.utc(2026, 7, 20),
      );

      expect(bill, isNotNull);
      expect(bill!.source, MoneyCreditCardBillViewSource.accountDebt);
      expect(bill.amountDueMinor, 120000);
      expect(bill.state, isNot(MoneyCreditCardStatementState.open));
    },
  );

  test(
    'current bill prefers issued unpaid statement over account debt fallback',
    () async {
      final account = await _createCreditCard(repository);
      final category = await repository.createCategory(
        'user_1',
        const MoneyCategoryDraft(name: '餐饮', kind: MoneyCategoryKind.expense),
      );

      await _createExpense(
        repository,
        account.id,
        category.id,
        46000,
        DateTime(2026, 7, 10),
        '本期消费',
      );

      final bill = await repository.getCurrentCreditCardBillViewForAccount(
        'user_1',
        account.id,
        asOf: DateTime.utc(2026, 7, 20),
      );

      expect(bill, isNotNull);
      expect(bill!.source, MoneyCreditCardBillViewSource.issuedStatement);
      expect(bill.amountDueMinor, 46000);
    },
  );

  test(
    'current bill moves to next unbilled cycle after issued statement is repaid',
    () async {
      final creditCard = await _createCreditCard(
        repository,
        statementDay: 16,
        repaymentDay: 4,
        budgetCycleStartDay: 16,
      );
      final bank = await repository.createAccount(
        'user_1',
        const MoneyAccountDraft(
          name: '储蓄卡',
          type: MoneyAccountType.bank,
          initialBalanceMinor: 500000,
        ),
      );
      final category = await repository.createCategory(
        'user_1',
        const MoneyCategoryDraft(name: '购物', kind: MoneyCategoryKind.expense),
      );

      await _createExpense(
        repository,
        creditCard.id,
        category.id,
        100000,
        DateTime(2026, 6, 20),
        '上期账单消费',
      );
      await repository.createTransfer(
        'user_1',
        MoneyTransferDraft(
          transactionAt: DateTime(2026, 8, 4),
          amountMinor: 100000,
          currencyCode: 'CNY',
          description: '信用卡还款',
          fromAccountId: bank.id,
          toAccountId: creditCard.id,
        ),
      );
      await _createExpense(
        repository,
        creditCard.id,
        category.id,
        32000,
        DateTime(2026, 7, 20),
        '下一期未出账消费',
      );

      final bill = await repository.getCurrentCreditCardBillViewForAccount(
        'user_1',
        creditCard.id,
        asOf: DateTime.utc(2026, 8, 5),
      );

      expect(bill, isNotNull);
      expect(bill!.source, MoneyCreditCardBillViewSource.unbilled);
      expect(bill.periodStart, DateTime(2026, 7, 16));
      expect(bill.periodEndExclusive, DateTime(2026, 8, 16));
      expect(bill.repaymentDate, DateTime(2026, 9, 4));
      expect(bill.amountDueMinor, 32000);
      expect(bill.state, MoneyCreditCardStatementState.open);
    },
  );
}

Future<MoneyAccountEntity> _createCreditCard(
  DriftMoneyRepository repository, {
  int statementDay = 17,
  int repaymentDay = 10,
  int budgetCycleStartDay = 16,
}) {
  return repository.createAccount(
    'user_1',
    MoneyAccountDraft(
      name: '招行信用卡',
      type: MoneyAccountType.creditCard,
      initialBalanceMinor: 2000000,
      statementDay: statementDay,
      repaymentDay: repaymentDay,
      budgetCycleStartDay: budgetCycleStartDay,
    ),
  );
}

Future<MoneyTransactionEntity> _createExpense(
  DriftMoneyRepository repository,
  String accountId,
  String categoryId,
  int amountMinor,
  DateTime transactionAt,
  String description,
) {
  return repository.createTransaction(
    'user_1',
    MoneyTransactionDraft(
      type: MoneyTransactionType.expense,
      transactionAt: transactionAt,
      amountMinor: amountMinor,
      currencyCode: 'CNY',
      description: description,
      accountId: accountId,
      categoryId: categoryId,
      paymentMethod: MoneyPaymentMethod.creditCard,
    ),
  );
}
