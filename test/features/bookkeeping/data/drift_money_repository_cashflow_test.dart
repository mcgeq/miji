import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/seed/database_seed_runner.dart';
import 'package:miji/core/sync/delta_sync/sync_change_logger.dart';
import 'package:miji/core/sync/delta_sync/sync_identity_store.dart';
import 'package:miji/features/bookkeeping/data/drift_money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_auto_posting_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_commitment_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_installment_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';

/// 「未来现金流」原来是自己手写查分期 + 账单 + 模板的第三份实现，缺了
/// 「模板已被分期接管 → 只算分期那一份」的去重，也把收入模板算进「每月固定」。
/// 现在它和预算「已预留」、时薪「本月还能自由花」共用 `upcomingExpenseCommitments`。
void main() {
  late AppDatabase database;
  late DriftMoneyRepository repository;
  late MoneyAccountEntity account;
  late MoneyAccountEntity creditAccount;
  late MoneyCategoryEntity expenseCategory;
  late MoneyCategoryEntity incomeCategory;

  final clock = DateTime.utc(2026, 10, 18, 3, 4, 5);

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
        now: () => clock,
      ),
      now: () => clock,
    );

    await database
        .into(database.users)
        .insert(
          UsersCompanion.insert(
            id: 'user_1',
            username: 'user_1',
            email: 'user_1@example.com',
            displayName: '用户',
            createdAt: clock,
            updatedAt: clock,
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
            createdAt: clock,
            updatedAt: clock,
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
            createdAt: clock,
            updatedAt: clock,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await database
        .into(database.moneyLedgerMembers)
        .insert(
          MoneyLedgerMembersCompanion.insert(
            ledgerId: 'default_ledger_user_1',
            memberId: 'default_member_user_1',
            createdAt: clock,
          ),
          mode: InsertMode.insertOrIgnore,
        );

    account = await repository.createAccount(
      'user_1',
      const MoneyAccountDraft(
        name: '工资卡',
        type: MoneyAccountType.bank,
        initialBalanceMinor: 100000000,
      ),
    );
    // 分期计划只能挂在信用类账户上（见 _validateInstallmentDraft）。
    creditAccount = await repository.createAccount(
      'user_1',
      const MoneyAccountDraft(
        name: '信用卡',
        type: MoneyAccountType.creditCard,
        // 信用类账户的额度 = initialBalanceMinor（见 _resolveCreditBudgetState）。
        initialBalanceMinor: 5000000,
      ),
    );
    expenseCategory = await repository.createCategory(
      'user_1',
      const MoneyCategoryDraft(name: '居住', kind: MoneyCategoryKind.expense),
    );
    incomeCategory = await repository.createCategory(
      'user_1',
      const MoneyCategoryDraft(name: '工资', kind: MoneyCategoryKind.income),
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<MoneyAutoPostingTemplateEntity> template({
    required MoneyTransactionType type,
    required int amountMinor,
    required int dayOfMonth,
    String? categoryId,
    String name = '测试周期',
  }) {
    return repository.createAutoPostingTemplate(
      'user_1',
      MoneyAutoPostingTemplateDraft(
        name: name,
        type: type,
        amountMinor: amountMinor,
        currencyCode: 'CNY',
        description: '周期账单',
        accountId: account.id,
        categoryId:
            categoryId ??
            (type == MoneyTransactionType.expense
                ? expenseCategory.id
                : incomeCategory.id),
        paymentMethod: MoneyPaymentMethod.bankTransfer,
        ledgerId: 'default_ledger_user_1',
        timeOfDayMinutes: 9 * 60,
        frequency: MoneyAutoPostingFrequency.monthly,
        dayOfMonth: dayOfMonth,
        startsOn: DateTime(2026, 1, 1),
      ),
    );
  }

  test('房贷（支出模板）进现金流，工资（收入模板）不进「每月固定」', () async {
    await template(
      type: MoneyTransactionType.expense,
      amountMinor: 800000,
      dayOfMonth: 25,
      name: '房贷',
    );
    await template(
      type: MoneyTransactionType.income,
      amountMinor: 1200000,
      dayOfMonth: 10,
      name: '工资',
    );

    final summary = await repository.getUpcomingCashFlowForUser(
      'user_1',
      ledgerId: 'default_ledger_user_1',
    );

    // 10 月 18 日看：工资（10 日）已经过点；房贷在 90 天窗口里展开成
    // 10/25、11/25、12/25 三次执行。
    expect(summary.items, hasLength(3));
    expect(summary.items.map((item) => item.title).toSet(), {'房贷'});
    // 「每月固定」只数未来 30 天内的那一次，不重复数 11 月、12 月。
    expect(summary.monthlyRecurringMinor, 800000);
    expect(summary.next30DaysMinor, 800000);
    expect(summary.next90DaysMinor, 2400000);
    for (final item in summary.items) {
      expect(
        item.sourceType,
        MoneyBudgetCommitmentSource.autoPosting.storageValue,
      );
    }
  });

  test('模板被分期接管后只算一份，不会在「每月固定」里再算一遍', () async {
    final plan = await repository.createInstallmentPlan(
      'user_1',
      MoneyInstallmentPlanDraft(
        ledgerId: 'default_ledger_user_1',
        accountId: creditAccount.id,
        name: '车贷',
        categoryId: expenseCategory.id,
        totalPrincipalMinor: 3000000,
        totalInterestMinor: 0,
        totalPeriods: 3,
        firstDueDate: DateTime(2026, 10, 20),
      ),
    );
    final taken = await template(
      type: MoneyTransactionType.expense,
      amountMinor: 1000000,
      dayOfMonth: 20,
      name: '车贷',
    );
    await repository.takeOverAutoPostingTemplate('user_1', taken.id, plan.id);

    final summary = await repository.getUpcomingCashFlowForUser(
      'user_1',
      ledgerId: 'default_ledger_user_1',
    );

    // 只剩分期那三期；「每月固定」（周期模板口径）必须是 0 —— 模板已被接管，
    // 它的 10/20、11/20、12/20 三次执行都不能再算一遍。
    expect(summary.items, hasLength(3));
    for (final item in summary.items) {
      expect(
        item.sourceType,
        MoneyBudgetCommitmentSource.installment.storageValue,
      );
      expect(item.amountMinor, 1000000);
    }
    expect(summary.monthlyRecurringMinor, 0);
    expect(summary.next30DaysMinor, 1000000);
  });

  test('待确认流水不进现金流卡（它讲的是未来确定会发生的钱）', () async {
    final transaction = await repository.createTransaction(
      'user_1',
      MoneyTransactionDraft(
        description: '待确认的一笔',
        type: MoneyTransactionType.expense,
        amountMinor: 50000,
        currencyCode: 'CNY',
        accountId: account.id,
        categoryId: expenseCategory.id,
        paymentMethod: MoneyPaymentMethod.bankTransfer,
        ledgerId: 'default_ledger_user_1',
        transactionAt: DateTime(2026, 10, 17, 12),
        status: MoneyTransactionStatus.pending,
      ),
    );
    expect(transaction.status, MoneyTransactionStatus.pending);

    final summary = await repository.getUpcomingCashFlowForUser(
      'user_1',
      ledgerId: 'default_ledger_user_1',
    );
    expect(summary.items, isEmpty);
    expect(summary.next30DaysMinor, 0);
  });

  test('upcomingExpenseCommitments 可以带上待确认流水（想买段的口径）', () async {
    await repository.createTransaction(
      'user_1',
      MoneyTransactionDraft(
        description: '待确认的一笔',
        type: MoneyTransactionType.expense,
        amountMinor: 50000,
        currencyCode: 'CNY',
        accountId: account.id,
        categoryId: expenseCategory.id,
        paymentMethod: MoneyPaymentMethod.bankTransfer,
        ledgerId: 'default_ledger_user_1',
        transactionAt: DateTime(2026, 10, 17, 12),
        status: MoneyTransactionStatus.pending,
      ),
    );

    final withPending = await repository.upcomingExpenseCommitments(
      'user_1',
      ledgerId: 'default_ledger_user_1',
      // 待确认流水落在 10 月 17 日 12:00，窗口要包住它（原来写成 18 日起）。
      start: DateTime(2026, 10, 17),
      end: DateTime(2026, 10, 19),
    );
    expect(withPending, hasLength(1));
    expect(
      withPending.single.source,
      MoneyBudgetCommitmentSource.pendingTransaction,
    );
    expect(withPending.single.currencyCode, 'CNY');
  });
}
