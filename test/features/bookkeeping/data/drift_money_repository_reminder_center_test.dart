import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/seed/database_seed_runner.dart';
import 'package:miji/core/sync/delta_sync/sync_change_logger.dart';
import 'package:miji/core/sync/delta_sync/sync_identity_store.dart';
import 'package:miji/features/bookkeeping/data/drift_money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_bill_reminder_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_installment_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_reminder_center_entity.dart';

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
        now: () => DateTime.utc(2026, 7, 19, 8),
      ),
      now: () => DateTime.utc(2026, 7, 19, 8),
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

  test('lists bill reminders and moves completed items to history', () async {
    final reminder = await repository.createBillReminder(
      'user_1',
      MoneyBillReminderDraft(
        name: '信用卡还款',
        amountMinor: 120000,
        dueDate: DateTime.utc(2026, 7, 22),
        ledgerId: 'default_ledger_user_1',
        sourceType: MoneyBillReminderSourceType.creditRepayment,
        remindBeforeDays: 3,
      ),
    );

    final pending = await repository.getPendingReminderCenterItems(
      'user_1',
      ledgerId: 'default_ledger_user_1',
      today: DateTime.utc(2026, 7, 19),
    );

    expect(pending, hasLength(1));
    expect(
      pending.single.sourceType,
      MoneyReminderCenterSourceType.creditCardBill,
    );
    expect(pending.single.sourceId, reminder.id);
    expect(pending.single.actionType, MoneyReminderCenterActionType.repay);
    expect(
      pending.single.priority(today: DateTime.utc(2026, 7, 19)),
      MoneyReminderCenterPriority.dueWithinThreeDays,
    );

    await repository.setReminderCenterState(
      'user_1',
      pending.single,
      MoneyReminderCenterState.completed,
    );

    expect(
      await repository.getPendingReminderCenterItems(
        'user_1',
        ledgerId: 'default_ledger_user_1',
        today: DateTime.utc(2026, 7, 19),
      ),
      isEmpty,
    );

    final history = await repository.getReminderCenterHistory(
      'user_1',
      ledgerId: 'default_ledger_user_1',
    );
    expect(history, hasLength(1));
    expect(history.single.state, MoneyReminderCenterState.completed);
    expect(history.single.sourceId, reminder.id);
    expect(history.single.accountId, reminder.accountId);
  });

  test(
    'adds budget alerts and pending installments to priority list',
    () async {
      final account = await repository.createAccount(
        'user_1',
        const MoneyAccountDraft(
          name: '日常账户',
          type: MoneyAccountType.bank,
          initialBalanceMinor: 1000000,
        ),
      );
      final creditAccount = await repository.createAccount(
        'user_1',
        const MoneyAccountDraft(
          name: '信用卡',
          type: MoneyAccountType.creditCard,
          initialBalanceMinor: 500000,
        ),
      );
      final category = await repository.createCategory(
        'user_1',
        const MoneyCategoryDraft(name: '餐饮', kind: MoneyCategoryKind.expense),
      );
      final budget = await repository.createBudget(
        'user_1',
        const MoneyBudgetDraft(
          name: '餐饮预算',
          ledgerId: 'default_ledger_user_1',
          amountMinor: 10000,
          alertEnabled: true,
          alertThresholdPercent: 80,
        ),
      );
      await repository.createTransaction(
        'user_1',
        MoneyTransactionDraft(
          ledgerId: 'default_ledger_user_1',
          accountId: account.id,
          categoryId: category.id,
          type: MoneyTransactionType.expense,
          amountMinor: 12000,
          currencyCode: 'CNY',
          description: '午餐',
          paymentMethod: MoneyPaymentMethod.bankCard,
          transactionAt: DateTime.utc(2026, 7, 18),
        ),
      );
      final installment = await repository.createInstallmentPlan(
        'user_1',
        MoneyInstallmentPlanDraft(
          ledgerId: 'default_ledger_user_1',
          accountId: creditAccount.id,
          name: '手机分期',
          categoryId: category.id,
          totalPrincipalMinor: 30000,
          totalInterestMinor: 0,
          totalPeriods: 3,
          firstDueDate: DateTime.utc(2026, 7, 18),
        ),
      );

      final pending = await repository.getPendingReminderCenterItems(
        'user_1',
        ledgerId: 'default_ledger_user_1',
        today: DateTime.utc(2026, 7, 19),
      );

      expect(
        pending.map((item) => item.sourceType),
        contains(MoneyReminderCenterSourceType.budget),
      );
      expect(
        pending.map((item) => item.sourceType),
        contains(MoneyReminderCenterSourceType.installment),
      );
      expect(
        pending.first.sourceType,
        MoneyReminderCenterSourceType.installment,
      );
      expect(pending.first.sourceId, startsWith(installment.id));

      final budgetItem = pending.singleWhere(
        (item) => item.sourceType == MoneyReminderCenterSourceType.budget,
      );
      expect(budgetItem.sourceId, budget.id);
      expect(budgetItem.actionType, MoneyReminderCenterActionType.viewBudget);
      expect(budgetItem.isBudgetExceeded, isTrue);
    },
  );

  test(
    'does not create auto credit repayment reminder before statement is issued',
    () async {
      final creditCard = await repository.createAccount(
        'user_1',
        const MoneyAccountDraft(
          name: '信用卡',
          type: MoneyAccountType.creditCard,
          initialBalanceMinor: 2000000,
          statementDay: 16,
          budgetCycleStartDay: 16,
          repaymentDay: 4,
        ),
      );
      final category = await repository.createCategory(
        'user_1',
        const MoneyCategoryDraft(name: '购物', kind: MoneyCategoryKind.expense),
      );

      await repository.createTransaction(
        'user_1',
        MoneyTransactionDraft(
          accountId: creditCard.id,
          categoryId: category.id,
          type: MoneyTransactionType.expense,
          amountMinor: 32000,
          currencyCode: 'CNY',
          description: '未出账消费',
          paymentMethod: MoneyPaymentMethod.creditCard,
          transactionAt: DateTime.utc(2026, 7, 18),
        ),
      );

      final reminders = await repository
          .watchBillRemindersForUser('user_1')
          .first;

      expect(
        reminders.where(
          (reminder) =>
              reminder.sourceType ==
              MoneyBillReminderSourceType.creditRepayment,
        ),
        isEmpty,
      );
      expect(
        await repository.getPendingReminderCenterItems(
          'user_1',
          today: DateTime.utc(2026, 7, 19),
        ),
        isEmpty,
      );
    },
  );

  test(
    'creates auto credit repayment reminder only for issued unpaid statement',
    () async {
      final creditCard = await repository.createAccount(
        'user_1',
        const MoneyAccountDraft(
          name: '信用卡',
          type: MoneyAccountType.creditCard,
          initialBalanceMinor: 2000000,
          statementDay: 16,
          budgetCycleStartDay: 16,
          repaymentDay: 4,
        ),
      );
      final category = await repository.createCategory(
        'user_1',
        const MoneyCategoryDraft(name: '购物', kind: MoneyCategoryKind.expense),
      );

      await repository.createTransaction(
        'user_1',
        MoneyTransactionDraft(
          accountId: creditCard.id,
          categoryId: category.id,
          type: MoneyTransactionType.expense,
          amountMinor: 100000,
          currencyCode: 'CNY',
          description: '已出账消费',
          paymentMethod: MoneyPaymentMethod.creditCard,
          transactionAt: DateTime.utc(2026, 6, 20),
        ),
      );

      final reminders = await repository
          .watchBillRemindersForUser('user_1')
          .first;
      final reminder = reminders.singleWhere(
        (item) =>
            item.sourceType == MoneyBillReminderSourceType.creditRepayment,
      );
      expect(reminder.amountMinor, 100000);
      expect(reminder.dueDate, DateTime(2026, 8, 4));
      expect(reminder.remindBeforeDays, 1);

      expect(
        await repository.getPendingReminderCenterItems(
          'user_1',
          today: DateTime.utc(2026, 8, 2),
        ),
        isEmpty,
      );

      final pending = await repository.getPendingReminderCenterItems(
        'user_1',
        today: DateTime.utc(2026, 8, 3),
      );

      expect(pending, hasLength(1));
      expect(
        pending.single.sourceType,
        MoneyReminderCenterSourceType.creditCardBill,
      );
      expect(pending.single.amountMinor, 100000);
      expect(pending.single.dueDate, DateTime(2026, 8, 4));
    },
  );
}
