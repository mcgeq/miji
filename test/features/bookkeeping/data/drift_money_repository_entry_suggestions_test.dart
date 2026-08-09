import 'package:drift/drift.dart';
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
  late MoneyAccountEntity account;
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

  MoneyTransactionDraft expenseDraft({
    required String description,
    required DateTime transactionAt,
    String? merchant,
    String? customPaymentMethodName,
    MoneyPaymentMethod paymentMethod = MoneyPaymentMethod.onlinePayment,
  }) {
    return MoneyTransactionDraft(
      type: MoneyTransactionType.expense,
      transactionAt: transactionAt,
      amountMinor: 1200,
      currencyCode: 'CNY',
      description: description,
      merchant: merchant,
      accountId: account.id,
      categoryId: expenseCategory.id,
      paymentMethod: paymentMethod,
      customPaymentMethodName: customPaymentMethodName,
    );
  }

  test('returns distinct merchants ordered by recency', () async {
    await repository.createTransaction(
      'user_1',
      expenseDraft(
        description: '旧',
        transactionAt: DateTime.utc(2026, 1, 3),
        merchant: '盒马',
      ),
    );
    await repository.createTransaction(
      'user_1',
      expenseDraft(
        description: '新',
        transactionAt: DateTime.utc(2026, 1, 5),
        merchant: '京东',
      ),
    );
    await repository.createTransaction(
      'user_1',
      expenseDraft(
        description: '重复商户',
        transactionAt: DateTime.utc(2026, 1, 6),
        merchant: '盒马',
      ),
    );
    // 空商户不应进入建议
    await repository.createTransaction(
      'user_1',
      expenseDraft(description: '无商户', transactionAt: DateTime.utc(2026, 1, 7)),
    );

    final suggestions = await repository.getEntrySuggestionsForUser('user_1');

    expect(suggestions.merchants, ['盒马', '京东']);
    expect(suggestions.customPaymentMethods, isEmpty);
  });

  test('returns custom payment method names ordered by recency', () async {
    await repository.createTransaction(
      'user_1',
      expenseDraft(
        description: '旧',
        transactionAt: DateTime.utc(2026, 1, 3),
        merchant: '盒马',
        paymentMethod: MoneyPaymentMethod.other,
        customPaymentMethodName: '美团月付',
      ),
    );
    await repository.createTransaction(
      'user_1',
      expenseDraft(
        description: '新',
        transactionAt: DateTime.utc(2026, 1, 5),
        paymentMethod: MoneyPaymentMethod.other,
        customPaymentMethodName: '京东支付',
      ),
    );

    final suggestions = await repository.getEntrySuggestionsForUser('user_1');

    expect(suggestions.customPaymentMethods, ['京东支付', '美团月付']);
  });

  test('excludes deleted transactions and applies limits', () async {
    for (var i = 0; i < 5; i++) {
      await repository.createTransaction(
        'user_1',
        expenseDraft(
          description: '商户$i',
          transactionAt: DateTime.utc(2026, 1, 3 + i),
          merchant: '商户$i',
        ),
      );
    }
    final deletedTx = await repository.createTransaction(
      'user_1',
      expenseDraft(
        description: '已删',
        transactionAt: DateTime.utc(2026, 1, 20),
        merchant: '已删除商户',
      ),
    );
    await repository.deleteTransaction('user_1', deletedTx.id);

    final limited = await repository.getEntrySuggestionsForUser(
      'user_1',
      merchantLimit: 3,
    );
    expect(limited.merchants.length, 3);
    expect(limited.merchants, isNot(contains('已删除商户')));

    final all = await repository.getEntrySuggestionsForUser('user_1');
    expect(all.merchants, isNot(contains('已删除商户')));
  });
}
