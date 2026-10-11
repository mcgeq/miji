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

void main() {
  late AppDatabase database;
  late DriftMoneyRepository repository;
  late MoneyAccountEntity bankAccount;
  late MoneyAccountEntity cashAccount;
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

    bankAccount = await repository.createAccount(
      'user_1',
      MoneyAccountDraft(
        name: '银行卡',
        type: MoneyAccountType.bank,
        initialBalanceMinor: 1000000,
      ),
    );
    cashAccount = await repository.createAccount(
      'user_1',
      MoneyAccountDraft(
        name: '现金',
        type: MoneyAccountType.cash,
        initialBalanceMinor: 1000000,
      ),
    );
    expenseCategory = await repository.createCategory(
      'user_1',
      MoneyCategoryDraft(name: '餐饮', kind: MoneyCategoryKind.expense),
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> addExpense(
    MoneyAccountEntity account,
    int amountMinor, {
    MoneyPaymentMethod method = MoneyPaymentMethod.bankCard,
    String? customPaymentMethodName,
  }) {
    return repository.createTransaction(
      'user_1',
      MoneyTransactionDraft(
        type: MoneyTransactionType.expense,
        transactionAt: DateTime.utc(2026, 7, 1, 10),
        amountMinor: amountMinor,
        currencyCode: 'CNY',
        description: '测试消费',
        accountId: account.id,
        categoryId: expenseCategory.id,
        paymentMethod: method,
        customPaymentMethodName: customPaymentMethodName,
        ledgerId: 'default_ledger_user_1',
        actualPayerAccount: 'default',
      ),
    );
  }

  test('filters transactions by account type', () async {
    await addExpense(bankAccount, 1000);
    await addExpense(bankAccount, 2000);
    await addExpense(cashAccount, 3000);

    final bankPage = await repository.listTransactions(
      'user_1',
      MoneyTransactionQuery(
        accountType: MoneyAccountType.bank,
        dateStart: DateTime(2026, 7, 1),
        dateEnd: DateTime(2026, 7, 31, 23, 59, 59),
      ),
    );
    expect(bankPage.total, 2);
    expect(bankPage.items.map((item) => item.amountMinor).toSet(), {
      1000,
      2000,
    });

    final cashPage = await repository.listTransactions(
      'user_1',
      MoneyTransactionQuery(
        accountType: MoneyAccountType.cash,
        dateStart: DateTime(2026, 7, 1),
        dateEnd: DateTime(2026, 7, 31, 23, 59, 59),
      ),
    );
    expect(cashPage.total, 1);
    expect(cashPage.items.single.amountMinor, 3000);
  });

  test('returns empty page when no account matches the type', () async {
    await addExpense(bankAccount, 1000);

    final creditPage = await repository.listTransactions(
      'user_1',
      MoneyTransactionQuery(
        accountType: MoneyAccountType.creditCard,
        dateStart: DateTime(2026, 7, 1),
        dateEnd: DateTime(2026, 7, 31, 23, 59, 59),
      ),
    );
    expect(creditPage.total, 0);
    expect(creditPage.items, isEmpty);
  });

  test('filters transactions by payment method and custom name', () async {
    await addExpense(bankAccount, 1000);
    await addExpense(
      bankAccount,
      2000,
      method: MoneyPaymentMethod.other,
      customPaymentMethodName: '京东支付',
    );
    await addExpense(
      cashAccount,
      3000,
      method: MoneyPaymentMethod.other,
      customPaymentMethodName: '美团支付',
    );

    final otherPage = await repository.listTransactions(
      'user_1',
      MoneyTransactionQuery(
        paymentMethod: MoneyPaymentMethod.other,
        dateStart: DateTime(2026, 7, 1),
        dateEnd: DateTime(2026, 7, 31, 23, 59, 59),
      ),
    );
    expect(otherPage.total, 2);

    final jdPage = await repository.listTransactions(
      'user_1',
      MoneyTransactionQuery(
        paymentMethod: MoneyPaymentMethod.other,
        customPaymentMethodName: '京东',
        dateStart: DateTime(2026, 7, 1),
        dateEnd: DateTime(2026, 7, 31, 23, 59, 59),
      ),
    );
    expect(jdPage.total, 1);
    expect(jdPage.items.single.amountMinor, 2000);
  });
}
