import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/seed/database_seed_runner.dart';
import 'package:miji/core/sync/delta_sync/sync_change_logger.dart';
import 'package:miji/core/sync/delta_sync/sync_identity_store.dart';
import 'package:miji/features/bookkeeping/data/drift_money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_spending_analysis_entity.dart';
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
  });

  tearDown(() async {
    await database.close();
  });

  test('aggregates category, subcategory, and merchant anomalies', () async {
    final account = await repository.createAccount(
      'user_1',
      const MoneyAccountDraft(
        name: '日常账户',
        type: MoneyAccountType.bank,
        initialBalanceMinor: 1000000,
      ),
    );
    final category = await repository.createCategory(
      'user_1',
      const MoneyCategoryDraft(name: '餐饮', kind: MoneyCategoryKind.expense),
    );
    final subCategory = await repository.createSubCategory(
      'user_1',
      MoneySubCategoryDraft(
        categoryId: category.id,
        name: '咖啡',
        kind: MoneyCategoryKind.expense,
      ),
    );

    Future<void> addExpense(
      DateTime date,
      int amountMinor, {
      String merchant = '咖啡店',
      String? subCategoryId,
    }) {
      return repository.createTransaction(
        'user_1',
        MoneyTransactionDraft(
          type: MoneyTransactionType.expense,
          transactionAt: date,
          amountMinor: amountMinor,
          currencyCode: 'CNY',
          description: merchant,
          merchant: merchant,
          accountId: account.id,
          categoryId: category.id,
          subCategoryId: subCategoryId,
          paymentMethod: MoneyPaymentMethod.bankCard,
          ledgerId: 'default_ledger_user_1',
        ),
      );
    }

    await addExpense(
      DateTime(2026, 4, 10),
      4000,
      subCategoryId: subCategory.id,
    );
    await addExpense(
      DateTime(2026, 5, 10),
      5000,
      subCategoryId: subCategory.id,
    );
    await addExpense(
      DateTime(2026, 6, 10),
      6000,
      subCategoryId: subCategory.id,
    );
    await addExpense(
      DateTime(2026, 7, 10),
      10000,
      subCategoryId: subCategory.id,
    );

    final analysis = await repository.getSpendingAnalysisForUser(
      'user_1',
      MoneySpendingAnalysisQuery(
        currentMonth: DateTime(2026, 7),
        ledgerId: 'default_ledger_user_1',
      ),
    );

    expect(analysis.currencyCode, 'CNY');
    expect(
      analysis.anomalies.map((item) => item.dimension),
      containsAll([
        MoneySpendingAnalysisDimension.category,
        MoneySpendingAnalysisDimension.subCategory,
        MoneySpendingAnalysisDimension.merchant,
      ]),
    );
    expect(
      analysis.anomalies
          .where(
            (item) => item.dimension == MoneySpendingAnalysisDimension.category,
          )
          .single
          .name,
      '餐饮',
    );
    expect(
      analysis.anomalies
          .where(
            (item) =>
                item.dimension == MoneySpendingAnalysisDimension.subCategory,
          )
          .single
          .name,
      '餐饮 / 咖啡',
    );
  });
}
