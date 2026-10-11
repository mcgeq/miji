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

/// 账户区间收支：余额对账反推「期初余额」的口径保证。
void main() {
  late AppDatabase database;
  late DriftMoneyRepository repository;
  late MoneyAccountEntity account;
  late MoneyCategoryEntity expenseCategory;
  late MoneyCategoryEntity incomeCategory;

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

  Future<void> addExpense(
    int amountMinor, {
    required DateTime at,
    MoneyTransactionStatus status = MoneyTransactionStatus.completed,
  }) {
    return repository.createTransaction(
      'user_1',
      MoneyTransactionDraft(
        type: MoneyTransactionType.expense,
        transactionAt: at,
        amountMinor: amountMinor,
        currencyCode: 'CNY',
        description: '测试消费',
        accountId: account.id,
        categoryId: expenseCategory.id,
        paymentMethod: MoneyPaymentMethod.bankCard,
        ledgerId: 'default_ledger_user_1',
        actualPayerAccount: 'default',
        status: status,
      ),
    );
  }

  Future<void> addIncome(int amountMinor, {required DateTime at}) {
    return repository.createTransaction(
      'user_1',
      MoneyTransactionDraft(
        type: MoneyTransactionType.income,
        transactionAt: at,
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

  test('only sums flows inside the half-open range', () async {
    await addExpense(1000, at: DateTime.utc(2026, 3, 1, 10));
    await addExpense(2000, at: DateTime.utc(2026, 3, 31, 23));
    await addIncome(50000, at: DateTime.utc(2026, 3, 15, 10));
    // 区间外：2 月末、4 月初都不算。
    await addExpense(9999, at: DateTime.utc(2026, 2, 28, 10));
    await addExpense(8888, at: DateTime.utc(2026, 4, 1, 0));

    final flows = await repository.getAccountFlowsForPeriod(
      'user_1',
      account.id,
      from: DateTime.utc(2026, 3, 1),
      to: DateTime.utc(2026, 4, 1),
    );

    expect(flows.incomeMinor, 50000);
    expect(flows.expenseMinor, 3000);
    expect(flows.netMinor, 47000);
  });

  test('excludes transfers and non-completed transactions', () async {
    await addExpense(1000, at: DateTime.utc(2026, 3, 5));
    await addExpense(
      4000,
      at: DateTime.utc(2026, 3, 6),
      status: MoneyTransactionStatus.pending,
    );
    final cash = await repository.createAccount(
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
        transactionAt: DateTime.utc(2026, 3, 7),
        amountMinor: 30000,
        currencyCode: 'CNY',
        description: '转账',
        fromAccountId: account.id,
        toAccountId: cash.id,
        ledgerId: 'default_ledger_user_1',
      ),
    );

    final flows = await repository.getAccountFlowsForPeriod(
      'user_1',
      account.id,
      from: DateTime.utc(2026, 3, 1),
      to: DateTime.utc(2026, 4, 1),
    );

    expect(flows.incomeMinor, 0);
    expect(flows.expenseMinor, 1000);
  });

  test('returns an empty result outside any activity', () async {
    await addExpense(1000, at: DateTime.utc(2026, 3, 5));

    final flows = await repository.getAccountFlowsForPeriod(
      'user_1',
      account.id,
      from: DateTime.utc(2027, 1, 1),
      to: DateTime.utc(2027, 2, 1),
    );

    expect(flows.isEmpty, isTrue);
  });
}
