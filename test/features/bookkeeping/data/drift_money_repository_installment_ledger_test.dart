import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/seed/database_seed_runner.dart';
import 'package:miji/features/bookkeeping/data/drift_money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_installment_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';

void main() {
  late AppDatabase database;
  late DriftMoneyRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftMoneyRepository(
      database: database,
      seedRunner: DatabaseSeedRunner(database: database),
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
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'posts family ledger installment transactions into personal and family ledgers',
    () async {
      await repository.ensureReadyForUser('user_1');
      final personalLedger = await repository.getDefaultLedgerForUser('user_1');
      final familyLedger = await repository.createLedger(
        'user_1',
        const MoneyLedgerDraft(name: '家庭账本'),
      );
      final otherLedger = await repository.createLedger(
        'user_1',
        const MoneyLedgerDraft(name: '另一个家庭'),
      );
      final account = await repository.createAccount(
        'user_1',
        const MoneyAccountDraft(
          name: '信用卡',
          type: MoneyAccountType.creditCard,
          initialBalanceMinor: 100000,
        ),
      );
      await repository.addAccountToLedger(
        'user_1',
        familyLedger.id,
        account.id,
      );

      final catalog = await repository
          .watchCategoryCatalogForUser('user_1', MoneyCategoryKind.expense)
          .first;
      final category = catalog.categories.first;
      final plan = await repository.createInstallmentPlan(
        'user_1',
        MoneyInstallmentPlanDraft(
          ledgerId: familyLedger.id,
          accountId: account.id,
          name: '手机分期',
          categoryId: category.id,
          totalPrincipalMinor: 12000,
          totalInterestMinor: 600,
          totalPeriods: 3,
          firstDueDate: DateTime(2026, 2, 10),
        ),
      );

      expect(plan.ledgerId, familyLedger.id);
      expect(
        (await repository
                .watchInstallmentPlansForUser(
                  'user_1',
                  ledgerId: familyLedger.id,
                )
                .first)
            .map((plan) => plan.id),
        contains(plan.id),
      );
      expect(
        (await repository
                .watchInstallmentPlansForUser(
                  'user_1',
                  ledgerId: otherLedger.id,
                )
                .first)
            .map((plan) => plan.id),
        isNot(contains(plan.id)),
      );

      final firstDetail =
          (await repository
                  .watchInstallmentDetailsForPlan('user_1', plan.id)
                  .first)
              .first;
      final transaction = await repository.postInstallmentDetail(
        'user_1',
        firstDetail.id,
      );

      final ledgers = await repository
          .watchLedgersForTransaction('user_1', transaction.id)
          .first;
      expect(ledgers.map((ledger) => ledger.id), contains(personalLedger.id));
      expect(ledgers.map((ledger) => ledger.id), contains(familyLedger.id));
    },
  );
}
